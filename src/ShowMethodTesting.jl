module ShowMethodTesting

using Test: @test

export ParsedShow, parse_show, @test_show

struct ParsedShow
    parsed_show::String
    vector_simplify::Bool
    repl::Any
end
Base.show(io::IO, ::MIME"text/plain", x::ParsedShow) = print(io, x.parsed_show)

"""
    parse_show(x; vector_simplify=true, repl=())
    parse_show(x::String; vector_simplify=true, repl)

Parse the output of `show` to a `ParsedShow` object, which can be compared with `isapprox` (`≈`).

# Arguments

- `x`: object to parse
- `vector_simplify`: if `true`, only the first and last elements of arrays are kept
- `repl`: container of Pair(s) with custom replacements to be made before parsing. The replacements 
   will be applied from left to right for ordered collections.

# Optional arguments, forwarded to `repr`

- `mime`: MIME type of the representation
- `context`: context of the representation

A `ParsedShow` object can be compared to another `ParsedShow` object or a string with `isapprox`.
See the `isapprox` function for more details.

# Example

```jldoctest
julia> using ShowMethodTesting

julia> struct A
           x::Int
           path::String
           vec::Vector{Float64}
       end

julia> Base.show(io::IO, ::MIME"text/plain", a::A) = print(io, "Object with Int(\$(a.x)), \$(a.path) and \$(a.vec)")

julia> a = A(1, "/usr/bin/bash", [1.0, π, 7.5, √2])
Object with Int(1), /usr/bin/bash and [1.0, 3.141592653589793, 7.5, 1.4142135623730951]

julia> parse_show(a) ≈ "Object with Int(1), /usr/bin/bash and [1.0, 3.1415, 7.5, 1.4142]"
true

julia> isapprox(parse_show(a), "Object with Int(1), /usr/bin/bash and [1.0, 3.1415, 7.5, 1.4142]"; float_match = (x,y) -> x == y, print_diff=false)
false
```

Note that in the last line we have set the comparison function for floats to be exact, which is why the comparison fails. And the
`print_diff` is set to `false`, so the function does not print details about the failed comparison.

"""
function parse_show(x; 
    vector_simplify=true, 
    repl=(), 
    # repr arguments
    mime="text/plain",
    context=nothing
)
    if isnothing(mime)
        parse_show(repr(x; context); vector_simplify, repl)
    else
        parse_show(repr("text/plain", x; context); vector_simplify, repl)
    end
end

function parse_show(x::String;
    vector_simplify=true,
    repl=(),
) 
    if length(repl) > 0 && !(eltype(repl) <: Pair)
        throw(ArgumentError("""\n
            
            The `repl` argument must be a container of Pair(s), e.g. Dict("old" => "new") or [ "old" => "new" ].

        """))
    end
    # Custom replacements
    s = x
    for (k, v) in repl
        s = replace(s, k => v)
    end
    # add spaces between digits and other characters (except dots), to interpret them as numbers
    s = replace(s, r"(?<=\d)(?=[^\d.])|(?<=[^\d.])(?=\d)" => s" ")
    if vector_simplify # keep only first and last array elements
        s = replace(s, r"(\[)([^,\]]+)(,.*,)([^,\]]+)(\])" => s"\1\2 \4\5")
    end
    return ParsedShow(s, vector_simplify, repl)
end

