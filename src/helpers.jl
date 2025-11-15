# Helper functions for extracting and manipulating keyword arguments in plot expressions

"""
    get_kwargs_from_expr(expr)

Extract keyword arguments from a function call expression.
Returns a vector of keyword argument expressions from the :parameters node.
"""
function get_kwargs_from_expr(expr)
    if !(expr isa Expr) || expr.head != :call
        return Expr[]
    end

    # Check if there's a :parameters node (keyword arguments)
    if length(expr.args) >= 2 && expr.args[2] isa Expr && expr.args[2].head == :parameters
        return expr.args[2].args
    end

    return Expr[]
end

"""
    extract_kwarg_value(expr, key::Symbol, default)

Extract the value of a specific keyword argument from a function call expression.
Returns the value if found, otherwise returns the default.
"""
function extract_kwarg_value(expr, key::Symbol, default)
    kwargs = get_kwargs_from_expr(expr)
    for kwarg in kwargs
        if kwarg isa Expr && kwarg.head == :kw && kwarg.args[1] == key
            return kwarg.args[2]
        end
    end
    return default
end

"""
    extract_width(expr)

Extract the width value from a plot expression.
Returns the width value if present, otherwise returns nothing.
"""
function extract_width(expr)
    kwargs = get_kwargs_from_expr(expr)
    for kwarg in kwargs
        if kwarg isa Expr && kwarg.head == :kw && kwarg.args[1] == :width
            return kwarg.args[2]
        end
    end
    return nothing
end

"""
    extract_height(expr)

Extract the height value from a plot expression.
Returns the height value if present, otherwise returns nothing.
"""
function extract_height(expr)
    kwargs = get_kwargs_from_expr(expr)
    for kwarg in kwargs
        if kwarg isa Expr && kwarg.head == :kw && kwarg.args[1] == :height
            return kwarg.args[2]
        end
    end
    return nothing
end

"""
    extract_title(expr)

Extract the title value from a plot expression.
Returns the title value if present, otherwise returns nothing.
"""
function extract_title(expr)
    kwargs = get_kwargs_from_expr(expr)
    for kwarg in kwargs
        if kwarg isa Expr && kwarg.head == :kw && kwarg.args[1] == :title
            return kwarg.args[2]
        end
    end
    return nothing
end

"""
    remove_title(expr)

Remove the title parameter from a plot expression.
This is used when creating temporary plots for overhead calculation.
"""
function remove_title(expr)
    if !(expr isa Expr) || expr.head != :call
        return expr
    end

    new_args = copy(expr.args)

    # Check if there's a :parameters node
    if length(new_args) >= 2 && new_args[2] isa Expr && new_args[2].head == :parameters
        # Filter out title parameter
        new_kwargs = filter(new_args[2].args) do kwarg
            !(kwarg isa Expr && kwarg.head == :kw && kwarg.args[1] == :title)
        end

        if isempty(new_kwargs)
            # Remove the parameters node entirely if no kwargs left
            deleteat!(new_args, 2)
        else
            new_args[2] = Expr(:parameters, new_kwargs...)
        end
    end

    return Expr(:call, new_args...)
end

"""
    add_width_param(expr, width_var)

Add a width parameter to a plot expression (only if not already present).
"""
function add_width_param(expr, width_var)
    if !(expr isa Expr) || expr.head != :call
        return expr
    end

    # Check if width is already present
    if !isnothing(extract_width(expr))
        return expr
    end

    # Add width parameter
    new_args = copy(expr.args)

    # Check if there's a :parameters node
    if length(new_args) >= 2 && new_args[2] isa Expr && new_args[2].head == :parameters
        # Add to existing parameters node
        new_params = copy(new_args[2].args)
        push!(new_params, Expr(:kw, :width, width_var))
        new_args[2] = Expr(:parameters, new_params...)
    else
        # Create new parameters node
        insert!(new_args, 2, Expr(:parameters, Expr(:kw, :width, width_var)))
    end

    return Expr(:call, new_args...)
end

"""
    replace_auto_width(expr, width_var)

Replace width = :auto with a variable name in a plot expression.
"""
function replace_auto_width(expr, width_var)
    if !(expr isa Expr) || expr.head != :call
        return expr
    end

    new_args = copy(expr.args)

    # Find and modify the parameters node
    if length(new_args) >= 2 && new_args[2] isa Expr && new_args[2].head == :parameters
        new_kwargs = []
        for kwarg in new_args[2].args
            if kwarg isa Expr && kwarg.head == :kw && kwarg.args[1] == :width
                # Check if it's :auto (which is represented as QuoteNode(:auto) or just :auto)
                if kwarg.args[2] == QuoteNode(:auto) || kwarg.args[2] == :(:auto)
                    # Replace with width_var
                    push!(new_kwargs, Expr(:kw, :width, width_var))
                else
                    # Keep as is
                    push!(new_kwargs, kwarg)
                end
            else
                push!(new_kwargs, kwarg)
            end
        end
        new_args[2] = Expr(:parameters, new_kwargs...)
    end

    return Expr(:call, new_args...)
