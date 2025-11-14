using BenchmarkTools
using UnicodePlots
using LiveLayoutUnicodePlots

# Define the benchmark suite
const SUITE = BenchmarkGroup()

# ============================================================================
# Benchmark functions
# ============================================================================

"""
    plot_sincos(x_vals, sin_vals, cos_vals, use_cache::Bool)

Animated plot using either @live_layout (cached) or live_plot(@layout) (uncached).
When `use_cache=true`, width calculation is cached after the first iteration.
When `use_cache=false`, width calculation happens on every iteration.

Note: Output is redirected to /dev/null to benchmark only the layout calculation,
not the data computation or terminal rendering performance.
"""
function plot_sincos(x_vals, sin_vals, cos_vals, use_cache::Bool)
    n = length(x_vals)
    live_plot = LivePlot()

    # Redirect stdout to /dev/null to avoid measuring terminal I/O
    redirect_stdout(open("/dev/null", "w")) do
        for i in 1:n
            if use_cache
                @live_layout live_plot [
                    lineplot(view(x_vals, 1:i), view(sin_vals, 1:i); title = "sin(x)", name = "sin",
                             xlim = (0, 2π), ylim = (-1, 1), width = :auto, height = :auto),
                    lineplot(view(x_vals, 1:i), view(cos_vals, 1:i); title = "cos(x)", name = "cos",
                             xlim = (0, 2π), ylim = (-1, 1), width = :auto, height = :auto)
                ]
            else
                live_plot(@layout [
                    lineplot(view(x_vals, 1:i), view(sin_vals, 1:i); title = "sin(x)", name = "sin",
                             xlim = (0, 2π), ylim = (-1, 1), width = :auto, height = :auto),
                    lineplot(view(x_vals, 1:i), view(cos_vals, 1:i); title = "cos(x)", name = "cos",
                             xlim = (0, 2π), ylim = (-1, 1), width = :auto, height = :auto)
                ])
            end
        end
    end

    return nothing
end

# ============================================================================
# Benchmark Group: plot_sincos pattern (cached vs uncached)
# ============================================================================

SUITE["plot_sincos"] = BenchmarkGroup(["animation", "caching"])

# Setup: Precompute data for benchmarks
const x_range = range(0, stop = 2π, length = 20)
const x_vals = collect(x_range)
const sin_vals = sin.(x_vals)
const cos_vals = cos.(x_vals)

# WITH CACHE: @live_layout
SUITE["plot_sincos"]["cached"] = @benchmarkable plot_sincos($x_vals, $sin_vals, $cos_vals, true) samples=50 seconds=30

# WITHOUT CACHE: live_plot(@layout)
SUITE["plot_sincos"]["uncached"] = @benchmarkable plot_sincos($x_vals, $sin_vals, $cos_vals, false) samples=50 seconds=30
