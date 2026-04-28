"""RHC/CAH comparison Stipple model (A-08) - abbreviated for speed"""
@app begin
    @in rhc_visits_json::String = "{}"
    @in ar_volumes_json::String = "{}"
    @in non_ar_volumes_json::String = "{}"
    @in mileage_miles::Float64 = 0.0
    @in conversion_cost::Float64 = 50_000.0

    @in is_calculating::Bool = false
    @in error_message::String = ""

    @out rhc_revenue::Float64 = 0.0
    @out cah_revenue::Float64 = 0.0
    @out revenue_difference::Float64 = 0.0
    @out revenue_difference_pct::Float64 = 0.0
    @out roi_pct::Float64 = 0.0
    @out break_even_months::Float64 = 0.0
    @out recommendation::String = ""

    @onbutton calculate_btn begin
        is_calculating = true
        error_message = ""
        try
            visits = isempty(rhc_visits_json) ? Dict() : JSON.parse(rhc_visits_json)
            ar_vols = isempty(ar_volumes_json) ? Dict() : JSON.parse(ar_volumes_json)
            non_ar_vols = isempty(non_ar_volumes_json) ? Dict() : JSON.parse(non_ar_volumes_json)

            payload = Dict(
                "rhc_visits" => visits,
                "ar_volumes" => ar_vols,
                "non_ar_volumes" => non_ar_vols,
                "mileage_miles" => mileage_miles,
                "conversion_cost" => conversion_cost
            )

            result = request(:post, "/api/analytics/rhc-cah", payload)
            if haskey(result, "error")
                error_message = get(result, "error", "Unknown error")
            else
                rhc_revenue = Float64(get(result, "rhc_revenue", 0.0))
                cah_revenue = Float64(get(result, "cah_revenue", 0.0))
                revenue_difference = cah_revenue - rhc_revenue
                revenue_difference_pct = Float64(get(result, "revenue_difference_pct", 0.0))
                roi_pct = Float64(get(result, "roi_pct", 0.0))
                break_even_months = Float64(get(result, "break_even_months", 999.0))
                recommendation = String(get(result, "recommendation", ""))
            end
        catch e
            error_message = "Error: $(sprint(showerror, e))"
        finally
            is_calculating = false
        end
    end
end
