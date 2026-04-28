"""
    claims_formats.jl — Parsers for healthcare claims and clinical-data formats

Supported formats:
- X12 837 (Health Care Claim — Professional/Institutional/Dental)
- X12 835 (Health Care Claim Payment/Advice — remittance)
- HL7 FHIR R4 JSON (Bundle, Patient, Encounter, Claim, ExplanationOfBenefit)

The X12 parsers are delimiter-aware: they read element/segment/sub-element
delimiters from the ISA envelope rather than assuming defaults. Output is a
typed `X12Interchange` with one or more transaction sets, each holding raw
segments plus extracted summary fields (claim/payment level).

The FHIR parser handles single resources and Bundles, returning
`FhirResource` records that can be mapped into `PatientEncounter` for
downstream pipelines via `fhir_to_encounter`.
"""

using Dates
using JSON3
using UUIDs

# ============================================================================
# X12 837 / 835 — common envelope structures
# ============================================================================

"""
    X12Delimiters

Delimiters discovered from the ISA envelope. The element separator is the
4th character of the ISA segment; the component (sub-element) separator is
ISA element 16; the segment terminator is the character immediately after
the trailing `IEA` component.
"""
struct X12Delimiters
    element::Char
    component::Char
    segment::Char
    repetition::Char
end

"""
    X12Segment

A single segment as `(tag, elements)`. Elements containing component
separators are returned as `Vector{String}`; otherwise as `String`.
"""
struct X12Segment
    tag::String
    elements::Vector{Any}
end

"""
    X12TransactionSet

One ST/SE transaction set inside a functional group.
"""
struct X12TransactionSet
    set_id::String          # e.g. "837", "835"
    control_number::String  # ST02
    segments::Vector{X12Segment}
    summary::Dict{String,Any}
end

"""
    X12Interchange

Top-level envelope (one ISA…IEA group) with delimiters and decoded
transaction sets.
"""
struct X12Interchange
    delimiters::X12Delimiters
    sender_id::String
    receiver_id::String
    interchange_control::String
    date::Date
    transaction_sets::Vector{X12TransactionSet}
end

"""
    parse_x12(raw::AbstractString) -> X12Interchange

Parse a raw EDI string. Accepts 837 or 835 payloads (auto-detected from
ST01). Raises on invalid envelope.
"""
function parse_x12(raw::AbstractString)::X12Interchange
    isempty(raw) && throw(ArgumentError("Empty X12 payload"))
    startswith(raw, "ISA") || throw(ArgumentError("X12 payload must begin with ISA"))
    length(raw) < 106 && throw(ArgumentError("X12 ISA header truncated"))

    elem = raw[4]
    component = raw[105]
    segment = raw[106]
    rep = elem  # default; ISA11 holds repetition separator in 5010+
    isa_elements = split(raw[1:105], elem)
    if length(isa_elements) >= 12 && length(isa_elements[12]) == 1
        rep = isa_elements[12][1]
    end
    delimiters = X12Delimiters(elem, component, segment, rep)

    sender = strip(get(isa_elements, 7, ""))
    receiver = strip(get(isa_elements, 9, ""))
    ctrl = strip(get(isa_elements, 14, ""))
    date_str = strip(get(isa_elements, 10, ""))
    isa_date = try
        length(date_str) == 6 ? Date("20" * date_str, dateformat"yyyymmdd") : today()
    catch; today(); end

    raw_segments = [strip(s) for s in split(raw, segment) if !isempty(strip(s))]

    sets = X12TransactionSet[]
    in_set = false
    cur_segs = X12Segment[]
    cur_id = ""
    cur_ctrl = ""

    for s in raw_segments
        elements = split(s, elem)
        tag = String(elements[1])
        decoded_elements = Any[]
        for e in elements[2:end]
            if occursin(component, e)
                push!(decoded_elements, String.(split(e, component)))
            else
                push!(decoded_elements, String(e))
            end
        end
        seg = X12Segment(tag, decoded_elements)

        if tag == "ST"
            in_set = true
            cur_segs = X12Segment[seg]
            cur_id = String(elements[2])
            cur_ctrl = length(elements) >= 3 ? String(elements[3]) : ""
        elseif tag == "SE"
            push!(cur_segs, seg)
            summary = if cur_id == "837"
                _summarize_837(cur_segs)
            elseif cur_id == "835"
                _summarize_835(cur_segs)
            else
                Dict{String,Any}()
            end
            push!(sets, X12TransactionSet(cur_id, cur_ctrl, cur_segs, summary))
            in_set = false
        elseif in_set
            push!(cur_segs, seg)
        end
    end

    return X12Interchange(delimiters, sender, receiver, ctrl, isa_date, sets)
