"""
Stipple reactive model for Reports & Export (E18).
"""
using Stipple, StippleUI, StipplePlotly

@app begin
    @in left_drawer_open::Bool = true
    @in template_type::String = "financial"
    @in period_from::String = ""
    @in period_to::String = ""
    @in facility_ids::Vector{String} = String[]
    @in sections_enabled::Vector{String} = ["executive_summary","financial_statements","variance_analysis","peer_comparison"]
    @in report_title::String = ""
    @out preview_html::String = ""
    @out generated_report_id::String = ""
    @in generate::Bool = false
    @in export_pdf::Bool = false
    @in export_xlsx::Bool = false
    @in errors::Vector{String} = String[]
    @in running::Bool = false

    @onchange generate begin
        generate || return
        running = true
        errors = String[]
        try
            preview_html = ""
            generated_report_id = ""
        catch e
            push!(errors, sprint(showerror, e))
        finally
            running = false
        end
        generate = false
    end
end

const reports_model = @init
