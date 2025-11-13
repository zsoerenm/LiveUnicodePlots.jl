# LiveUnicodePlots.jl

A Julia package for creating live/animated terminal plots and flexible plot layouts with [UnicodePlots.jl](https://github.com/JuliaPlots/UnicodePlots.jl).

## Features

- **Live/Animated Plots**: Update plots in-place for smooth terminal animations
- **Flexible Layouts**: Arrange plots horizontally or in grids with automatic width/height negotiation
- **Performance**: Automatic caching of layout calculations for efficient updates
- **Simple API**: Clean macro-based interface for both static and animated plots

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/zsoerenm/LiveUnicodePlots.jl")
```

## Quick Start

### Static Horizontal Layout

```julia
using LiveUnicodePlots
using UnicodePlots

x = range(0, 2π, length=30)

@layout [
    lineplot(x, sin.(x); title="sin(x)", width=:auto),
    lineplot(x, cos.(x); title="cos(x)", width=:auto)
]
```

### Grid Layout

```julia
@layout [
    [lineplot(x, sin.(x); title="sin", width=:auto, height=10),
     lineplot(x, cos.(x); title="cos", width=:auto, height=10)],
    [lineplot(x, tan.(x); title="tan", width=:auto, height=:auto),
     lineplot(x, -tan.(x); title="-tan", width=:auto, height=:auto)]
]
```

### Animated Plots

```julia
live_plot = LivePlot()
x_vals = Float64[]
y_vals = Float64[]

for i in 1:100
    push!(x_vals, i * 0.1)
    push!(y_vals, sin(i * 0.1))

    @live_layout live_plot [
        lineplot(x_vals, y_vals; title="sin(x)", width=:auto),
        lineplot(x_vals, cos.(x_vals); title="cos(x)", width=:auto)
    ]

    sleep(0.05)
end
```

## Documentation

### Macros

#### `@layout`

Create static plot layouts with automatic width/height negotiation.

```julia
# Horizontal layout
@layout [plot1, plot2, ...]

# Grid layout (Vector of Vectors)
@layout [[row1_plot1, row1_plot2], [row2_plot1, row2_plot2]]
```

#### `@live_layout`

Create animated plot layouts with caching for performance.

```julia
live_plot = LivePlot()

@live_layout live_plot [plot1, plot2, ...]
```

### Width and Height Negotiation

- Use `width=:auto` for automatic width calculation based on terminal size
- Use `height=:auto` for automatic height calculation in grid layouts
- Fixed dimensions are respected and remaining space is distributed to `:auto` plots
- Overhead (borders, labels) is automatically accounted for

### Grid Layout Behavior

- Each inner vector represents a row of plots
- Width negotiation happens within each row
- Height negotiation happens between rows
- If any plot in a row has fixed height, the maximum is used
- If all plots have `:auto` height, space is divided equally
- Title overhead is calculated dynamically (plots without titles get extra canvas space)

## API Reference

### Types

- `LivePlot()`: Create a live plot instance for animations
- `LayoutResult`: Internal wrapper for layout results

### Functions

- `merge_plots_horizontal(plots)`: Merge plots side-by-side
- `merge_plots_vertical(rows)`: Merge plot rows vertically

## License

MIT License