end

"""
    summarize_claims(itx::X12Interchange) -> Vector{Dict{String,Any}}

Return one normalized record per claim/remittance across all transaction
sets in the interchange.
"""
function summarize_claims(itx::X12Interchange)::Vector{Dict{String,Any}}
    out = Dict{String,Any}[]
    for ts in itx.transaction_sets
        push!(out, merge(Dict("transaction" => ts.set_id, "control" => ts.control_number), ts.summary))
    end
    return out
end

# ── 837 (claim) summary ──────────────────────────────────────────────────────

function _summarize_837(segs::Vector{X12Segment})::Dict{String,Any}
    info = Dict{String,Any}(
        "claim_count" => 0,
        "billed_total" => 0.0,
        "service_lines" => 0,
        "subscriber_id" => "",
        "billing_provider_npi" => "",
        "diagnoses" => String[],
        "claim_ids" => String[],
    )
    for seg in segs
        if seg.tag == "CLM"
            info["claim_count"] += 1
            length(seg.elements) >= 1 && push!(info["claim_ids"], _scalar(seg.elements[1]))
            if length(seg.elements) >= 2
                amt = tryparse(Float64, _scalar(seg.elements[2]))
                amt === nothing || (info["billed_total"] += amt)
            end
        elseif seg.tag == "SV1" || seg.tag == "SV2" || seg.tag == "SV3"
            info["service_lines"] += 1
        elseif seg.tag == "NM1" && length(seg.elements) >= 1 && _scalar(seg.elements[1]) == "85"
            length(seg.elements) >= 9 && (info["billing_provider_npi"] = _scalar(seg.elements[9]))
        elseif seg.tag == "NM1" && length(seg.elements) >= 1 && _scalar(seg.elements[1]) == "IL"
            length(seg.elements) >= 9 && (info["subscriber_id"] = _scalar(seg.elements[9]))
        elseif seg.tag == "HI"
            for e in seg.elements
                e isa Vector || continue
                length(e) >= 2 || continue
                qualifier = String(e[1])
                if startswith(qualifier, "ABK") || startswith(qualifier, "BK") ||
                   startswith(qualifier, "ABF") || startswith(qualifier, "BF")
                    push!(info["diagnoses"], String(e[2]))
                end
            end
        end
    end
    return info
end

# ── 835 (remittance) summary ────────────────────────────────────────────────

function _summarize_835(segs::Vector{X12Segment})::Dict{String,Any}
    info = Dict{String,Any}(
        "payment_total" => 0.0,
        "payer_id" => "",
        "payee_npi" => "",
        "claim_count" => 0,
        "claim_payments" => Vector{Dict{String,Any}}(),
    )
    for seg in segs
        if seg.tag == "BPR" && length(seg.elements) >= 2
            amt = tryparse(Float64, _scalar(seg.elements[2]))
            amt === nothing || (info["payment_total"] = amt)
        elseif seg.tag == "N1" && length(seg.elements) >= 1
            role = _scalar(seg.elements[1])
            if role == "PR" && length(seg.elements) >= 4
                info["payer_id"] = _scalar(seg.elements[4])
            elseif role == "PE" && length(seg.elements) >= 4
                info["payee_npi"] = _scalar(seg.elements[4])
            end
        elseif seg.tag == "CLP"
            info["claim_count"] += 1
            cp = Dict{String,Any}(
                "claim_id" => length(seg.elements) >= 1 ? _scalar(seg.elements[1]) : "",
                "status_code" => length(seg.elements) >= 2 ? _scalar(seg.elements[2]) : "",
                "billed" => length(seg.elements) >= 3 ?
                    something(tryparse(Float64, _scalar(seg.elements[3])), 0.0) : 0.0,
                "paid" => length(seg.elements) >= 4 ?
                    something(tryparse(Float64, _scalar(seg.elements[4])), 0.0) : 0.0,
                "patient_resp" => length(seg.elements) >= 5 ?
                    something(tryparse(Float64, _scalar(seg.elements[5])), 0.0) : 0.0,
            )
            push!(info["claim_payments"], cp)
        end
    end
    return info
end

_scalar(x) = x isa Vector ? (isempty(x) ? "" : String(x[1])) : String(x)

# ============================================================================
# HL7 FHIR R4 ingestion
# ============================================================================

"""
    FhirResource

Lightweight representation of a parsed FHIR resource.
"""
struct FhirResource
    resource_type::String
    id::String
    body::Dict{String,Any}
end

