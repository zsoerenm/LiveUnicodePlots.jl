# TextPlot Design Document

**Date:** 2025-11-14
**Feature:** Text display elements for status and metrics alongside plots

## Overview

Add `textplot()` function to LiveLayoutUnicodePlots.jl to enable displaying text content (status messages, metrics, logs) alongside plots in layouts. The textplot will participate in the same width/height negotiation as regular plots.

## Use Case

Display live status and metrics information next to plots in terminal dashboards:

```julia
@layout [
    lineplot(x, y; title="Data Stream"),
    textplot("""
        Status: Running
        Count: $count
        Rate: $(rate)/s
        Errors: $errors
    """; width=:auto, title="Metrics")
]
```

## Architecture

### Core Components

**1. TextGraphics Struct**
```julia
struct TextGraphics
    char_width::Int
    char_height::Int
end
```

Mimics BarplotGraphics interface (uses `char_width` not `pixel_width` like BrailleCanvas).

**2. TextPlot Struct**
```julia
struct TextPlot
    graphics::TextGraphics
    decorations::Dict{Symbol, Any}
end
```

Mimics UnicodePlots' plot structure to integrate seamlessly with existing layout system.

**3. Function Signature**
```julia
textplot(content::AbstractString;
         width=:auto,
         height=:auto,
         title::AbstractString="",
         border::Symbol=:solid,
         wrap::Bool=true)
```

**Parameters:**
- `content`: Multiline string (splits on `\n`)
- `width`: `:auto` for automatic negotiation, or fixed integer
- `height`: `:auto` for automatic negotiation, or fixed integer
- `title`: Optional title displayed like plot titles
- `border`: Border style - `:solid` (Unicode box drawing) or `:ascii` (ASCII characters)
- `wrap`: Enable text wrapping (`true`) or truncation (`false`)

### Text Processing Logic

**Width Handling:**
- Fixed width: Wrap (if `wrap=true`) or truncate (if `wrap=false`) lines to fit
- `:auto`: Calculate from longest line, participate in layout negotiation

**Height Handling:**
- Fixed height: Truncate or pad lines to fit
- `:auto`: Calculate from line count (after wrapping), participate in layout negotiation

**Wrapping Behavior:**
- `wrap=true` (default): Long lines wrap at word boundaries (spaces), fallback to character-level if needed
- `wrap=false`: Long lines truncated with `...` indicator, preserves one-to-one line mapping

**Text Operations:**
1. Split content on `\n` into lines
2. Strip trailing whitespace from each line
3. Apply wrapping or truncation based on width
4. Pad lines to uniform width
5. Truncate or pad to match height

### Rendering Format

**Solid border (`:solid`):**
```
┌─ Title ────────┐
│ Status: OK     │
│ Count: 1234    │
│ Rate: 45.2/s   │
└────────────────┘
```

**ASCII border (`:ascii`):**
```
+- Title --------+
| Status: OK     |
| Count: 1234    |
| Rate: 45.2/s   |
+----------------+
```

### Integration with Existing System

**No changes needed to:**
- `helpers.jl`: Already extracts `width`, `height`, `title` from keyword arguments
- `macros.jl`: Already handles any plot-returning function call
- `layout_generation.jl`: `_calculate_overheads()` already checks for `char_width` field

**TextPlot must implement:**
- `Base.show(io::IO, ::MIME"text/plain", tp::TextPlot)`: Render to string for printing
- Graphics field with `char_width` property for overhead calculation
- String output compatible with plot merging functions

### Implementation Files

**New file:** `src/textplot.jl`
- `TextGraphics` struct
- `TextPlot` struct
- `textplot()` function
- `Base.show()` method for rendering
- Helper functions for wrapping, truncation, border rendering

**Modified file:** `src/LiveLayoutUnicodePlots.jl`
- Add `include("textplot.jl")`
- Export `textplot`

**Modified file:** `src/types.jl` (if needed)
- May need to adjust type unions if overhead calculation needs explicit TextPlot support

## Examples

### Basic Metrics Display
```julia
@layout [
    lineplot(x, sin.(x); title="Signal"),
    textplot("Status: OK\nCount: 1234\nRate: 45.2/s";
             width=25, height=10, title="Metrics")
]
```

### With Auto Sizing
```julia
@layout [
    lineplot(x, y; title="Data", width=60),
    textplot(status_text; width=:auto, title="Status")
]
```

### In Grid Layout
```julia
@layout [
    [lineplot(x, sin.(x); title="sin"),
     lineplot(x, cos.(x); title="cos")],
    [textplot(metrics1; width=:auto),
     textplot(metrics2; width=:auto)]
]
```

### With Wrapping Disabled
```julia
textplot("""
    CPU: 45%
    Memory: 2.3 GB
    Disk: 180 GB
"""; wrap=false, width=:auto, title="System")
```

## Testing Strategy

**Unit Tests:**
- Text wrapping at word boundaries
- Text truncation with `...` indicator
- Width/height calculation
- Border rendering (solid and ASCII)
- Empty content handling
- Multi-line content with various line lengths

**Integration Tests:**
- TextPlot in horizontal layouts with plots
- TextPlot in grid layouts
- Width negotiation with `:auto`
- Height negotiation with `:auto`
- Mixed fixed and auto sizing
- Live layouts with textplot

## Future Enhancements (Out of Scope)

- Text alignment (left, center, right)
- ANSI color support
- Padding/margin controls
- Alternative border styles (`:double`, `:rounded`, `:none`)
- Automatic table formatting for structured data
- Vertical text alignment within box
