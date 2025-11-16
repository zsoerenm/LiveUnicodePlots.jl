# TextPlot implementation for displaying text content in layouts
# Uses UnicodePlots' Plot interface for consistency

using UnicodePlots: Plot, GraphicsArea

"""
    TextGraphics <: GraphicsArea

Graphics structure for text display, compatible with UnicodePlots' Plot interface.
Implements the required methods: nrows, ncols, print_row, and preprocess!.
"""
mutable struct TextGraphics <: GraphicsArea
    lines::Vector{String}      # Processed text lines to display
    char_width::Int            # Width in characters
    char_height::Int           # Height in lines (number of rows)
    visible::Bool              # Required by UnicodePlots' show method
end

# Required interface methods for UnicodePlots' Plot

"""
    UnicodePlots.nrows(g::TextGraphics)

Return the number of rows (lines) in the text graphics.
"""
UnicodePlots.nrows(g::TextGraphics) = g.char_height

"""
    UnicodePlots.ncols(g::TextGraphics)

Return the number of columns (width) in the text graphics.
"""
UnicodePlots.ncols(g::TextGraphics) = g.char_width

"""
    UnicodePlots.print_row(io::IO, print_nocol::Function, print_color::Function, g::TextGraphics, row::Int)

Print a specific row of the text graphics. This is called by UnicodePlots' show method.
"""
function UnicodePlots.print_row(io::IO, print_nocol::Function, print_color::Function, g::TextGraphics, row::Int)
    if row <= length(g.lines)
        # Pad line to exact width
        line = rpad(g.lines[row], g.char_width)
        print_nocol(io, line)
    else
        # Empty line if beyond content
        print_nocol(io, " " ^ g.char_width)
    end
end

"""
    UnicodePlots.preprocess!(io::IO, g::TextGraphics)

Preprocessing step called before rendering. Returns a postprocessing function.
For TextGraphics, no preprocessing is needed.
"""
function UnicodePlots.preprocess!(::IO, ::TextGraphics)
    # Return a no-op postprocessing function that takes the graphics object as argument
    return (g) -> nothing
end

# Helper functions for text processing

"""
    _wrap_line(line::AbstractString, max_width::Int)

Wrap a single line at word boundaries, returning vector of wrapped lines.
Falls back to character-level wrapping if word is longer than max_width.
"""
function _wrap_line(line::AbstractString, max_width::Int)
    if length(line) <= max_width
        return [line]
    end

    wrapped = String[]
    remaining = line

    while length(remaining) > max_width
        # Try to find last space within max_width
        break_pos = findlast(' ', remaining[1:min(max_width, length(remaining))])

        if isnothing(break_pos) || break_pos == 0
            # No space found, break at max_width (character-level)
            push!(wrapped, remaining[1:max_width])
            remaining = remaining[max_width+1:end]
        else
            # Break at space
            push!(wrapped, rstrip(remaining[1:break_pos-1]))
            remaining = lstrip(remaining[break_pos+1:end])
        end
    end

    # Add remaining text
    if !isempty(remaining)
        push!(wrapped, remaining)
    end

    return wrapped
end

"""
    _truncate_line(line::AbstractString, max_width::Int)

Truncate a line to max_width, adding "..." if truncated.
"""
function _truncate_line(line::AbstractString, max_width::Int)
    if length(line) <= max_width
        return line
    end

    # Reserve 3 chars for "..."
    if max_width <= 3
        return "..."[1:max_width]
    end

    return line[1:max_width-3] * "..."
end

"""
    _process_text(content::AbstractString, width::Int, height::Union{Int,Nothing}, wrap::Bool)

Process text content: split into lines, apply wrapping or truncation, and limit height.
Returns a vector of strings (processed lines).
"""
function _process_text(content::AbstractString, width::Int, height::Union{Int,Nothing}, wrap::Bool)
    # Split on newlines
    input_lines = split(content, '\n', keepempty=true)

    # Process each line (wrap or truncate)
    processed_lines = String[]
    for line in input_lines
        line_str = rstrip(String(line))

        if wrap
            # Wrap the line
            wrapped = _wrap_line(line_str, width)
            append!(processed_lines, wrapped)
        else
            # Truncate the line
            truncated = _truncate_line(line_str, width)
            push!(processed_lines, truncated)
        end
    end

    # Limit height if specified
    if !isnothing(height) && length(processed_lines) > height
        processed_lines = processed_lines[1:height]
    end

    return processed_lines
end

"""
    textplot(content::AbstractString;
             width=:auto,
             height=:auto,
             title::AbstractString="",
             border::Symbol=:solid,
             wrap::Bool=true)

Create a text display element that can be used in layouts alongside plots.
Returns a UnicodePlots.Plot object for consistency with other plot types.

# Arguments
- `content`: Text content to display (multiline strings supported)
- `width`: Width in characters or `:auto` for automatic sizing
- `height`: Height in lines or `:auto` for automatic sizing
- `title`: Optional title displayed at top
- `border`: Border style - `:solid` (Unicode), `:ascii`, `:bold`, `:dashed`, `:dotted`, or `:none`
- `wrap`: Enable word wrapping (`true`) or truncate lines (`false`)

# Examples
```julia
@layout [
    lineplot(x, y; title="Data"),
    textplot("Status: OK\\nCount: 1234"; width=25, title="Metrics")
]
```
"""
function textplot(content::AbstractString;
                  width=:auto,
                  height=:auto,
                  title::AbstractString="",
                  border::Symbol=:solid,
                  wrap::Bool=true)
    # Calculate actual width
    actual_width = if width == :auto
        # Find longest line in content
        input_lines = split(content, '\n', keepempty=true)
        max_line_length = maximum(length(rstrip(String(line))) for line in input_lines; init=0)
        max(max_line_length, 5)  # Minimum width of 5
    else
        width
    end

    # Calculate actual height (process text to see how many lines after wrapping)
    temp_lines = _process_text(content, actual_width, nothing, wrap)
    actual_height = if height == :auto
        length(temp_lines)
    else
        height
    end

    # Process text with actual dimensions
    lines = _process_text(content, actual_width, actual_height, wrap)

    # Pad to height if needed
    while length(lines) < actual_height
        push!(lines, "")
    end

    # Create TextGraphics
    graphics = TextGraphics(lines, actual_width, actual_height, true)

    # Create Plot with TextGraphics
    # UnicodePlots will handle borders and title rendering
    plot = Plot(
        graphics;
        title=title,
        border=border,
        # Set labels to empty to maximize content area
        xlabel="",
        ylabel="",
        # Disable decorations that don't make sense for text
        compact=true
    )

    return plot
end
