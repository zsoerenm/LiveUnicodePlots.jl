using BenchmarkTools
using UnicodePlots
using LiveLayoutUnicodePlots

# Define the benchmark suite
const SUITE = BenchmarkGroup()

# ============================================================================
# Benchmark functions
# ============================================================================

"""
    plot_sincos(x_vals, sin_vals, cos_vals)

Animated plot benchmark using live_plot(@layout).

Note: Output is redirected to /dev/null to benchmark only the layout calculation,
not the data computation or terminal rendering performance.
"""
function plot_sincos(x_vals, sin_vals, cos_vals)
    n = length(x_vals)
    live_plot = LivePlot()

    # Redirect stdout to /dev/null to avoid measuring terminal I/O
    redirect_stdout(open("/dev/null", "w")) do
        for i in 1:n
            live_plot(@layout [
                lineplot(view(x_vals, 1:i), view(sin_vals, 1:i); title = "sin(x)", name = "sin",
                         xlim = (0, 2π), ylim = (-1, 1), width = :auto, height = :auto),
                lineplot(view(x_vals, 1:i), view(cos_vals, 1:i); title = "cos(x)", name = "cos",
                         xlim = (0, 2π), ylim = (-1, 1), width = :auto, height = :auto)
            ])
        end
    end

    return nothing
end

# ============================================================================
# Benchmark Group: plot_sincos animation pattern
# ============================================================================

SUITE["plot_sincos"] = BenchmarkGroup(["animation"])

# Setup: Precompute data for benchmarks
const x_range = range(0, stop = 2π, length = 20)
const x_vals = collect(x_range)
const sin_vals = sin.(x_vals)
const cos_vals = cos.(x_vals)

# Animation benchmark
SUITE["plot_sincos"]["animation"] = @benchmarkable plot_sincos($x_vals, $sin_vals, $cos_vals) samples=50 seconds=30
