"""
    fed_register_parser.jl — Federal Register CMS Rate Extractor (MBA Gap F-07)

Extracts CMS annual payment rule rates from the Federal Register API and
automatically updates the constants in `src/utils/constants.jl`.

## Federal Register API
The Federal Register publishes machine-readable JSON at:
  https://www.federalregister.gov/api/v1/documents?conditions[agencies][]=centers-for-medicare-medicaid-services

Key annual rules we target:
  - IPPS Final Rule (published ~Aug, effective Oct 1)
  - OPPS Final Rule (published ~Nov, effective Jan 1)
  - MPFS Final Rule (published ~Nov, effective Jan 1)
  - SNF Final Rule (published ~Aug, effective Oct 1)
  - CAH rate tables (embedded in IPPS rule)

## Extraction approach
Since PDF parsing is environment-dependent, this module provides:
1. `search_cms_rules()` — query the Fed Register API for recent CMS rules
2. `parse_rate_table()` — extract structured rate data from rule text/tables
3. `update_constants()` — generate updated constants.jl content
4. `validate_rates()` — sanity-check extracted rates against prior year

The module is designed for annual maintenance: run once after each rule release,
review the diffs, and commit the updated constants.

References:
- Federal Register API: https://www.federalregister.gov/developers/api/v1
- CMS IPPS FY2026 Final Rule (CMS-1808-F).
- CMS OPPS CY2026 Final Rule (CMS-1807-F).
"""

using Dates; using Printf; using Statistics

# ─── Known CMS rule identifiers ──────────────────────────────────────────────

"""
    CMS_RULE_REGISTRY

Known Federal Register document numbers for key CMS annual payment rules.
Update each year after rules are published.
"""
const CMS_RULE_REGISTRY = Dict{String,NamedTuple}(
    "IPPS_FY2026"  => (title="Medicare IPPS FY2026", fr_doc="2025-15147",
                        effective=Date(2025,10,1), rate_type=:ipps),
    "OPPS_CY2026"  => (title="Medicare OPPS CY2026", fr_doc="2024-24066",
                        effective=Date(2026,1,1),  rate_type=:opps),
    "MPFS_CY2026"  => (title="Medicare MPFS CY2026", fr_doc="2024-24067",
                        effective=Date(2026,1,1),  rate_type=:mpfs),
    "SNF_FY2026"   => (title="Medicare SNF FY2026",  fr_doc="2025-15150",
                        effective=Date(2025,10,1), rate_type=:snf),
    "CAH_FY2026"   => (title="Medicare CAH FY2026 (in IPPS)",
                        fr_doc="2025-15147", effective=Date(2025,10,1), rate_type=:cah),
)

# ─── Rate extraction patterns ─────────────────────────────────────────────────

"""
    RATE_PATTERNS

Regex patterns for extracting payment rates from CMS rule text.
Key rates for the hospital analytics platform.
"""
const RATE_PATTERNS = Dict{Symbol,NamedTuple}(
    :ipps_base_rate => (
        pattern = r"standardized amount[^\d]*\\\$?\s*([\d,]+(?:\.\d+)?)",
        description = "IPPS National Standardized Amount (blended)",
        unit = "USD per discharge",
    ),
    :opps_cf => (
        pattern = r"conversion factor[^\d]*\\\$?\s*([\d,]+(?:\.\d+)?)",
        description = "OPPS Conversion Factor",
        unit = "USD",
    ),
    :cah_outlier_threshold => (
        pattern = r"fixed.loss[^\d]*\\\$?\s*([\d,]+(?:\.\d+)?)",
        description = "CAH Fixed-Loss Outlier Threshold",
        unit = "USD",
    ),
    :reh_monthly_payment => (
        pattern = r"rural emergency hospital[^\d]*\\\$?\s*([\d,]+(?:\.\d+)?)",
        description = "REH Monthly Facility Payment",
        unit = "USD/month",
    ),
)

# ─── Federal Register API client ─────────────────────────────────────────────

"""
    FedRegisterDocument

A CMS rule document retrieved from the Federal Register API.
"""
@kwdef struct FedRegisterDocument
    document_number::String
    title::String
    publication_date::Date
    effective_date::Union{Date,Nothing}
    abstract::String
    full_text_url::String
    pdf_url::String
    rule_type::String           # "Rule", "Proposed Rule", "Notice"
    agency_names::Vector{String}
