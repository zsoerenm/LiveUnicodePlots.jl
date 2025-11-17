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
Handles if/else expressions by checking all branches (returns nothing if any branch lacks width).
"""
function extract_width(expr)
    # Handle if/else expressions
    if expr isa Expr && expr.head == :if
        # Check all branches - if any branch doesn't have width, return nothing
        then_width = extract_width(expr.args[2])
        if length(expr.args) >= 3
            else_width = extract_width(expr.args[3])
            # Both branches must have same width specification for us to extract it
            if then_width == else_width
                return then_width
            else
                return nothing  # Branches have different widths
            end
        else
            return then_width
        end
    end

    # Handle block expressions
    if expr isa Expr && expr.head == :block
        # Find the actual plot expression in the block (skip LineNumberNodes)
        for arg in expr.args
            if !(arg isa LineNumberNode)
                return extract_width(arg)
            end
        end
        return nothing
    end

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
Handles if/else expressions by recursively processing branches.
"""
function remove_title(expr)
    # Handle if/else expressions
    if expr isa Expr && expr.head == :if
        new_args = Any[expr.args[1]]  # Keep condition
        push!(new_args, remove_title(expr.args[2]))  # Process then-branch
        if length(expr.args) >= 3
            push!(new_args, remove_title(expr.args[3]))  # Process else-branch
        end
        return Expr(:if, new_args...)
    end

    # Handle block expressions
    if expr isa Expr && expr.head == :block
        new_args = Any[]
        for arg in expr.args
            if arg isa LineNumberNode
                push!(new_args, arg)
            else
                push!(new_args, remove_title(arg))
            end
        end
        return Expr(:block, new_args...)
    end

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
Handles if/else expressions by recursively processing branches.
For variables or unsupported expressions, throws an error directing users to use direct expressions.
"""
function add_width_param(expr, width_var)
    # Handle if/else expressions by recursively processing branches
    if expr isa Expr && expr.head == :if
        # expr.args[1] is the condition
        # expr.args[2] is the then-branch
        # expr.args[3] is the else-branch (if present)
        new_args = Any[expr.args[1]]  # Keep the condition unchanged
        push!(new_args, add_width_param(expr.args[2], width_var))  # Process then-branch
        if length(expr.args) >= 3
            push!(new_args, add_width_param(expr.args[3], width_var))  # Process else-branch
        end
        return Expr(:if, new_args...)
    end

    # Handle block expressions (from if/else bodies)
    if expr isa Expr && expr.head == :block
        # Find the actual plot expression in the block (skip LineNumberNodes)
        new_args = Any[]
        for arg in expr.args
            if arg isa LineNumberNode
                push!(new_args, arg)
            else
                push!(new_args, add_width_param(arg, width_var))
            end
        end
        return Expr(:block, new_args...)
    end

    # If it's not a call expression and not an if/else, throw an error
    if !(expr isa Expr) || expr.head != :call
        error("""
            @layout macro cannot inject width into variables.

            You passed a variable to @layout, but the macro needs direct plot expressions
            to automatically distribute width.

            Instead of:
                plot1 = textplot("content"; title="Title")
                @layout [plot1, plot2]

            Use one of these options:

            Option 1 - Inline the plot expressions (recommended):
                @layout [
                    textplot("content"; title="Title"),
                    textplot("more"; title="Title 2")
                ]

            Option 2 - Use if/else expressions inline:
                @layout [
                    if condition
                        textplot("A"; title="Title")
                    else
                        textplot("B"; title="Title")
                    end,
                    textplot("more"; title="Title 2")
                ]

            DO NOT use variables:
                plot1 = textplot("content"; title="Title", width=:auto)  # This won't work!
                @layout [plot1, plot2]  # width=:auto is evaluated at plot creation, not macro time
            """)
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

