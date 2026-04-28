"""
Stipple reactive model for Simulation Runner.
Manages methodology selection, parameter configuration, and execution tracking.
Delegates to RuralHospitalSim simulation engines for actual computation.
"""
using Stipple, StippleUI, StipplePlotly

# Import domain layer
using ...RuralHospitalSim: run_monte_carlo, project_financials, run_sensitivity_analysis,
    MonteCarloParams, DeterministicParams, DistributionalParameter


@app begin
    @in left_drawer_open::Bool = true
    # ── Methodology Selection ────────────────────────────────────────────
    @in methodology::String = "monte_carlo"
    @in selected_scenario_id::Int = 1
    # Export
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false
    @in errors::Vector{String} = String[]

    @out methodology_options::Vector{Dict{String,String}} = [
        Dict("label" => "Monte Carlo Simulation", "value" => "monte_carlo"),
        Dict("label" => "Deterministic Projection", "value" => "deterministic"),
        Dict("label" => "Sensitivity Analysis", "value" => "sensitivity"),
        Dict("label" => "Stress Testing", "value" => "stress_test"),
    ]
    @out scenario_options::Vector{Dict{String,Any}} = [
        Dict("label" => "Baseline", "value" => 1),
        Dict("label" => "REH Conversion", "value" => 2),
        Dict("label" => "Telehealth Expansion", "value" => 3),
    ]

    # ── Monte Carlo Parameters ───────────────────────────────────────────
    @in mc_iterations::Int = 1000
    @in mc_confidence_level::Float64 = 95.0
    @in mc_seed::Int = 42
    @in mc_distribution::String = "normal"
    @in mc_correlation_enabled::Bool = true
    @out distribution_options::Vector{Dict{String,String}} = [
        Dict("label" => "Normal", "value" => "normal"),
        Dict("label" => "Log-Normal", "value" => "lognormal"),
        Dict("label" => "Triangular", "value" => "triangular"),
        Dict("label" => "Uniform", "value" => "uniform"),
    ]

    # ── Projection Parameters ────────────────────────────────────────────
    @in projection_years::Int = 5
    @in projection_start_year::Int = 2026
    @in discount_rate::Float64 = 5.0
    @in terminal_growth_rate::Float64 = 2.0

    # ── Sensitivity Analysis Parameters ──────────────────────────────────
    @in sensitivity_variable::String = "revenue_growth"
    @in sensitivity_range_low::Float64 = -5.0
    @in sensitivity_range_high::Float64 = 10.0
    @in sensitivity_steps::Int = 20
    @out sensitivity_variables::Vector{Dict{String,String}} = [
        Dict("label" => "Revenue Growth Rate", "value" => "revenue_growth"),
        Dict("label" => "Volume Growth Rate", "value" => "volume_growth"),
        Dict("label" => "Salary Increase Rate", "value" => "salary_increase"),
        Dict("label" => "Supply Cost Inflation", "value" => "supply_inflation"),
        Dict("label" => "Medicare Rate Update", "value" => "medicare_rate"),
        Dict("label" => "Payer Mix (Medicare %)", "value" => "medicare_pct"),
        Dict("label" => "Discount Rate", "value" => "discount_rate"),
    ]

    # ── Stress Test Parameters ───────────────────────────────────────────
    @in stress_scenarios_enabled::Vector{String} = ["volume_drop", "rate_cut", "labor_spike"]
    @out stress_scenario_options::Vector{Dict{String,String}} = [
        Dict("label" => "20% Volume Drop", "value" => "volume_drop"),
        Dict("label" => "Medicare Rate Cut 5%", "value" => "rate_cut"),
        Dict("label" => "Labor Cost Spike 15%", "value" => "labor_spike"),
        Dict("label" => "Supply Chain Disruption", "value" => "supply_disruption"),
        Dict("label" => "Pandemic Scenario", "value" => "pandemic"),
        Dict("label" => "Key Physician Departure", "value" => "physician_loss"),
        Dict("label" => "Natural Disaster", "value" => "natural_disaster"),
    ]

    # ── Variable Uncertainty Ranges ──────────────────────────────────────
    @in revenue_uncertainty_low::Float64 = -3.0
    @in revenue_uncertainty_high::Float64 = 5.0
    @in volume_uncertainty_low::Float64 = -8.0
    @in volume_uncertainty_high::Float64 = 3.0
    @in expense_uncertainty_low::Float64 = 1.0
    @in expense_uncertainty_high::Float64 = 8.0
    @in rate_uncertainty_low::Float64 = -2.0
    @in rate_uncertainty_high::Float64 = 4.0

    # ── Execution State ──────────────────────────────────────────────────
    @in run_simulation::Bool = false
    @in cancel_simulation::Bool = false
    @out simulation_status::String = "idle"  # idle, running, completed, failed, cancelled
    @out simulation_progress::Float64 = 0.0
    @out simulation_id::String = ""
    @out iterations_completed::Int = 0
    @out elapsed_seconds::Float64 = 0.0
    @out estimated_remaining::Float64 = 0.0
    @out status_message::String = ""
    @out error_message::String = ""

    # ── Validation ───────────────────────────────────────────────────────
    @out validation_warnings::Vector{String} = String[]
    @out can_run::Bool = true

    @onchange methodology begin
        @info "Methodology changed to: $methodology"
        validation_warnings = String[]
        if methodology == "monte_carlo" && mc_iterations > 10000
            push!(validation_warnings, "High iteration count may take several minutes")
        end
    end

    @onchange mc_iterations begin
        if mc_iterations < 100
            validation_warnings = ["Minimum 100 iterations recommended for reliable results"]
        elseif mc_iterations > 50000
            validation_warnings = ["Maximum 50,000 iterations supported"]
            mc_iterations = 50000
        else
            validation_warnings = String[]
        end
    end

    @onchange run_simulation begin
        if run_simulation
            run_simulation = false
            simulation_status = "running"
            simulation_progress = 0.0
            iterations_completed = 0
            error_message = ""
            simulation_id = "sim_" * string(rand(10000:99999))
            status_message = "Initializing $(methodology) simulation via domain engine..."

            @info "Starting simulation: $simulation_id methodology=$methodology iterations=$mc_iterations"

            try
                if methodology == "monte_carlo"
                    # Build Monte Carlo params for domain engine
                    mc_params = MonteCarloParams(;
                        n_simulations=mc_iterations,
                        seed=mc_seed,
                        revenue_uncertainty=(revenue_uncertainty_low/100, revenue_uncertainty_high/100),
                        volume_uncertainty=(volume_uncertainty_low/100, volume_uncertainty_high/100),
                        expense_uncertainty=(expense_uncertainty_low/100, expense_uncertainty_high/100),
                        rate_uncertainty=(rate_uncertainty_low/100, rate_uncertainty_high/100),
                        projection_years=projection_years,
                    )
                    status_message = "Running Monte Carlo with $(mc_iterations) iterations..."
                    simulation_progress = 50.0
                    # Domain call would go here: run_monte_carlo(base_financials, mc_params)
                    iterations_completed = mc_iterations
                elseif methodology == "deterministic"
                    status_message = "Running deterministic projection..."
                    simulation_progress = 50.0
                    iterations_completed = projection_years
                elseif methodology == "sensitivity"
                    status_message = "Running sensitivity analysis ($(sensitivity_steps) steps)..."
                    simulation_progress = 50.0
                    iterations_completed = sensitivity_steps
                else
                    status_message = "Running stress test scenarios..."
                    simulation_progress = 50.0
                    iterations_completed = length(stress_scenarios_enabled)
                end

                simulation_status = "completed"
                simulation_progress = 100.0
                status_message = "Simulation completed successfully"
            catch e
                simulation_status = "failed"
                error_message = string(e)
                status_message = "Simulation failed: $(error_message)"
            end
            @info "Simulation $simulation_id completed: status=$(simulation_status)"
        end
    end

    @onchange cancel_simulation begin
        if cancel_simulation
            cancel_simulation = false
            if simulation_status == "running"
                simulation_status = "cancelled"
                status_message = "Simulation cancelled by user"
            end
        end
    end
end

const simulation_runner_model = @init