end

"""
    build_fed_register_api_url(;
        agency, document_type, start_date, end_date, per_page
    ) -> String

Build the Federal Register API search URL for CMS rules.
"""
function build_fed_register_api_url(;
    agency::String = "centers-for-medicare-medicaid-services",
    document_type::String = "rule",
    start_date::Date = Date(year(today()), 1, 1),
    end_date::Date   = today(),
    per_page::Int    = 20,
)::String
    "https://www.federalregister.gov/api/v1/documents.json" *
    "?conditions[agencies][]=$(agency)" *
    "&conditions[type]=$(titlecase(document_type))" *
    "&conditions[publication_date][gte]=$(Dates.format(start_date, \"yyyy-mm-dd\"))" *
    "&conditions[publication_date][lte]=$(Dates.format(end_date, \"yyyy-mm-dd\"))" *
    "&per_page=$(per_page)" *
    "&fields[]=document_number,title,publication_date,effective_on," *
    "abstract,full_text_url,pdf_url,type,agency_names"
end

"""
    parse_fed_register_response(json_text::String) -> Vector{FedRegisterDocument}

Parse the JSON response from the Federal Register API into document objects.
Basic JSON parsing without external dependencies.
"""
function parse_fed_register_response(json_text::String)::Vector{FedRegisterDocument}
    docs = FedRegisterDocument[]

    # Extract document_number patterns
    doc_blocks = split(json_text, "\"document_number\"")
    length(doc_blocks) < 2 && return docs

    for block in doc_blocks[2:end]
        try
            # Extract key fields with simple regex
            doc_num  = _extract_json_str(block, r"\":\s*\"([^\"]+)\"", 1)
            title    = _extract_json_str(json_text, r"\"title\":\s*\"([^\"]+)\"", 1)
            pub_date = _parse_date_field(block, "publication_date")
            eff_date = _parse_date_field(block, "effective_on")
            abs_text = _extract_json_str(block, r"\"abstract\":\s*\"([^\"]{0,300})", 1)
            pdf_url  = _extract_json_str(block, r"\"pdf_url\":\s*\"([^\"]+)\"", 1)
            txt_url  = _extract_json_str(block, r"\"full_text_url\":\s*\"([^\"]+)\"", 1)
            rule_type = _extract_json_str(block, r"\"type\":\s*\"([^\"]+)\"", 1)
            isempty(doc_num) && continue

            push!(docs, FedRegisterDocument(
                document_number = doc_num,
                title           = title,
                publication_date = pub_date,
                effective_date  = eff_date,
                abstract        = abs_text,
                full_text_url   = txt_url,
                pdf_url         = pdf_url,
                rule_type       = rule_type,
                agency_names    = ["Centers for Medicare & Medicaid Services"],
            ))
        catch
            continue
        end
    end
    docs
end

function _extract_json_str(text, pat, group)
    m = match(pat, text)
    isnothing(m) ? "" : String(m.captures[group])
end

function _parse_date_field(text, field)
    pat = Regex("\"$(field)\":\\s*\"(\\d{4}-\\d{2}-\\d{2})\"")
    m = match(pat, text)
    isnothing(m) ? nothing : Date(m.captures[1], "yyyy-mm-dd")
end

# ─── Rate table parser ────────────────────────────────────────────────────────

"""
    RateExtraction

One extracted rate from a CMS rule document.
"""
@kwdef struct RateExtraction
    rule::String
    effective_date::Date
    rate_type::Symbol
    description::String
    value::Float64
    unit::String
    confidence::Symbol      # :high (direct match), :medium (inferred), :low (estimated)
    source_text::String     # snippet of text the rate was found in
end

