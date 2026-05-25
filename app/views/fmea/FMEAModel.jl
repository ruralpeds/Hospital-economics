"""
Stipple reactive model for FMEA (Failure Mode and Effects Analysis).
IEC 62304 / ISO 14971 risk assessment with RPN scoring and prioritization.
Delegates to RuralHospitalSim FMEA functions for computation.
"""
using Stipple, StippleUI, StipplePlotly

# Import domain layer
using ...RuralHospitalSim: calculate_rpn, assess_risk_acceptability,
    generate_fmea_report, prioritize_failure_modes, FailureMode, FMEAReport


@app begin
    @in left_drawer_open::Bool = true
    # ── Inputs (failure mode entry) ─────────────────────────────────────
    @in fm_id::String = "FM-001"
    @in fm_description::String = ""
    @in fm_component::String = ""
    @in fm_severity::Int = 3
    @in fm_probability::Int = 3
    @in fm_detectability::Int = 3
    @in add_mode::Bool = false
    @in clear_modes::Bool = false
    @in recalculate::Bool = false

    # ── Internal state ──────────────────────────────────────────────────
    @out modes_table::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out modes_count::Int = 0

    # ── Report outputs ──────────────────────────────────────────────────
    @out high_risk_count::Int = 0
    @out average_rpn::Float64 = 0.0
    @out max_rpn::Int = 0
    @out risk_reduction_pct::Float64 = 0.0

    @out prioritized_table::Vector{Dict{String,Any}} = Dict{String,Any}[]

    @out heatmap_data::Vector{PlotData} = PlotData[]
    @out heatmap_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="RPN Risk Matrix (Severity x Probability)"),
        xaxis=[PlotLayoutAxis(title="Probability")],
        yaxis=[PlotLayoutAxis(title="Severity")],
    )

    # Private storage for FailureMode objects
    @private failure_modes::Vector{FailureMode} = FailureMode[]

    # ── Add failure mode handler ────────────────────────────────────────
    @onchange add_mode begin
        if add_mode
            add_mode = false

            mode = FailureMode(;
                id=fm_id,
                description=fm_description,
                component=fm_component,
                severity=fm_severity,
                probability=fm_probability,
                detectability=fm_detectability,
            )
            push!(failure_modes, mode)

            rpn = mode.rpn
            risk = assess_risk_acceptability(rpn)
            risk_str = String(risk)

            push!(modes_table, Dict(
                "id" => mode.id,
                "description" => mode.description,
                "component" => mode.component,
                "severity" => mode.severity,
                "probability" => mode.probability,
                "detectability" => mode.detectability,
                "rpn" => rpn,
                "risk_level" => risk_str,
            ))
            modes_count = length(failure_modes)

            # Auto-increment ID
            fm_id = "FM-$(lpad(string(modes_count + 1), 3, '0'))"

            @info "FMEA: Added $(mode.id), RPN=$(rpn), risk=$(risk_str)"
        end
    end

    # ── Clear modes handler ─────────────────────────────────────────────
    @onchange clear_modes begin
        if clear_modes
            clear_modes = false
            empty!(failure_modes)
            modes_table = Dict{String,Any}[]
            modes_count = 0
            prioritized_table = Dict{String,Any}[]
            high_risk_count = 0
            average_rpn = 0.0
            max_rpn = 0
            risk_reduction_pct = 0.0
            heatmap_data = PlotData[]
            fm_id = "FM-001"
        end
    end

    # ── Generate report handler ─────────────────────────────────────────
    @onchange recalculate begin
        if recalculate
            recalculate = false

            if isempty(failure_modes)
                @warn "FMEA: No failure modes to analyze"
                return
            end

            report = generate_fmea_report(failure_modes)
            high_risk_count = report.high_risk_count
            average_rpn = report.average_rpn
            max_rpn = report.max_rpn
            risk_reduction_pct = report.risk_reduction_pct

            # Prioritized table
            sorted = prioritize_failure_modes(failure_modes)
            prioritized_table = [Dict(
                "id" => m.id,
                "description" => m.description,
                "component" => m.component,
                "severity" => m.severity,
                "probability" => m.probability,
                "detectability" => m.detectability,
                "rpn" => m.rpn,
                "risk_level" => String(assess_risk_acceptability(m.rpn)),
            ) for m in sorted]

            # Heatmap: count of modes at each (severity, probability) cell
            heatmap_matrix = zeros(Float64, 5, 5)
            for m in failure_modes
                heatmap_matrix[m.severity, m.probability] += 1.0
            end

            heatmap_data = [
                PlotData(
                    z=heatmap_matrix,
                    x=["1-Improbable", "2-Remote", "3-Occasional", "4-Probable", "5-Frequent"],
                    y=["1-Negligible", "2-Minor", "3-Moderate", "4-Major", "5-Catastrophic"],
                    plot=StipplePlotly.Charts.PLOT_TYPE_HEATMAP,
                    colorscale="YlOrRd",
                ),
            ]

            @info "FMEA Report: $(length(failure_modes)) modes, high_risk=$(high_risk_count), avg_rpn=$(round(average_rpn, digits=1))"
        end
    end
end

const fmea_model = @init
