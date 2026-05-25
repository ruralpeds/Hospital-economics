"""
    MARiskModel — A-06 Medicare Advantage Risk Adjustment

Stipple reactive model for calculating member-level RAF scores and cohort risk analysis.
"""
@app begin
    # ──────── UI state ────────
    @in left_drawer_open::Bool = true

    # ──────── Export ────────
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false

    # ──────── Inputs ────────
    @in upload_csv::String = ""
    @in annual_capitation::Float64 = 10_000.0
    @in use_sample_data::Bool = false

    # Member list (for CSV import)
    @in member_data_json::String = "[]"

    # ──────── State ────────
    @in is_loading::Bool = false
    @in is_calculating::Bool = false
    @in error_message::String = ""

    # ──────── Outputs ────────
    @out member_rafs::Vector{NamedTuple} = []
    @out cohort_stats::Dict = Dict(
        "member_count" => 0,
        "mean_raf" => 0.0,
        "std_raf" => 0.0,
        "percentiles" => Dict(),
        "capitation_impact" => Dict()
    )

    @out risk_band_chart_labels::Vector{String} = []
    @out risk_band_chart_values::Vector{Int} = []

    @out raf_distribution_data::Vector{Float64} = []

    # ──────── Handlers ────────
    @onbutton load_sample_data_btn begin
        is_loading = true
        error_message = ""

        try
            # Create sample cohort with 50 members
            sample_members = [
                Dict(
                    "member_id" => "M$(lpad(i, 4, '0'))",
                    "age" => 50 + rand(0:40),
                    "sex" => rand(["M", "F"]),
                    "diagnoses" => if i % 3 == 0
                        String.(["HCC" * lpad(j, 3, "0") for j in rand(1:86, rand(0:3))])
                    else
                        String[]
                    end
                )
                for i in 1:50
            ]
            member_data_json = JSON.json(sample_members)
            use_sample_data = true
            error_message = ""
        catch e
            error_message = "Error generating sample data: $(sprint(showerror, e))"
        finally
            is_loading = false
        end
    end

    @onbutton calculate_raf_btn begin
        is_calculating = true
        error_message = ""

        try
            members_data = JSON.parse(member_data_json)
            if isempty(members_data)
                error_message = "No member data to analyze"
                return
            end

            # Call API endpoint
            payload = Dict(
                "members" => members_data,
                "annual_capitation" => annual_capitation
            )

            result = request(:post, "/api/risk/ma-risk", payload)
            if haskey(result, "error")
                error_message = get(result, "error", "Unknown error")
            else
                # Populate member-level results
                member_rafs = [
                    NamedTuple(Dict(
                        :member_id => m["member_id"],
                        :age => m["age"],
                        :sex => m["sex"],
                        :diagnoses_count => length(get(m, "diagnoses", [])),
                        :hcc_count => m["hcc_count"],
                        :member_raf => Float64(m["combined_raf"]),
                        :risk_band => m["risk_band"]
                    ))
                    for m in get(result, "member_rafs", [])
                ]

                # Populate cohort stats
                cohort_stats = get(result, "cohort_stats", Dict())

                # Risk band distribution for chart
                risk_dist = get(cohort_stats, "risk_band_distribution", Dict())
                risk_band_chart_labels = ["Low", "Average", "High", "Very High"]
                risk_band_chart_values = [
                    get(risk_dist, "low", 0),
                    get(risk_dist, "average", 0),
                    get(risk_dist, "high", 0),
                    get(risk_dist, "very_high", 0)
                ]

                # RAF distribution histogram data
                raf_distribution_data = [m.member_raf for m in member_rafs]
            end
        catch e
            error_message = "Error calculating RAF: $(sprint(showerror, e))"
        finally
            is_calculating = false
        end
    end

    @onbutton clear_data_btn begin
        member_data_json = "[]"
        member_rafs = []
        cohort_stats = Dict(
            "member_count" => 0,
            "mean_raf" => 0.0,
            "std_raf" => 0.0,
            "percentiles" => Dict(),
            "capitation_impact" => Dict()
        )
        risk_band_chart_labels = []
        risk_band_chart_values = []
        error_message = ""
    end
end