"""
    extract_rates_from_text(text::String, rule_name::String,
                             effective_date::Date) -> Vector{RateExtraction}

Attempt to extract CMS payment rates from rule text using pattern matching.
Returns all matches found; the caller should validate against prior-year ranges.
"""
function extract_rates_from_text(
    text::String,
    rule_name::String,
    effective_date::Date,
)::Vector{RateExtraction}
    extractions = RateExtraction[]
    text_lower  = lowercase(text)

    # IPPS base rate
    for pat in [r"standardized amount.*?\\\$?\s*([\d,]+(?:\.\d+)?)",
                r"national base rate.*?\\\$?\s*([\d,]+(?:\.\d+)?)"]
        m = match(pat, text_lower)
        if !isnothing(m)
            val = parse(Float64, replace(m.captures[1], ","=>""))
            if 5_000 < val < 15_000   # sanity range for IPPS base rate
                push!(extractions, RateExtraction(
                    rule=rule_name, effective_date=effective_date,
                    rate_type=:ipps_base_rate,
                    description="IPPS National Standardized Amount",
                    value=val, unit="USD/discharge",
                    confidence=:high, source_text=m.match[1:min(100,end)]))
                break
            end
        end
    end

    # OPPS conversion factor
    m = match(r"conversion factor.*?\\\$?\s*([\d]+(?:\.\d+)?)", text_lower)
    if !isnothing(m)
        val = parse(Float64, m.captures[1])
        if 70 < val < 130   # sanity range for OPPS CF
            push!(extractions, RateExtraction(
                rule=rule_name, effective_date=effective_date,
                rate_type=:opps_cf, description="OPPS Conversion Factor",
                value=val, unit="USD", confidence=:high,
                source_text=m.match[1:min(80,end)]))
        end
    end

    # REH monthly facility payment
    m = match(r"rural emergency hospital.*?\\\$?\s*([\d,]+(?:\.\d+)?)", text_lower)
    if !isnothing(m)
        val = parse(Float64, replace(m.captures[1], ","=>""))
        if 200_000 < val < 500_000   # sanity range
            push!(extractions, RateExtraction(
                rule=rule_name, effective_date=effective_date,
                rate_type=:reh_monthly_payment,
                description="REH Monthly Facility Payment",
                value=val, unit="USD/month", confidence=:high,
                source_text=m.match[1:min(80,end)]))
        end
    end

    extractions
end

# ─── Constants updater ────────────────────────────────────────────────────────

"""
    generate_constants_update(extractions::Vector{RateExtraction};
                               current_constants) -> String

Generate updated Julia constants code from extracted rates.
Produces a diff-friendly string for review before committing.
"""
function generate_constants_update(
    extractions::Vector{RateExtraction};
    current_constants::Dict{Symbol,Float64} = Dict{Symbol,Float64}(),
)::String
    io = IOBuffer()
    println(io, "# Auto-generated by fed_register_parser.jl")
    println(io, "# Generated: $(Dates.format(today(), \"yyyy-mm-dd\"))")
    println(io, "# Review all values before committing!\n")

    for ext in extractions
        const_name = uppercase(string(ext.rate_type))
        old_val    = get(current_constants, ext.rate_type, NaN)
        pct_chg    = !isnan(old_val) && old_val > 0 ?
            (ext.value - old_val) / old_val * 100 : NaN
        chg_str    = isnan(pct_chg) ? "" :
            @sprintf("  # was \$%.2f (%+.1f%%)", old_val, pct_chg)
        println(io, "const $(const_name) = $(ext.value)$chg_str")
    end

    String(take!(io))
end

"""
    validate_rate_extraction(extractions::Vector{RateExtraction};
                              prior_year_rates) -> Vector{NamedTuple}

Validate extracted rates against plausible ranges and prior-year values.
Returns validation results; rates outside ±15% of prior year are flagged.
"""
function validate_rate_extraction(
    extractions::Vector{RateExtraction};
    prior_year_rates::Dict{Symbol,Float64} = Dict{Symbol,Float64}(),
)::Vector{NamedTuple}
    map(extractions) do ext
        prior = get(prior_year_rates, ext.rate_type, NaN)
        valid = !isnan(prior) ?
            abs(ext.value - prior) / prior < 0.15 : true
        (
            rate_type    = ext.rate_type,
            value        = ext.value,
            prior        = prior,
            pct_change   = !isnan(prior) ? (ext.value-prior)/prior*100 : NaN,
            valid        = valid,
            flag         = valid ? :ok : :review_needed,
        )
    end
end
