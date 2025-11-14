# Functions for generating layout code with width and height negotiation

"""
    _calculate_overheads(temp_plots, num_plots)

Calculate overhead (borders, labels, etc.) for each plot by comparing
the actual line length with the canvas width.
"""
function _calculate_overheads(temp_plots, num_plots)
    # Helper function to strip ANSI codes
    strip_ansi = (s::AbstractString) -> replace(s, r"\e\[[0-9;]*m" => "")

    # Helper function to extract canvas width from different plot types
    function get_canvas_width(graphics)
        if hasfield(typeof(graphics), :pixel_width)
            # BrailleCanvas (lineplot, scatterplot, etc.)
            return div(graphics.pixel_width, 2)
        elseif hasfield(typeof(graphics), :char_width)
            # BarplotGraphics and similar
            return graphics.char_width
        else
            # Fallback: try to infer from string representation
            error("Unknown graphics type: $(typeof(graphics))")
        end
    end

    # Calculate overhead for each plot from temporary plots
    overheads = Vector{Int}(undef, num_plots)
    for i in 1:num_plots
        p = temp_plots[i]

        # Get the actual line length (strip ANSI codes for accurate measurement)
        lines = split(string(p), '\n')
        # Find a line with content (not the border lines)
        content_line = lines[2]
        content_line_clean = strip_ansi(content_line)
        line_length = length(content_line_clean)

        # Extract the actual width from the plot's canvas
        plot_width = get_canvas_width(p.graphics)

        # Overhead = total line length - plot width
        overheads[i] = line_length - plot_width
    end

    return overheads
end

"""
    _generate_layout_code(plot_exprs, num_plots, live_plot_expr)

Generate code for horizontal layout with automatic width negotiation.
This function creates expressions that will be executed at runtime to:
1. Create temporary plots to measure overhead
2. Calculate available width and distribute among :auto plots
3. Create final plots with negotiated widths
4. Merge plots horizontally

# Arguments
- `plot_exprs`: Vector of plot expressions from the macro
- `num_plots`: Number of plots in the layout
- `live_plot_expr`: Optional LivePlot instance for caching (nothing for static layouts)
"""
function _generate_layout_code(plot_exprs, num_plots, live_plot_expr)
    # Extract width info and create temporary plots for overhead calculation
    width_exprs = []
    temp_exprs = []
    auto_width_count = 0

    for expr in plot_exprs
        width_val = extract_width(expr)

        # Track width: nothing for auto, value for fixed
        if isnothing(width_val) || width_val == QuoteNode(:auto) || width_val == :(:auto)
            push!(width_exprs, :nothing)
            auto_width_count += 1
        else
            push!(width_exprs, width_val)
        end

        # Always create a temporary plot with width=10 and empty title to measure overhead
        # Remove title to avoid it dominating the overhead calculation
        new_expr = if isnothing(width_val)
            add_width_param(remove_title(expr), 10)
        elseif width_val == QuoteNode(:auto) || width_val == :(:auto)
            replace_auto_width(remove_title(expr), 10)
        else
            # Even for fixed-width plots, create temp with width=10
            add_width_param(remove_title(expr), 10)
        end
        push!(temp_exprs, new_expr)
    end

    # Process each plot expression for final creation with negotiated width
    final_exprs = []
    for expr in plot_exprs
        width_val = extract_width(expr)

        if isnothing(width_val) || width_val == QuoteNode(:auto) || width_val == :(:auto)
            # Replace :auto or add width parameter with negotiated width
            new_expr = if isnothing(width_val)
                add_width_param(expr, :_w)
            else
                replace_auto_width(expr, :_w)
            end
            push!(final_exprs, new_expr)
        else
            # Keep as-is (fixed width)
            push!(final_exprs, expr)
        end
    end

    # Generate common width calculation logic using Expr construction
    # This avoids nested quote issues by building expressions manually
    width_calc_expr = Expr(:block,
        # Create temporary plots for all plots to measure overhead
        :(temp_plots = [$(temp_exprs...)]),

        :(overheads = LiveLayoutUnicodePlots._calculate_overheads(temp_plots, $(num_plots))),

        # Calculate space used by fixed-width plots (width + overhead)
        :(total_fixed = sum(
            isnothing(w) ? 0 : (w + oh)
            for (w, oh) in zip(widths, overheads)
        )),

        # Calculate total overhead for auto-width plots
        :(total_auto_overhead = sum(
            isnothing(w) ? oh : 0
            for (w, oh) in zip(widths, overheads)
        )),

        # Available width to distribute among auto-width plots
        :(available = term_width - total_fixed - total_auto_overhead - padding_between),
        :($(auto_width_count) > 0 ? Int(max(div(available, $(auto_width_count)), 5)) : 0)
    )

    # Generate the runtime code
    if isnothing(live_plot_expr)
        # No caching - always calculate width
        return quote
            let term_width = displaysize(stdout)[2],
                widths = [$(width_exprs...)],
                padding_between = 2 * ($num_plots - 1)

                _w = $width_calc_expr

                LiveLayoutUnicodePlots.LayoutResult(LiveLayoutUnicodePlots.merge_plots_horizontal([$(final_exprs...)]))
            end
        end
    else
        # With LivePlot caching - check cache first, calculate and cache if needed
        return quote
            let lp = $(live_plot_expr),
                term_width = displaysize(stdout)[2],
                widths = [$(width_exprs...)],
                padding_between = 2 * ($num_plots - 1)

                _w = if length(lp.cached_widths) < 1
                    # First time - calculate and cache
                    calculated_w = $width_calc_expr
                    push!(lp.cached_widths, calculated_w)
                    calculated_w
                else
                    # Use cached width
                    lp.cached_widths[1]
                end

                # Use truncation when cached to prevent overflow if data changes
                LiveLayoutUnicodePlots.LayoutResult(LiveLayoutUnicodePlots.merge_plots_horizontal(
                    [$(final_exprs...)];
                    truncate_to_terminal = length(lp.cached_widths) >= 1
                ))
            end
        end
    end
