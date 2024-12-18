[![Build Status](https://github.com/m3g/ShowMethodTesting.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/m3g/ShowMethodTesting.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![codecov](https://codecov.io/gh/m3g/ShowMethodTesting.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/m3g/ShowMethodTesting.jl)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

# ShowMethodTesting.jl

This is a simple package to help testing `Base.show` methods defined for custom types. The package
exports a single function `parse_show` which, receiving an instance of a structure, will parse the
`show` output of that structure such that:

- Numbers are isolated from other characters (except dots), and compared up to a precision defined 
  by the user (by default equality for integers and rtol=1e-3 for floats).
- Paths are identified and compared only for their last entry (the file name or last directory entry).
- Arrays are simplified and only the first and last elements are compared, to avoid errors associated
  to the number of elements printed. 

The function `parse_show` returns then a custom object which can be compared with `isapprox` to 
the string copy/pasted from the show of the custom type.

## The `parse_show` function:

```julia
parse_show(x; vector_simplify=true, repl=Dict())
```

Parse the output of `show` to a `TestShowString` object, which can be compared with `isapprox` (`≈`).

### Arguments

- `x`: object to parse
- `vector_simplify`: if `true`, only the first and last elements of arrays are kept
- `repl`: dictionary with custom replacements to be made before parsing

### Comparison arguments

The `isapprox` function comparing two `TestShowString` objects has the following keyword arguments:

- `f64`: function to compare two floats
- `i64`: function to compare two integers
- `path`: function to compare two paths
- `assertion_error`: if `true`, throws an `AssertionError` if the comparison fails

### Example

```julia-repl
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

julia> isapprox(parse_show(a), "Object with Int(1), /usr/bin/bash and [1.0, 3.1415, 7.5, 1.4142]"; f64 = (x,y) -> x == y, assertion_error=false)
false
```

Note that in the last line we have set the comparison function for floats to be exact, which is why the comparison fails. And the
`assertion_error` is set to `false`, so the function returns `false` instead of throwing an error.
