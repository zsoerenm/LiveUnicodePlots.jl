"""
    LayoutResult

A wrapper type for layout results that automatically displays in the REPL.
Behaves like a string when converted but displays automatically like UnicodePlots.
"""
struct LayoutResult
    content::String
end

# Make LayoutResult display automatically in REPL
Base.show(io::IO, ::MIME"text/plain", lr::LayoutResult) = print(io, lr.content)

# Allow conversion to string for LivePlot compatibility
Base.String(lr::LayoutResult) = lr.content

"""
    LivePlot

A mutable struct for managing in-place plot updates in the terminal with automatic
width caching for performance.

# Fields
- `num_lines::Int`: Number of lines in the last rendered plot (tracked automatically)
- `first_iteration::Bool`: Whether this is the first render (tracked automatically)
- `cached_widths::Vector{Int}`: Cached width calculations per row for performance (tracked automatically)
- `cached_signatures::Vector{Vector{UInt64}}`: Cached plot signatures for cache invalidation (tracked automatically)

For horizontal layouts, only the first element is used.
For grid layouts, each row has its own cached width and signatures at the corresponding index.
Each signature vector contains one hash per plot in that row.

# Example
```julia
# Create a LivePlot instance
live_plot = LivePlot()

# Animate using @live_layout macro (recommended - clean syntax)
for x in range(0, 2π, length=20)
    push!(x_vals, x)
    push!(y_vals, sin(x))

    @live_layout live_plot [
        lineplot(x_vals, y_vals; title = "sin(x)", width = :auto)
    ]
    sleep(0.05)
end
```
"""
mutable struct LivePlot
    num_lines::Int
    first_iteration::Bool
    cached_widths::Vector{Int}
    cached_signatures::Vector{Vector{UInt64}}

    LivePlot() = new(0, true, Int[], Vector{UInt64}[])
end

"""
    (lp::LivePlot)(plot_content::Union{String,LayoutResult})

Render a plot string in-place, automatically handling terminal cursor movement
and clearing. This provides a clean API for creating animated plots.

# Arguments
- `plot_content`: String or LayoutResult containing the plot(s) to render (typically from @layout)

# Example
```julia
live_plot = LivePlot()

# Use with @layout macro and manual rendering
result = @layout [lineplot(x, y; width=:auto)]
live_plot(result)

# Or use @live_layout for cleaner syntax (recommended)
@live_layout live_plot [lineplot(x, y; width=:auto)]
```
"""
function (lp::LivePlot)(plot_content::Union{String,LayoutResult})
    # Convert to string if needed
    plot_str = plot_content isa LayoutResult ? String(plot_content) : plot_content

    # Move cursor up and clear previous plot (except on first iteration)
    if !lp.first_iteration && lp.num_lines > 0
        # Move cursor up by num_lines
        print("\033[$(lp.num_lines)A")
        # Clear from cursor to end of screen (this handles terminal resizing)
        print("\033[0J")
    end

    # Count lines in the plot string
    lp.num_lines = count('\n', plot_str) + 1

    # Display
    print(plot_str)
    println()
    flush(stdout)

    # Update state
    lp.first_iteration = false

    return nothing
end
