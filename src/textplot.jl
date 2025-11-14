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
    _render_with_border(lines::Vector{String}, width::Int, title::AbstractString, border::Symbol)

Render text lines with borders. Width is the content width (excluding borders).
Returns a vector of strings including border lines and optional title line.
Matches UnicodePlots style: title on separate line above box, simple borders.
"""
function _render_with_border(lines::Vector{String}, width::Int, title::AbstractString, border::Symbol)
    # Choose border characters
    if border == :solid
        tl, tr, bl, br = '┌', '┐', '└', '┘'
        horiz, vert = '─', '│'
    elseif border == :ascii
        tl, tr, bl, br = '+', '+', '+', '+'
        horiz, vert = '-', '|'
    else
        error("Unknown border style: $border. Use :solid or :ascii")
    end

    bordered = String[]

    # ANSI color codes matching UnicodePlots
    # Title: bright white + bold (\e[97;1m)
    # Border: gray (\e[38;5;8m)
    # Reset: \e[0m
    title_color = "\e[97;1m"
    border_color = "\e[38;5;8m"
    reset = "\e[0m"

    # Add title on separate line if present (matching UnicodePlots style)
    # UnicodePlots format: 6 spaces + braille spaces + colored bold title + braille spaces + space
    if !isempty(title)
        # Use braille space (U+2800) like UnicodePlots for proper alignment
        braille_space = '⠀'
        # Calculate padding to center title over the box
        # Box total width = width + 2 (for borders)
        box_width = width + 2
        title_padded = lpad(rpad(title, div(box_width + length(title), 2)), box_width)
        # Apply color to title text only, braille spaces stay uncolored
        title_with_color = replace(title_padded, title => title_color * title * reset)
        # Add leading spaces and braille padding to match UnicodePlots
        title_line = "      " * replace(title_with_color, ' ' => braille_space) * " "
        push!(bordered, title_line)
    end

    # Simple top border (no title decoration)
    # Add leading spaces and gray color to match UnicodePlots
    top_line = "      " * border_color * string(tl, horiz ^ width, tr) * reset * " "
    push!(bordered, top_line)

    # Content lines with side borders (borders are gray)
    for line in lines
        # Pad line to width
        padded = rpad(line, width)
        content_line = "      " * border_color * string(vert) * reset * padded * border_color * string(vert) * reset * " "
        push!(bordered, content_line)
    end

    # Bottom border (gray)
    bottom_line = "      " * border_color * string(bl, horiz ^ width, br) * reset * " "
    push!(bordered, bottom_line)

    return bordered
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
    # Process content to get lines
    # For auto sizing, we need to process first to determine dimensions

    # Calculate actual width
    actual_width = if width == :auto
        # Find longest line in content
        input_lines = split(content, '\n', keepempty=true)
        max_line_length = maximum(length(rstrip(String(line))) for line in input_lines)
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

    # Create graphics with actual dimensions
    graphics = TextGraphics(actual_width, actual_height)

    # Store all parameters in decorations
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

"""
    Base.show(io::IO, ::MIME"text/plain", tp::TextPlot)

Render the TextPlot to a string for display.
"""
function Base.show(io::IO, ::MIME"text/plain", tp::TextPlot)
    content = tp.decorations[:content]
    width = tp.graphics.char_width
    height = tp.graphics.char_height
    title = tp.decorations[:title]
    border = tp.decorations[:border]
    wrap = tp.decorations[:wrap]

    # Process text
    lines = _process_text(content, width, height, wrap)

    # Pad to height if needed
    while length(lines) < height
        push!(lines, "")
    end

    # Render with border
    bordered_lines = _render_with_border(lines, width, title, border)

    # Output
    print(io, join(bordered_lines, '\n'))
end

"""
    Base.show(io::IO, tp::TextPlot)

Render the TextPlot to a string for display (fallback for string()).
"""
function Base.show(io::IO, tp::TextPlot)
    # Use the same rendering as MIME"text/plain"
    show(io, MIME("text/plain"), tp)
end
