"""
Stipple reactive model for the Education Center.
Manages topic navigation, glossary search, and tutorial progress.
"""
using Stipple, StippleUI


@app begin
    @in left_drawer_open::Bool = true
    # ── Navigation ───────────────────────────────────────────────────────
    @in active_section::String = "topics"
    @in selected_topic::String = ""
    @in glossary_search::String = ""

    # ── Topic Library ────────────────────────────────────────────────────
    @out topics::Vector{Dict{String,Any}} = [
        Dict("id"=>"cah_basics", "title"=>"Critical Access Hospital (CAH) Basics",
             "category"=>"Hospital Types", "difficulty"=>"beginner",
             "summary"=>"Understanding the CAH designation, requirements, and cost-based reimbursement.",
             "content"=>"Critical Access Hospitals (CAHs) are small hospitals in rural areas that receive cost-based reimbursement from Medicare. To qualify, a hospital must have 25 or fewer acute care inpatient beds, be located more than 35 miles from another hospital (or 15 miles in mountainous terrain), maintain an annual average length of stay of 96 hours or less for acute care patients, and provide 24/7 emergency care services."),
        Dict("id"=>"reh_overview", "title"=>"Rural Emergency Hospitals (REH)",
             "category"=>"Hospital Types", "difficulty"=>"intermediate",
             "summary"=>"The new REH designation under the CAA 2021 — requirements, benefits, and conversion process.",
             "content"=>"Rural Emergency Hospitals (REHs) were established by the Consolidated Appropriations Act of 2021. REHs provide emergency department services and observation care without inpatient beds. They receive facility-specific monthly payments plus 5% above OPPS rates for outpatient services. To convert, a hospital must have been a CAH or small rural hospital with 50 or fewer beds."),
        Dict("id"=>"cost_report", "title"=>"Medicare Cost Reports Explained",
             "category"=>"Financial", "difficulty"=>"advanced",
             "summary"=>"How to read and interpret CMS-2552 cost reports for rural hospitals.",
             "content"=>"The Medicare Cost Report (CMS-2552-10) is an annual filing that details a hospital's costs, charges, revenue, and utilization statistics. Key worksheets include Worksheet S-2 (hospital identification), Worksheet S-3 (inpatient revenue), Worksheet A (reclassification and adjustment of trial balance), Worksheet B (cost allocation), and Worksheet E (calculation of reimbursement settlement)."),
        Dict("id"=>"payer_mix", "title"=>"Understanding Payer Mix",
             "category"=>"Financial", "difficulty"=>"beginner",
             "summary"=>"How the distribution of Medicare, Medicaid, commercial, and self-pay patients impacts revenue.",
             "content"=>"Payer mix describes the percentage of a hospital's patients (or revenue) covered by each type of insurance. Rural hospitals typically have a higher Medicare percentage (55-70%) than urban hospitals (40-50%). A hospital's payer mix directly affects its financial health because each payer reimburses at different rates."),
        Dict("id"=>"financial_ratios", "title"=>"Key Financial Ratios for Hospitals",
             "category"=>"Financial", "difficulty"=>"intermediate",
             "summary"=>"Operating margin, days cash on hand, current ratio, debt-to-capitalization, and more.",
             "content"=>"Key financial ratios include: Operating Margin (operating income / total revenue), Total Margin (net income / total revenue), Days Cash on Hand (cash and investments / daily operating expenses), Current Ratio (current assets / current liabilities), Debt-to-Capitalization (long-term debt / (long-term debt + net assets)), and Average Age of Plant (accumulated depreciation / depreciation expense)."),
        Dict("id"=>"monte_carlo", "title"=>"Monte Carlo Simulation for Hospital Finance",
             "category"=>"Methodology", "difficulty"=>"advanced",
             "summary"=>"How Monte Carlo methods model financial uncertainty in hospital projections.",
             "content"=>"Monte Carlo simulation generates thousands of possible financial outcomes by randomly sampling from probability distributions assigned to uncertain variables (volume growth, rate changes, cost inflation). The result is a probability distribution of outcomes rather than a single point estimate, enabling decision-makers to understand the range and likelihood of different financial scenarios."),
        Dict("id"=>"closure_indicators", "title"=>"Hospital Closure Risk Indicators",
             "category"=>"Risk", "difficulty"=>"intermediate",
             "summary"=>"Early warning signs and financial distress indicators for rural hospitals.",
             "content"=>"Research identifies several factors associated with rural hospital closure: negative operating margins for 3+ consecutive years, days cash on hand below 30, declining patient volume, high Medicare/Medicaid payer mix, population decline in the service area, distance from other hospitals, loss of key physicians, and aging facility infrastructure."),
        Dict("id"=>"staffing_models", "title"=>"Rural Hospital Staffing Models",
             "category"=>"Operations", "difficulty"=>"intermediate",
             "summary"=>"Optimal staffing ratios, FTE benchmarks, and labor cost management.",
             "content"=>"Rural hospitals face unique staffing challenges including recruitment difficulty, higher contract labor costs, and the need for staff to fill multiple roles. Key benchmarks include FTE per adjusted occupied bed (typically 4.5-6.0 for CAHs), labor cost as a percentage of net patient revenue (target 50-55%), and nursing hours per patient day."),
    ]

    # ── Glossary ─────────────────────────────────────────────────────────
    @out glossary_terms::Vector{Dict{String,String}} = [
        Dict("term"=>"ADC", "definition"=>"Average Daily Census — the average number of inpatients per day"),
        Dict("term"=>"ALOS", "definition"=>"Average Length of Stay — mean duration of inpatient stay in days"),
        Dict("term"=>"AOB", "definition"=>"Adjusted Occupied Bed — beds adjusted for outpatient volume"),
        Dict("term"=>"CAH", "definition"=>"Critical Access Hospital — small rural hospital with cost-based Medicare reimbursement"),
        Dict("term"=>"CMI", "definition"=>"Case Mix Index — measure of patient acuity and resource intensity"),
        Dict("term"=>"CMS", "definition"=>"Centers for Medicare & Medicaid Services"),
        Dict("term"=>"Cost-to-Charge Ratio", "definition"=>"Ratio of actual costs to billed charges, used in cost report settlement"),
        Dict("term"=>"DSH", "definition"=>"Disproportionate Share Hospital — extra Medicare payments for serving low-income patients"),
        Dict("term"=>"EMTALA", "definition"=>"Emergency Medical Treatment and Labor Act — requires EDs to treat all patients regardless of ability to pay"),
        Dict("term"=>"FTE", "definition"=>"Full-Time Equivalent — standard measure of staffing (2,080 hours/year)"),
        Dict("term"=>"HCAHPS", "definition"=>"Hospital Consumer Assessment of Healthcare Providers and Systems — patient satisfaction survey"),
        Dict("term"=>"IPPS", "definition"=>"Inpatient Prospective Payment System — Medicare's DRG-based payment for inpatient care"),
        Dict("term"=>"NPV", "definition"=>"Net Present Value — sum of discounted future cash flows"),
        Dict("term"=>"OPPS", "definition"=>"Outpatient Prospective Payment System — Medicare's APC-based payment for outpatient services"),
        Dict("term"=>"PPS", "definition"=>"Prospective Payment System — fixed per-case payment rather than cost-based"),
        Dict("term"=>"REH", "definition"=>"Rural Emergency Hospital — new designation providing ED and outpatient services without inpatient beds"),
        Dict("term"=>"RUCA", "definition"=>"Rural-Urban Commuting Area — census-based classification of geographic areas"),
        Dict("term"=>"Swing Bed", "definition"=>"A bed that can be used for either acute or skilled nursing care"),
        Dict("term"=>"340B", "definition"=>"Federal drug pricing program allowing eligible hospitals to purchase outpatient drugs at reduced prices"),
        Dict("term"=>"Wage Index", "definition"=>"CMS geographic adjustment factor for hospital labor costs"),
    ]

    # ── Filtered outputs ─────────────────────────────────────────────────
    @out filtered_glossary::Vector{Dict{String,String}} = Dict{String,String}[]
    @out filtered_topics::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out selected_topic_content::Dict{String,Any} = Dict{String,Any}()

    # ── Tutorial Progress ────────────────────────────────────────────────
    @in tutorial_step::Int = 1
    @out tutorial_total_steps::Int = 5
    @out tutorial_completed::Vector{String} = String[]

    @onchange glossary_search begin
        if isempty(glossary_search)
            filtered_glossary = glossary_terms
        else
            q = lowercase(glossary_search)
            filtered_glossary = filter(t ->
                contains(lowercase(t["term"]), q) || contains(lowercase(t["definition"]), q),
                glossary_terms)
        end
    end

    @onchange selected_topic begin
        if !isempty(selected_topic)
            idx = findfirst(t -> t["id"] == selected_topic, topics)
            if idx !== nothing
                selected_topic_content = topics[idx]
                active_section = "detail"
            end
        end
    end
end

const education_model = @init