"""
    isapprox(x::ParsedShow, y::ParsedShow
        float_match=(x1, x2) -> isapprox(x1, x2, rtol=1e-3),
        int_match=(x1, x2) -> x1 == x2,
        path_match=(x1, x2) -> last(splitpath(x1)) == last(splitpath(x2)),
        assertion_error=true,
    )
    isapprox(x::ParsedShow, y::String; kargs...) = isapprox(x, parse_show(y); kargs...)
    isapprox(x::String, y::ParsedShow; kargs...) = isapprox(parse_show(x), y; kargs...)

Compare two `ParsedShow` objects, with custom comparison functions for floats, integers and paths.

# Arguments

- `x`: first object to compare
- `y`: second object to compare
- `float_match`: function to compare two floats
- `int_match`: function to compare two integers
- `path_match`: function to compare two paths
- `assertion_error`: if `true`, throws an `AssertionError` if the comparison fails

"""
function Base.isapprox(
    x::ParsedShow,
    y::ParsedShow;
    float_match=(x1, x2) -> isapprox(x1, x2, rtol=1e-3),
    int_match=(x1, x2) -> x1 == x2,
    path_match=(x1, x2) -> last(splitpath(x1)) == last(splitpath(x2)),
    print_diff=true,
)
    match(f, x1, x2) = begin
        if !f(x1, x2)
            if print_diff
                print("""

                    show method comparison failed: '$x1' ($(typeof(x1))) == '$x2' ($(typeof(x2)))

                    full parsed show strings:

                    Parsed show string:
                    ---------------------\n
                """)
                print(x.parsed_show)
                print("""\n

                    Expected output:
                    ---------------------\n
                """)
                print(y.parsed_show)
                print("""\n
                    ---------------------

                """)
            end
            return false
        end
        return true
    end
    # Custom substitutions
    xfields = split(x.parsed_show)
    yfields = split(y.parsed_show)
    all_match = true
    for (xf, yf) in zip(xfields, yfields)
        !all_match && break
        value = tryparse(Int, xf) # test if xf can be interpreted as an integer
        if !isnothing(value)
            all_match = match(int_match, value, tryparse(Int, yf))
            continue
        end
        value = tryparse(Float64, xf) # test if xf can be interpreted as a float
        if !isnothing(value)
            all_match = match(float_match, value, tryparse(Float64, yf))
            continue
        end
        xf = strip(xf, ',')
        yf = strip(yf, ',')
        if ispath(yf) || ispath(xf) # only compares the last entry for paths
            all_match = match(path_match, last(splitpath(xf)), last(splitpath(yf)))
            continue
        end
        all_match = match(isequal, xf, yf)
    end
    return all_match
end
function Base.isapprox(x::ParsedShow, y::String; kargs...) 
    isapprox(
        x, 
        parse_show(y; vector_simplify=x.vector_simplify, repl=x.repl); 
        kargs...
    )
end
Base.isapprox(x::String, y::ParsedShow; kargs...) = isapprox(parse_show(x), y; kargs...)

"""
    @test_show obj ≈ expected_str parse_options=(kwargs1...) match_options=(kwargs2...)

Test if the show output of an object matches an expected string representation.

# Arguments

- `obj`: The object to test
- `expected_str`: Expected string representation
- `parse_options`: Keyword arguments passed to `parse_show`.
- `match_options`: Keyword arguments passed to `isapprox`, to adjust how elements are compared.

"""
"""
    @test_show obj ≈ expected_str parse_options=(kwargs...) match_options=(kwargs...)

Test if the show output of an object matches an expected string representation.

# Arguments
- `obj`: The object to test
- `expected_str`: Expected string representation
- `parse_options`: Keyword arguments passed to `parse_show`
- `match_options`: Keyword arguments passed to `isapprox`
"""
macro test_show(expr...)
    if length(expr) == 0
        throw(ArgumentError("Expression required"))
    end
    
    main_expr = expr[1]
    if !(main_expr isa Expr && main_expr.head === :call && main_expr.args[1] === :≈)
        throw(ArgumentError("Expression must be in the form: obj ≈ expected_str"))
    end
    
    obj = main_expr.args[2]
    expected = main_expr.args[3]
    
    # Initialize empty keyword arguments
    parse_kwargs = []
    match_kwargs = []
    
    # Look for keyword arguments in the remaining arguments
    for arg in expr[2:end]
        if arg isa Expr && arg.head === :(=)
            if arg.args[1] === :parse_options
                # Extract keyword arguments for parse_show
                tuple_expr = arg.args[2]
                for kw in tuple_expr.args
                    if kw isa Expr
                        if kw.head === :(=)
                            key = kw.args[1]
                            value = kw.args[2]
                            # Handle nested => operator
                            if value isa Expr && value.head === :call && value.args[1] === :(=>)
                                push!(parse_kwargs, Expr(:kw, key, Expr(:call, :(=>), esc(value.args[2]), esc(value.args[3]))))
                            else
                                push!(parse_kwargs, Expr(:kw, key, esc(value)))
                            end
                        elseif kw.head === :call && length(kw.args) == 3 && kw.args[1] === :(=>)
                            # Handle repl pairs in arrays
                            push!(parse_kwargs, Expr(:kw, :repl, esc(tuple_expr)))
                            break
                        end
                    end
                end
            elseif arg.args[1] === :match_options
                tuple_expr = arg.args[2]
                for kw in tuple_expr.args
                    if kw isa Expr && kw.head === :(=)
                        push!(match_kwargs, Expr(:kw, kw.args[1], esc(kw.args[2])))
                    end
                end
            end
        end
    end
    
    # Create the final test expression
    return quote
        @test isapprox(
            parse_show($(esc(obj)); $(parse_kwargs...)),
            parse_show($(esc(expected)); $(parse_kwargs...));
            $(match_kwargs...)
        )
    end
end

end