end

"""
    add_height_param(expr, height_var)

Add a height parameter to a plot expression (only if not already present).
"""
function add_height_param(expr, height_var)
    if !(expr isa Expr) || expr.head != :call
        return expr
    end

    # Check if height is already present
    if !isnothing(extract_height(expr))
        return expr
    end

    # Add height parameter
    new_args = copy(expr.args)

    # Check if there's a :parameters node
    if length(new_args) >= 2 && new_args[2] isa Expr && new_args[2].head == :parameters
        # Add to existing parameters node
        new_params = copy(new_args[2].args)
        push!(new_params, Expr(:kw, :height, height_var))
        new_args[2] = Expr(:parameters, new_params...)
    else
        # Create new parameters node
        insert!(new_args, 2, Expr(:parameters, Expr(:kw, :height, height_var)))
    end

    return Expr(:call, new_args...)
end

"""
    replace_auto_height(expr, height_var)

Replace height = :auto with a variable name in a plot expression.
"""
function replace_auto_height(expr, height_var)
    if !(expr isa Expr) || expr.head != :call
        return expr
    end

    new_args = copy(expr.args)

    # Find and modify the parameters node
    if length(new_args) >= 2 && new_args[2] isa Expr && new_args[2].head == :parameters
        new_kwargs = []
        for kwarg in new_args[2].args
            if kwarg isa Expr && kwarg.head == :kw && kwarg.args[1] == :height
                # Check if it's :auto
                if kwarg.args[2] == QuoteNode(:auto) || kwarg.args[2] == :(:auto)
                    # Replace with height_var
                    push!(new_kwargs, Expr(:kw, :height, height_var))
                else
                    # Keep as is
                    push!(new_kwargs, kwarg)
                end
            else
                push!(new_kwargs, kwarg)
            end
        end
        new_args[2] = Expr(:parameters, new_kwargs...)
    end

    return Expr(:call, new_args...)
end

"""
    extract_signature_params(expr)

Extract signature-affecting parameters from a plot expression at macro time.
Returns an expression that will compute a hash tuple of (plot_function, title, xlabel, ylabel, xlim, ylim)
at runtime.

This avoids creating temporary plots just to compute signatures - we hash the parameter values directly.

# Examples
```julia
expr = :(lineplot(x, y; title="Test", xlim=(0, 1)))
sig_expr = extract_signature_params(expr)
# Returns: :(hash((Symbol("lineplot"), "Test", nothing, nothing, (0, 1), nothing)))
```
"""
function extract_signature_params(expr)
    # Extract the plot function name
    plot_fn = if expr isa Expr && expr.head == :call
        if expr.args[1] isa Symbol
            QuoteNode(expr.args[1])
        else
            # Handle namespaced functions like UnicodePlots.lineplot
            QuoteNode(expr.args[1])
        end
    else
        QuoteNode(:unknown)
    end

    # Extract signature-affecting parameters
    title = extract_kwarg_value(expr, :title, nothing)
    xlabel = extract_kwarg_value(expr, :xlabel, nothing)
    ylabel = extract_kwarg_value(expr, :ylabel, nothing)
    xlim = extract_kwarg_value(expr, :xlim, nothing)
    ylim = extract_kwarg_value(expr, :ylim, nothing)

    # Generate expression to hash these values at runtime
    # Note: We use the actual values (which may be variables) so they're evaluated at runtime
    return :(hash(($(plot_fn), $(title), $(xlabel), $(ylabel), $(xlim), $(ylim))))
end

"""
    compute_plot_signature(plot)::UInt64

Compute a hash signature for a plot based on characteristics that affect overhead:
- Plot type (graphics type)
- Decorations (axis limits, corner labels)
- Title presence and content
- X/Y axis labels

Used for cache invalidation in LivePlot to detect when overhead may have changed.

# Examples
```julia
p1 = lineplot(1:5, 1:5; title="Test")
p2 = lineplot(1:5, 1:5; title="Test")
sig1 = compute_plot_signature(p1)
sig2 = compute_plot_signature(p2)
@assert sig1 == sig2  # Same characteristics = same signature

p3 = lineplot(1:5, 1:5; title="Different")
sig3 = compute_plot_signature(p3)
@assert sig1 != sig3  # Different title = different signature
```
"""
function compute_plot_signature(plot)::UInt64
    # Start with graphics type (BrailleCanvas vs TextGraphics vs BarplotGraphics, etc.)
    h = hash(typeof(plot.graphics))

    # Include decoration information (axis limits stored as corner labels)
    if hasfield(typeof(plot), :decorations)
        h = hash(plot.decorations, h)
    end

    # For UnicodePlots: title, xlabel, ylabel are stored as RefValue{String}
    if hasfield(typeof(plot), :title)
        h = hash(plot.title[], h)  # Extract value from RefValue
    end
    if hasfield(typeof(plot), :xlabel)
        h = hash(plot.xlabel[], h)
    end
    if hasfield(typeof(plot), :ylabel)
        h = hash(plot.ylabel[], h)
    end

    return h
end