end

"""
    _generate_grid_layout_code(row_exprs, live_plot_expr)

Generate code for grid layout (Vector of Vectors) with automatic width and height negotiation.
This function creates expressions that will be executed at runtime to:
1. For each row: calculate width distribution among plots
2. Calculate height distribution among rows
3. Create all plots with negotiated dimensions
4. Merge horizontally within rows, then vertically

# Arguments
- `row_exprs`: Vector of Vectors of plot expressions (each inner vector is a row)
- `live_plot_expr`: Optional LivePlot instance for caching (nothing for static layouts)
"""
function _generate_grid_layout_code(row_exprs, live_plot_expr)
    # row_exprs is a Vector of Vectors - each inner vector is a row of plots
    num_rows = length(row_exprs)

    # Generate code for each row
    row_codes = []

    for (row_idx, row_plots) in enumerate(row_exprs)
        if !(row_plots isa Expr && row_plots.head == :vect)
            error("@layout grid: each row must be a vector of plot expressions")
        end

        plot_exprs = row_plots.args
        num_plots_in_row = length(plot_exprs)

        # Process each plot in the row for width negotiation (horizontal)
        width_exprs = []
        temp_exprs = []
        auto_width_count = 0

        for expr in plot_exprs
            width_val = extract_width(expr)

            if isnothing(width_val) || width_val == QuoteNode(:auto) || width_val == :(:auto)
                push!(width_exprs, :nothing)
                auto_width_count += 1
            else
                push!(width_exprs, width_val)
            end

            # Create temp plot for overhead calculation
            new_expr = if isnothing(width_val)
                add_width_param(remove_title(expr), 10)
            elseif width_val == QuoteNode(:auto) || width_val == :(:auto)
                replace_auto_width(remove_title(expr), 10)
            else
                add_width_param(remove_title(expr), 10)
            end
            push!(temp_exprs, new_expr)
        end

        # Extract height info and title info for this row (check all plots in the row)
        height_exprs = []
        title_exprs = []
        has_fixed_height = false

        for expr in plot_exprs
            height_val = extract_height(expr)
            title_val = extract_title(expr)

            if isnothing(height_val) || height_val == QuoteNode(:auto) || height_val == :(:auto)
                push!(height_exprs, :nothing)
            else
                push!(height_exprs, height_val)
                has_fixed_height = true
            end

            # Store title expression (it might be a variable or a string literal)
            push!(title_exprs, isnothing(title_val) ? :("") : title_val)
        end

        # Process plots for final creation with negotiated width and height
        final_exprs = []
        for expr in plot_exprs
            width_val = extract_width(expr)
            height_val = extract_height(expr)

            # Handle width
            new_expr = if isnothing(width_val) || width_val == QuoteNode(:auto) || width_val == :(:auto)
                if isnothing(width_val)
                    add_width_param(expr, Symbol("_w_row_$(row_idx)"))
                else
                    replace_auto_width(expr, Symbol("_w_row_$(row_idx)"))
                end
            else
                expr
            end

            # Handle height
            new_expr = if isnothing(height_val) || height_val == QuoteNode(:auto) || height_val == :(:auto)
                if isnothing(height_val)
                    add_height_param(new_expr, Symbol("_h_row_$(row_idx)"))
                else
                    replace_auto_height(new_expr, Symbol("_h_row_$(row_idx)"))
                end
            else
                new_expr
            end

            push!(final_exprs, new_expr)
        end

        # Width calculation for this row
        width_calc_expr = Expr(:block,
            :(temp_plots = [$(temp_exprs...)]),
            :(overheads = LiveLayoutUnicodePlots._calculate_overheads(temp_plots, $(num_plots_in_row))),
            :(total_fixed = sum(isnothing(w) ? 0 : (w + oh) for (w, oh) in zip([$(width_exprs...)], overheads))),
            :(total_auto_overhead = sum(isnothing(w) ? oh : 0 for (w, oh) in zip([$(width_exprs...)], overheads))),
            :(available = term_width - total_fixed - total_auto_overhead - padding_between),
            :($(auto_width_count) > 0 ? Int(max(div(available, $(auto_width_count)), 5)) : 0)
        )

        # Generate row code with caching support
        row_code = if isnothing(live_plot_expr)
            # No caching
            quote
                let widths = [$(width_exprs...)],
                    padding_between = 2 * ($num_plots_in_row - 1),
                    term_width = displaysize(stdout)[2]

                    $(Symbol("_w_row_$(row_idx)")) = $width_calc_expr

                    # Merge plots horizontally for this row
                    LiveLayoutUnicodePlots.merge_plots_horizontal([$(final_exprs...)])
                end
            end
        else
            # With caching
            quote
                let widths = [$(width_exprs...)],
                    padding_between = 2 * ($num_plots_in_row - 1),
                    term_width = displaysize(stdout)[2],
                    lp = $(live_plot_expr)

                    $(Symbol("_w_row_$(row_idx)")) = if length(lp.cached_widths) < $row_idx
                        # First time for this row - calculate and cache
                        calculated_w = $width_calc_expr
                        push!(lp.cached_widths, calculated_w)
                        calculated_w
                    else
                        # Use cached width for this row
                        lp.cached_widths[$row_idx]
                    end

                    # Merge plots horizontally for this row
                    LiveLayoutUnicodePlots.merge_plots_horizontal([$(final_exprs...)])
                end
            end
        end

        push!(row_codes, (row_code, has_fixed_height, height_exprs, title_exprs))
    end

    # Generate height negotiation code
    height_negotiation = quote
        term_height = displaysize(stdout)[1]

        # Height overhead per plot (without title): top border (1) + bottom border (1) + x-axis labels (2) = 4 lines
        # Title adds 1 additional line if present
        # This matches UnicodePlots' default_height() = displaysize(stdout)[1] - 5 (which assumes title is present)
        BASE_HEIGHT_OVERHEAD = 4

        # Collect height info for each row
        row_heights = []
        row_overheads = []
        auto_height_rows = []
        total_fixed_height = 0

        $(map(enumerate(row_codes)) do (idx, (_, has_fixed, heights, titles))
            if has_fixed
                quote
                    # Row $idx has fixed height - take maximum and add overhead
                    max_h = maximum(h for h in [$(heights...)] if !isnothing(h))
                    # Calculate overhead for this row based on titles
                    row_titles = [$(titles...)]
                    # Maximum overhead in the row (if any plot has a title, we need the extra line)
                    row_overhead = BASE_HEIGHT_OVERHEAD + (any(!isempty(String(t)) for t in row_titles) ? 1 : 0)
                    row_height_with_overhead = max_h + row_overhead
                    push!(row_heights, max_h)
                    push!(row_overheads, row_overhead)
                    total_fixed_height += row_height_with_overhead
                end
            else
                quote
                    # Row $idx has auto height
                    row_titles = [$(titles...)]
                    # Calculate overhead for this row based on titles
                    row_overhead = BASE_HEIGHT_OVERHEAD + (any(!isempty(String(t)) for t in row_titles) ? 1 : 0)
                    push!(row_heights, nothing)
                    push!(row_overheads, row_overhead)
                    push!(auto_height_rows, $idx)
                end
            end
        end...)

        # Calculate height for auto rows
        num_auto_rows = length(auto_height_rows)
        if num_auto_rows > 0
            # Available height = terminal height - fixed row heights (with overhead) - spacing between rows
            available_height = term_height - total_fixed_height - ($num_rows - 1)

            # Distribute among auto rows, accounting for each row's overhead
            for row_idx in auto_height_rows
                # Subtract this row's overhead to get the canvas height
                canvas_height = Int(max(div(available_height, num_auto_rows) - row_overheads[row_idx], 5))
                row_heights[row_idx] = canvas_height
            end
        end
    end

    # Generate final code with row rendering
    final_code = quote
        let term_width = displaysize(stdout)[2]
            $height_negotiation

            # Generate each row with calculated heights
            rows = String[]
            $(map(enumerate(row_codes)) do (idx, (row_code, _, _, _))
                quote
                    $(Symbol("_h_row_$(idx)")) = row_heights[$idx]
                    push!(rows, $row_code)
                end
            end...)

            # Merge rows vertically
            result = LiveLayoutUnicodePlots.merge_plots_vertical(rows)

            $(if isnothing(live_plot_expr)
                :(LiveLayoutUnicodePlots.LayoutResult(result))
            else
                quote
                    # Use truncation when cached
                    if length($(live_plot_expr).cached_widths) >= $num_rows
                        # Apply truncation
                        term_width = displaysize(stdout)[2]
                        strip_ansi = (s::AbstractString) -> replace(s, r"\e\[[0-9;]*m" => "")
                        result_lines = split(result, '\n')
                        result_lines = map(result_lines) do line
                            display_length = length(strip_ansi(line))
                            if display_length > term_width
                                LiveLayoutUnicodePlots.truncate_line_preserving_ansi(line, term_width)
                            else
                                line
                            end
                        end
                        result = join(result_lines, '\n')
                    end
                    LiveLayoutUnicodePlots.LayoutResult(result)
                end
            end)
        end
    end

    return final_code
end
