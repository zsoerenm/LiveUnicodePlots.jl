# LiveLayoutUnicodePlots.jl

A Julia package for creating live/animated terminal plots and flexible plot layouts with [UnicodePlots.jl](https://github.com/JuliaPlots/UnicodePlots.jl).

[![asciicast](https://asciinema.org/a/gaDph4q0WJ9oyEpcv5YVqDNSm.svg)](https://asciinema.org/a/gaDph4q0WJ9oyEpcv5YVqDNSm)

## Features

- **Live/Animated Plots**: Update plots in-place for smooth terminal animations
- **Flexible Layouts**: Arrange plots horizontally or in grids with automatic width/height negotiation
- **Simple API**: Clean macro-based interface for both static and animated plots

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/zsoerenm/LiveLayoutUnicodePlots.jl")
```

## Quick Start

### Static Horizontal Layout

```julia
using LiveLayoutUnicodePlots
using UnicodePlots

x = range(0, 2π, length=30)

@layout [
    lineplot(x, sin.(x); title="sin(x)"), # equivalent to width=:auto
    lineplot(x, cos.(x); title="cos(x)") # equivalent to width=:auto
]
```

### Grid Layout

```julia
@layout [
    [lineplot(x, sin.(x); title="sin", height=10),
     lineplot(x, cos.(x); title="cos", height=10)],
    [lineplot(x, tan.(x); title="tan", height=:auto),
     lineplot(x, -tan.(x); title="-tan", height=:auto)] # If one row has height=:auto the layout will make use of the entire terminal height
]
```

### Animated Plots

```julia
function plot_sincos()
    live_plot = LivePlot()
    x_vals = Float64[]

    for i in 1:100
        push!(x_vals, i * 0.1)

        live_plot(@layout [
            lineplot(x_vals, sin.(x_vals); title="sin(x)", xlim = (0, 10), ylim = (-1, 1)),
            lineplot(x_vals, cos.(x_vals); title="cos(x)", xlim = (0, 10), ylim = (-1, 1))
        ])

        sleep(0.05)
    end
end
plot_sincos()
```

### Text Elements

Display status messages, metrics, or logs alongside plots:

```julia
using LiveLayoutUnicodePlots
using UnicodePlots

x = range(0, 2π, length=30)

@layout [
    lineplot(x, sin.(x); title="Signal"),
    textplot("""
        Status: Running
        Count: 1234
        Rate: 45.2/s
        Errors: 0
    """; width=25, title="Metrics")
]
```

Text elements support automatic width/height negotiation and word wrapping:

```julia
# Auto width based on content
@layout [
    lineplot(x, cos.(x); title="Data", width=50),
    textplot("Processing...\nProgress: 75%"; width=:auto, title="Status")
]

# Disable wrapping for columnar data
textplot("""
    CPU: 45%
    Memory: 2.3 GB
    Disk: 180 GB
"""; wrap=false, width=:auto, title="System")
```

### Dynamic Plot Switching

You can dynamically switch between different plot types:

```julia
using LiveLayoutUnicodePlots
using UnicodePlots

live_plot = LivePlot()
x = Float64[]
y = Float64[]

for i in 1:100
    push!(x, i * 0.1)
    push!(y, sin(i * 0.1))

    # Dynamically choose plot type based on condition
    plot1 = if length(y) > 50 && maximum(y) > 0.5
        lineplot(x, y; title="Signal")
    else
        textplot("Waiting for signal..."; width=30, title="Status")
    end

    live_plot(@layout [
        plot1,
        lineplot(x, cos.(x); title="Reference")
    ])

    sleep(0.05)
end
```

## Documentation

### Macros

#### `@layout`

Create plot layouts with automatic width/height negotiation.

```julia
# Horizontal layout
@layout [plot1, plot2, ...]

# Grid layout (Vector of Vectors)
@layout [[row1_plot1, row1_plot2], [row2_plot1, row2_plot2]]

# With LivePlot for animations
live_plot = LivePlot()
live_plot(@layout [plot1, plot2, ...])
```

### Width and Height Negotiation

- Use `width=:auto` (or omit the `width` parameter entirely) for automatic width calculation based on terminal size
- Use `height=:auto` for automatic height calculation in grid layouts
- Fixed dimensions are respected and remaining space is distributed to automatically sized plots
- Overhead (borders, labels) is automatically accounted for

### Grid Layout Behavior

- Each inner vector represents a row of plots
- Width negotiation happens within each row
- Height negotiation happens between rows
- If any plot in a row has fixed height, the maximum is used
- If all plots have automatic height calculation, space is divided equally
- Title overhead is calculated dynamically (plots without titles get extra canvas space)

## API Reference

### Types

- `LivePlot()`: Create a live plot instance for animations
- `LayoutResult`: Internal wrapper for layout results

### Functions

- `merge_plots_horizontal(plots)`: Merge plots side-by-side
- `merge_plots_vertical(rows)`: Merge plot rows vertically
- `textplot(content; width, height, title, border, wrap)`: Create text display element

## License

MIT License
