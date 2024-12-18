module ShowMethodTesting

export parse_show

struct TestShowString
    parsed_show::String
end
Base.show(io::IO, ::MIME"text/plain", x::TestShowString) = print(io, x.parsed_show)

function Base.isapprox(
    x::TestShowString,
    y::TestShowString;
    f64=(x1, x2) -> isapprox(x1, x2, rtol=1e-3),
    i64=(x1, x2) -> x1 == x2,
    path=(x1, x2) -> last(splitpath(x1)) == last(splitpath(x2)),
    assertion_error=true,
)
    match(f, x1, x2) = begin
        if !f(x1, x2)
            if assertion_error
                throw(AssertionError("""\n

                    show method comparison with $x1 ($(typeof(x1))) == $x2 ($(typeof(x2)))

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
            all_match = match(i64, value, tryparse(Int, yf))
            continue
        end
        value = tryparse(Float64, xf) # test if xf can be interpreted as a float
        if !isnothing(value)
            all_match = match(f64, value, tryparse(Float64, yf))
            continue
        end
        xf = strip(xf, ',')
        yf = strip(yf, ',')
        if ispath(yf) || ispath(xf) # only compares the last entry for paths
            all_match = match(path, last(splitpath(xf)), last(splitpath(yf)))
            continue
        end
        all_match = match(isequal, xf, yf)
    end
    return all_match
end
Base.isapprox(x::TestShowString, y::String; kargs...) = isapprox(x, parse_show(y); kargs...)
Base.isapprox(x::String, y::TestShowString; kargs...) = isapprox(parse_show(x), y; kargs...)

"""
    parse_show(x; vector_simplify=true, repl=Dict())
    parse_show(x::String; vector_simplify=true, repl=Dict())

Parse the output of `show` to a `TestShowString` object, which can be compared with `isapprox` (`≈`).

# Arguments

- `x`: object to parse
- `vector_simplify`: if `true`, only the first and last elements of arrays are kept
- `repl`: dictionary with custom replacements to be made before parsing

# Comparison arguments

The `isapprox` function comparing two `TestShowString` objects has the following keyword arguments:

- `f64`: function to compare two floats
- `i64`: function to compare two integers
- `path`: function to compare two paths
- `assertion_error`: if `true`, throws an `AssertionError` if the comparison fails

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
```

"""
function parse_show(x;
    vector_simplify=true,
    repl=Dict(),
)
    buff = IOBuffer()
    show(buff, MIME"text/plain"(), x)
    parse_show(String(take!(buff)); vector_simplify, repl)
end

function parse_show(x::String;
    vector_simplify=true,
    repl=Dict(),
)
    # Custom replacements
    s = replace(x, repl...)
    # add spaces between digits and other characters (except dots), to interpret them as numbers
    s = replace(s, r"(?<=\d)(?=[^\d.])|(?<=[^\d.])(?=\d)" => s" ")
    if vector_simplify # keep only first and last array elements
        s = replace(s, r"\[ (\S+).* (\S+)\ ]" => s"[ \1 \2 ]")
    end
    return TestShowString(s)
end

end
