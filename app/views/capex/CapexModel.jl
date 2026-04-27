"""
    CapexModel — A-05 Capital Budgeting Tool

Stipple reactive model for ranking capital projects by NPV, IRR, profitability index.
"""
@app begin
    # ──────── Inputs ────────
    @in projects_json::String = "[]"
    @in wacc_input::Float64 = 0.08
    @in budget_constraint::Float64 = 500_000.0
    @in apply_budget::Bool = false

    # ──────── Project table input ────────
    @in project_name::String = ""
    @in project_initial_outlay::Float64 = 0.0
    @in project_useful_life::Int = 5
    @in project_annual_cf::String = "0,0,0,0,0"
    @in project_salvage::Float64 = 0.0

    # ──────── State ────────
    @in is_loading::Bool = false
    @in is_calculating::Bool = false
    @in error_message::String = ""

    # ──────── Outputs ────────
    @out ranked_projects::Vector{NamedTuple} = []
    @out selected_projects::Vector{NamedTuple} = []
    @out total_selected_investment::Float64 = 0.0
    @out total_selected_npv::Float64 = 0.0
    @out unallocated_budget::Float64 = 0.0

    @out chart_labels::Vector{String} = []
    @out chart_npv_data::Vector{Float64} = []
    @out chart_waterfalldetails::Dict = Dict()

    # ──────── Handlers ────────
    @onbutton add_project_btn begin
        # Parse annual cash flows
        try
            cfs = parse.(Float64, split(project_annual_cf, ","))
            if length(cfs) != project_useful_life
                error_message = "Annual CF count must match useful life"
                return
            end

            # Append to projects_json (convert to/from JSON for state management)
            existing = isempty(projects_json) ? [] : JSON.parse(projects_json)
            push!(existing, Dict(
                "name" => project_name,
                "initial_outlay" => project_initial_outlay,
                "useful_life" => project_useful_life,
                "annual_cf" => cfs,
                "salvage_value" => project_salvage
            ))
            projects_json = JSON.json(existing)

            # Clear form
            project_name = ""
            project_initial_outlay = 0.0
            project_annual_cf = "0,0,0,0,0"
            project_salvage = 0.0
            error_message = ""
        catch e
            error_message = "Error parsing project: $(sprint(showerror, e))"
        end
    end

    @onbutton rank_projects_btn begin
        is_calculating = true
        error_message = ""

        try
            # Parse projects from JSON
            projects_data = JSON.parse(projects_json)
            if isempty(projects_data)
                error_message = "No projects to rank"
                return
            end

            # Build CapexProject structs
            projects = [
                CapexProject(
                    name = p["name"],
                    initial_outlay = Float64(p["initial_outlay"]),
                    useful_life = Int(p["useful_life"]),
                    annual_cf = Float64.(p["annual_cf"]),
                    salvage_value = Float64(get(p, "salvage_value", 0.0))
                )
                for p in projects_data
            ]

            # Call backend
            payload = Dict(
                "projects" => projects_data,
                "wacc" => wacc_input,
                "budget_constraint" => apply_budget ? budget_constraint : nothing
            )

            result = request(:post, "/api/optimize/capex-ranking", payload)
            if haskey(result, "error")
                error_message = get(result, "error", "Unknown error")
            else
                ranked_projects = [
                    NamedTuple(Dict(
                        :name => p["name"],
                        :initial_outlay => Float64(p["initial_outlay"]),
                        :npv => Float64(p["npv"]),
                        :irr => Float64(p["irr"]),
                        :profitability_index => Float64(p["profitability_index"]),
                        :pi_rank => Int(p["pi_rank"]),
                        :selected => Bool(p["selected"])
                    ))
                    for p in get(result, "ranked_projects", [])
                ]

                selected_projects = filter(p -> p.selected, ranked_projects)
                total_selected_investment = sum(p.initial_outlay for p in selected_projects)
                total_selected_npv = sum(p.npv for p in selected_projects)
                unallocated_budget = max(0.0, budget_constraint - total_selected_investment)

                # Populate chart
                chart_labels = [p.name for p in ranked_projects]
                chart_npv_data = [p.npv for p in ranked_projects]
            end
        catch e
            error_message = "Error ranking projects: $(sprint(showerror, e))"
        finally
            is_calculating = false
        end
    end

    @onbutton clear_projects_btn begin
        projects_json = "[]"
        ranked_projects = []
        selected_projects = []
        error_message = ""
    end
end