"""
    parse_fhir(input) -> Vector{FhirResource}

Parse a FHIR JSON payload from a `String`, `IO`, or pre-parsed `Dict`.
Bundles are flattened into individual entry resources; single resources
are returned as a one-element vector.
"""
function parse_fhir(input)::Vector{FhirResource}
    parsed = if input isa AbstractString
        JSON3.read(input, Dict{String,Any})
    elseif input isa IO
        JSON3.read(read(input, String), Dict{String,Any})
    elseif input isa Dict
        input
    else
        throw(ArgumentError("Unsupported FHIR input type: $(typeof(input))"))
    end

    rt = get(parsed, "resourceType", "")
    if rt == "Bundle"
        out = FhirResource[]
        for entry in get(parsed, "entry", Any[])
            res = get(entry, "resource", nothing)
            res === nothing && continue
            push!(out, _to_fhir_resource(res))
        end
        return out
    end
    return [_to_fhir_resource(parsed)]
end

function _to_fhir_resource(d::AbstractDict)::FhirResource
    rt = String(get(d, "resourceType", "Unknown"))
    id = String(get(d, "id", string(uuid4())))
    return FhirResource(rt, id, Dict{String,Any}(string(k) => v for (k, v) in d))
end

"""
    fhir_to_encounter(resources::Vector{FhirResource};
                      org_salt::String = "HealthcareEconomicsOrg2024")
        -> Vector{PatientEncounter}

Map a set of FHIR resources to `PatientEncounter` records. Pairs each
`Encounter` resource with the referenced `Patient` (when present in the
same input) to populate demographics. Resources lacking either side are
skipped.
"""
function fhir_to_encounter(
    resources::Vector{FhirResource};
    org_salt::String = "HealthcareEconomicsOrg2024",
)::Vector{PatientEncounter}
    patients = Dict{String,Dict{String,Any}}()
    for r in resources
        r.resource_type == "Patient" || continue
        patients[r.id] = r.body
    end

    encounters = PatientEncounter[]
    for r in resources
        r.resource_type == "Encounter" || continue
        body = r.body
        subject_ref = String(get(get(body, "subject", Dict()), "reference", ""))
        patient_id_raw = last(split(subject_ref, "/"))
        patient_record = get(patients, String(patient_id_raw), Dict{String,Any}())

        period = get(body, "period", Dict())
        admit = _fhir_date(get(period, "start", nothing))
        disch = _fhir_date(get(period, "end", admit))
        admit === nothing && continue

        dob = _fhir_date(get(patient_record, "birthDate", nothing))
        sex = _fhir_sex(get(patient_record, "gender", "unknown"))
        zip3 = _fhir_zip3(patient_record)

        diagnoses = _fhir_diagnoses(body)
        primary = isempty(diagnoses) ? "" : diagnoses[1]
        secondary = length(diagnoses) > 1 ? diagnoses[2:end] : String[]

        enc = PatientEncounter(
            String(patient_id_raw),
            r.id,
            admit,
            disch === nothing ? admit : disch;
            birth_year = dob === nothing ? 1950 : year(dob),
            age_at_admission = dob === nothing ? 0 : min(90, year(admit) - year(dob)),
            sex = sex,
            zip_code_prefix = zip3,
            admission_type = _fhir_admission_type(body),
            primary_diagnosis = primary,
            secondary_diagnoses = secondary,
            source_system = "FHIR",
        )
        push!(encounters, enc)
    end
    return encounters
end

# ── FHIR field helpers ──────────────────────────────────────────────────────

function _fhir_date(v)
    v === nothing && return nothing
    s = String(v)
    isempty(s) && return nothing
    try
        length(s) >= 10 ? Date(s[1:10]) : Date(s)
    catch
        nothing
    end
end

function _fhir_sex(g)
    s = lowercase(String(g))
    s == "male"   && return "M"
    s == "female" && return "F"
    return "O"
end

function _fhir_zip3(patient::AbstractDict)
    addrs = get(patient, "address", Any[])
    isempty(addrs) && return "000"
    postal = String(get(addrs[1], "postalCode", ""))
    length(postal) >= 3 ? postal[1:3] : "000"
end

function _fhir_admission_type(enc_body::AbstractDict)
    cls = get(enc_body, "class", Dict())
    code = lowercase(String(get(cls, "code", "")))
    code in ("emer", "emergency") && return "Emergency"
    code in ("urg", "urgent") && return "Urgent"
    code in ("imp", "inpatient", "amb", "ambulatory") && return "Scheduled"
    return "Scheduled"
end

function _fhir_diagnoses(enc_body::AbstractDict)::Vector{String}
    out = String[]
    for d in get(enc_body, "diagnosis", Any[])
        cond = get(d, "condition", Dict())
        ref = String(get(cond, "reference", ""))
        disp = String(get(cond, "display", ""))
        push!(out, isempty(disp) ? ref : disp)
    end
    return out
end
