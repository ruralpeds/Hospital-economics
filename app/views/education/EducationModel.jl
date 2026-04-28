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
    # Export
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false
    @in errors::Vector{String} = String[]

    @out topics::Vector{Dict{String,Any}} = [
        Dict("id"=>"cah_basics", "title"=>"Critical Access Hospital (CAH) Basics",
             "category"=>"Hospital Types", "difficulty"=>"beginner",
             "summary"=>"Understanding the CAH designation, requirements, and cost-based reimbursement.",
             "content"=>"Critical Access Hospitals (CAHs) are small hospitals in rural areas that receive cost-based reimbursement from Medicare. To qualify, a hospital must have 25 or fewer acute care inpatient beds, be located more than 35 miles from another hospital (or 15 miles in mountainous terrain), maintain an annual average length of stay of 96 hours or less for acute care patients, and provide 24/7 emergency care services."),
        Dict("id"=>"reh_overview", "title"=>"Rural Emergency Hospitals (REH)",
             "category"=>"Hospital Types", "difficulty"=>"intermediate",
             "summary"=>"The new REH designation under the CAA 2021 — requirements, benefits, and conversion process.",
             "content"=>"Rural Emergency Hospitals (REHs) were established by the Consolidated Appropriations Act of 2021. REHs provide emergency department services and observation care without inpatient beds. They receive facility-specific monthly payments plus 5% above OPPS rates for outpatient services. To convert, a hospital must have been a CAH or small rural hospital with 50 or fewer beds."),
        Dict("id"=>"reh_conversion", "title"=>"CAH-to-REH Conversion Decision Framework",
             "category"=>"Hospital Types", "difficulty"=>"advanced",
             "summary"=>"Evaluating whether to convert from a CAH to an REH — financial trade-offs, community impact, and regulatory steps.",
             "content"=>"Converting from a Critical Access Hospital to a Rural Emergency Hospital involves significant trade-offs. Benefits include the monthly facility payment (~\$272,866/month in FY2024), elimination of inpatient cost obligations, 5% OPPS add-on, and lower staffing requirements. Risks include loss of inpatient revenue (typically 30-45% of net revenue), community backlash, and staff displacement. Key decision factors: current inpatient volume (low volumes favor REH), distance to nearest inpatient facility, service area demographics, financial distress level, and availability of skilled nursing alternatives for swing bed patients. The conversion process requires CMS approval, state licensure changes, and a community engagement period."),
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
        Dict("id"=>"program_340b", "title"=>"The 340B Drug Pricing Program",
             "category"=>"Policy", "difficulty"=>"intermediate",
             "summary"=>"How eligible rural hospitals leverage 340B to generate pharmacy revenue and fund patient care programs.",
             "content"=>"The 340B Drug Pricing Program requires drug manufacturers to offer outpatient drugs at discounted prices to eligible healthcare organizations, including CAHs and sole community hospitals. Rural hospitals typically use 340B savings in two ways: (1) dispensing discounted drugs to eligible patients and billing insurers at higher rates, generating revenue spread; and (2) funding charity care, community health programs, and expanding access to medications. Contract pharmacies extend 340B reach to communities without in-house pharmacies. Key risks include potential legislative changes limiting contract pharmacies, manufacturer restrictions on 340B pricing, and compliance audits by HRSA. For a typical 25-bed CAH, 340B savings can range from \$200K to \$1.5M annually depending on outpatient volume and specialty mix."),
        Dict("id"=>"vbc_transition", "title"=>"Value-Based Care for Rural Hospitals",
             "category"=>"Policy", "difficulty"=>"advanced",
             "summary"=>"Transitioning from fee-for-service to value-based payment — ACO models, risk sharing, and quality metrics.",
             "content"=>"Value-Based Care (VBC) shifts payment from volume to outcomes. Rural hospitals can participate through Medicare Shared Savings Program (MSSP) ACOs, BPCI Advanced bundled payments, and the new TEAM model. Key concepts: attributed lives (the population a provider is responsible for), PMPM benchmarks (per-member-per-month spending targets), quality gates (minimum quality scores to earn shared savings), and downside risk (financial penalty if spending exceeds benchmarks). Rural-specific challenges include small patient panels (statistical noise in quality measures), limited specialist access, and higher per-capita costs due to low volume. Success strategies include telehealth integration, care coordination with regional partners, and focusing on preventable readmissions and ED utilization."),
        Dict("id"=>"sdoh_impact", "title"=>"Social Determinants of Health & Hospital Finance",
             "category"=>"Policy", "difficulty"=>"intermediate",
             "summary"=>"How poverty, food insecurity, and social factors affect hospital costs, utilization, and reimbursement.",
             "content"=>"Social Determinants of Health (SDOH) — including poverty, food insecurity, housing instability, transportation barriers, and educational attainment — significantly impact rural hospital economics. Communities with higher SDOH burden experience: more ED visits for preventable conditions, higher readmission rates, greater uncompensated care, and more complex case mixes. CMS is increasingly incorporating SDOH into payment models through the Area Deprivation Index and ICD-10 Z-codes for social risk factors. Hospitals can improve outcomes and reduce costs by screening for SDOH, partnering with community organizations, and investing in programs like food pharmacies, transportation assistance, and community health workers."),
        Dict("id"=>"disaster_resilience", "title"=>"Disaster Preparedness & Financial Resilience",
             "category"=>"Risk", "difficulty"=>"intermediate",
             "summary"=>"Building financial and operational resilience against natural disasters, pandemics, and supply chain disruptions.",
             "content"=>"Rural hospitals face outsized disaster vulnerability due to limited surge capacity, single-source supply chains, and thin financial reserves. Key resilience dimensions: (1) Financial — maintaining 60+ days cash on hand and access to emergency credit lines; (2) Operational — generator capacity, water reserves, and mutual aid agreements with neighboring facilities; (3) Workforce — cross-training staff, maintaining credentialed volunteer pools, and pandemic staffing plans; (4) Supply chain — diversified vendors, strategic pharmaceutical reserves, and regional purchasing cooperatives. The COVID-19 pandemic demonstrated that hospitals with stronger pre-disaster financial positions recovered faster. FEMA and HHS grants can offset preparedness costs, and CMS emergency preparedness conditions of participation set minimum requirements."),
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
        Dict("id"=>"telehealth_economics", "title"=>"Telehealth Economics for Rural Hospitals",
             "category"=>"Operations", "difficulty"=>"beginner",
             "summary"=>"ROI of telehealth programs — reimbursement, cost savings, and expanded access.",
             "content"=>"Telehealth can transform rural hospital economics by enabling specialist access without recruitment costs, reducing unnecessary transfers, and expanding the patient catchment area. Key revenue drivers: originating site facility fees (\$27-\$29 per encounter), professional fees for employed providers conducting distant-site visits, and reduced transfer costs (\$5K-\$50K per avoided transfer). Investment requirements include platform licensing (\$15K-\$100K/year), equipment (\$2K-\$10K per exam room), broadband connectivity, and staff training. Post-COVID reimbursement parity has made telehealth financially viable for most rural hospitals. Services with highest rural ROI: telestroke, tele-ICU, telepsychiatry, and primary care follow-up."),
        Dict("id"=>"medicaid_supplemental", "title"=>"Medicaid Supplemental Payments & DSH",
             "category"=>"Financial", "difficulty"=>"advanced",
             "summary"=>"State-level Medicaid programs, DSH payments, and upper payment limit pools for rural hospitals.",
             "content"=>"Medicaid supplemental payments are state-administered programs that provide additional reimbursement above standard Medicaid rates. Key programs include: Disproportionate Share Hospital (DSH) payments for hospitals serving high proportions of Medicaid and uninsured patients; Upper Payment Limit (UPL) supplements that bridge the gap between Medicaid rates and Medicare rates; and state-specific directed payment programs. For rural hospitals in Medicaid expansion states, these payments can represent 5-15% of total net revenue. Key risks: DSH allotment reductions under the ACA (repeatedly delayed but still pending), state budget pressures, and changing eligibility calculations. Hospitals should track their DSH adjustment percentage and UPL gap to ensure they capture all available supplemental funds."),
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
        Dict("term"=>"DSCR", "definition"=>"Debt Service Coverage Ratio — annual net operating income divided by annual debt payments"),
        Dict("term"=>"UPL", "definition"=>"Upper Payment Limit — maximum Medicaid payment rate, typically tied to Medicare rates"),
        Dict("term"=>"TEAM", "definition"=>"Transforming Episode Accountability Model — CMS mandatory bundled payment model for certain episodes"),
        Dict("term"=>"ACO", "definition"=>"Accountable Care Organization — group of providers sharing responsibility for cost and quality of care"),
        Dict("term"=>"PMPM", "definition"=>"Per Member Per Month — a capitated payment benchmark used in value-based contracts"),
        Dict("term"=>"CCR", "definition"=>"Cost-to-Charge Ratio — ratio of costs to charges used in Medicare cost report settlement"),
        Dict("term"=>"HPSA", "definition"=>"Health Professional Shortage Area — federal designation for areas with insufficient primary care, dental, or mental health providers"),
        Dict("term"=>"Step-Down Allocation", "definition"=>"Cost accounting method that sequentially allocates overhead department costs to revenue-producing departments"),
        Dict("term"=>"Sequestration", "definition"=>"Automatic 2% reduction in Medicare payments mandated by the Budget Control Act of 2011"),
        Dict("term"=>"DRG", "definition"=>"Diagnosis-Related Group — classification system grouping inpatient stays for prospective payment"),
    ]

    # ── Filtered outputs ─────────────────────────────────────────────────
    @out filtered_glossary::Vector{Dict{String,String}} = Dict{String,String}[]
    @out filtered_topics::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out selected_topic_content::Dict{String,Any} = Dict{String,Any}()

    # ── Tutorial Progress ────────────────────────────────────────────────
    @in tutorial_step::Int = 1
    @out tutorial_total_steps::Int = 8
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
