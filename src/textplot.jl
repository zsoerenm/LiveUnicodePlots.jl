# TextPlot implementation for displaying text content in layouts

"""
    TextGraphics

Minimal graphics structure for TextPlot, mimicking UnicodePlots' graphics interface.
Uses char_width/char_height like BarplotGraphics (not pixel_width like BrailleCanvas).
"""
struct TextGraphics
    char_width::Int
    char_height::Int
end

"""
    TextPlot

A plot-like structure for displaying text content with borders, compatible with
LiveLayoutUnicodePlots layout system.
"""
struct TextPlot
    graphics::TextGraphics
    decorations::Dict{Symbol, Any}
end

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

# Arguments
- `content`: Text content to display (multiline strings supported)
- `width`: Width in characters or `:auto` for automatic sizing
- `height`: Height in lines or `:auto` for automatic sizing
- `title`: Optional title displayed at top
- `border`: Border style - `:solid` (Unicode) or `:ascii`
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
    # Placeholder implementation
    graphics = TextGraphics(20, 5)
    decorations = Dict{Symbol, Any}(
        :title => title,
        :width => width,
        :height => height,
        :border => border,
        :wrap => wrap,
        :content => content
    )

    return TextPlot(graphics, decorations)
end
