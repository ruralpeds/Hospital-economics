# ============================================================================
# Formatting Utilities
# ============================================================================

"""
    format_currency(amount::Real; cents::Bool=true) -> String

Format a numeric value as US currency.

# Examples
```julia
format_currency(1234567.89)   # "\$1,234,567.89"
format_currency(-500.0)       # "(\$500.00)"
format_currency(1000; cents=false)  # "\$1,000"
```
"""
function format_currency(amount::Real; cents::Bool=true)
    negative = amount < 0
    abs_amount = abs(Float64(amount))

    if cents
        dollars = floor(Int, abs_amount)
        c = round(Int, (abs_amount - dollars) * 100)
        if c == 100
            dollars += 1
            c = 0
        end
        dollar_str = _add_commas(dollars)
        formatted = "\$$dollar_str.$(lpad(c, 2, '0'))"
    else
        dollars = round(Int, abs_amount)
        dollar_str = _add_commas(dollars)
        formatted = "\$$dollar_str"
    end

    return negative ? "($formatted)" : formatted
end

"""
    format_percentage(value::Real; digits::Int=1) -> String

Format a numeric value (expressed as a decimal fraction) as a percentage.

# Examples
```julia
format_percentage(0.0523)    # "5.2%"
format_percentage(-0.031; digits=2)  # "-3.10%"
```
"""
function format_percentage(value::Real; digits::Int=1)
    pct = Float64(value) * 100.0
    return string(round(pct; digits=digits), "%")
end

"""
    format_ratio(value::Real; digits::Int=2) -> String

Format a numeric ratio with a fixed number of decimal places.

# Examples
```julia
format_ratio(2.456)       # "2.46"
format_ratio(0.5; digits=3)  # "0.500"
```
"""
function format_ratio(value::Real; digits::Int=2)
    return string(round(Float64(value); digits=digits))
end

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

"""Insert commas into an integer string for thousands separators."""
function _add_commas(n::Integer)
    s = string(abs(n))
    len = length(s)
    parts = String[]
    idx = len
    while idx > 0
        start = max(1, idx - 2)
        push!(parts, s[start:idx])
        idx = start - 1
    end
    return join(reverse(parts), ",")
end
