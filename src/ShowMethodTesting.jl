module ShowMethodTesting

export ParsedShow, parse_show

struct ParsedShow
    parsed_show::String
end
Base.show(io::IO, ::MIME"text/plain", x::ParsedShow) = print(io, x.parsed_show)

"""
    parse_show(x; vector_simplify=true, repl=Dict())
    parse_show(x::String; vector_simplify=true, repl=Dict())

Parse the output of `show` to a `ParsedShow` object, which can be compared with `isapprox` (`≈`).

# Arguments

- `x`: object to parse
- `vector_simplify`: if `true`, only the first and last elements of arrays are kept
- `repl`: dictionary with custom replacements to be made before parsing

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

julia> isapprox(parse_show(a), "Object with Int(1), /usr/bin/bash and [1.0, 3.1415, 7.5, 1.4142]"; float_match = (x,y) -> x == y, assertion_error=false)
false
```

Note that in the last line we have set the comparison function for floats to be exact, which is why the comparison fails. And the
`assertion_error` is set to `false`, so the function returns `false` instead of throwing an error.

"""
parse_show(x; vector_simplify=true, repl=Dict()) = parse_show(repr("text/plain", x); vector_simplify, repl)

function parse_show(x::String;
    vector_simplify=true,
    repl=Dict(),
)
    # Custom replacements
    s = x
    for (k, v) in repl
        s = replace(s, k => v)
    end
    # add spaces between digits and other characters (except dots), to interpret them as numbers
    s = replace(s, r"(?<=\d)(?=[^\d.])|(?<=[^\d.])(?=\d)" => s" ")
    if vector_simplify # keep only first and last array elements
        s = replace(s, r"\[ (\S+).* (\S+)\ ]" => s"[ \1 \2 ]")
    end
    return ParsedShow(s)
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
    assertion_error=true,
)
    match(f, x1, x2) = begin
        if !f(x1, x2)
            if assertion_error
                throw(AssertionError("""\n

                    show method comparison failed for $x1 ($(typeof(x1))) == $x2 ($(typeof(x2)))

                    full parsed show strings:

                    $x

                    $y

                """))
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
Base.isapprox(x::ParsedShow, y::String; kargs...) = isapprox(x, parse_show(y); kargs...)
Base.isapprox(x::String, y::ParsedShow; kargs...) = isapprox(parse_show(x), y; kargs...)

end
