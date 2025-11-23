using ShowMethodTesting
using Test

@testset "Aqua.test_all" begin
    import Aqua
    Aqua.test_all(ShowMethodTesting)
end

@testset "ShowMethodTesting.jl" begin
    using ShowMethodTesting
    struct A
        x::Int
        path::String
        vec::Vector{Float64}
        a::Float32
        b::Float32
        c::Float64
        d::Float64
    end
    Base.show(io::IO, ::MIME"text/plain", a::A) = 
        print(io, """
            Object with Int($(a.x)), $(a.path) and $(a.vec) vector.
            a, b, c, d = $(a.a), $(a.b), $(a.c), $(a.d)
        """)
    a = A(1, "/usr/bin/bash", [1.0, π, 7.5, √2], 1.3f-17, 2.6f17, 1.3e-17, 2.6f17)
    @test parse_show(a) ≈ """
        Object with Int(1), /usr/bin/bash and [1.0, 3.141592653589793, 7.5, 1.4142135623730951] vector.
        a, b, c, d = 1.3e-17, 2.6e17, 1.3e-17, 2.6000000279170253e17
    """
    @test """ 
        Object with Int(1), /usr/bin/bash and [1.0, 3.141592653589793, 7.5, 1.4142135623730951] vector.
        a, b, c, d = 1.3e-17, 2.6e17, 1.3e-17, 2.6000000279170253e17
    """ ≈ parse_show(a)
    @test parse_show("""
        Object with Int(1), /usr/bin/bash and [1.0, 3.141592653589793, 7.5, 1.4142135623730951] vector.
        a, b, c, d = 1.3e-17, 2.6e17, 1.3e-17, 2.6000000279170253e17
    """) ≈ parse_show(a)
    @test_throws "comparison failed" parse_show(a) ≈ "Object with Int(2), /usr/bin/bash and [1.0, 3.141592653589793, 7.5, 1.4142135623730951]"
    # do not throw error with assertion_error == false
    @test !isapprox(parse_show(a), """
    Object with Int(2), /usr/bin/bash and [1.0, 3.141592653589793, 7.5, 1.4142135623730951]"  
    """; assertion_error=false)
    # Test show method
    @test contains(repr("text/plain", parse_show(a)), "Object with Int( 1 )")
    # Test custom multiple substitions (keep only first 3 lines)
    @test parse_show([a, a, a, a]; repl=["/usr/bin/bash" => "", r"^((?:[^\n]*\n){3}).*"s => s"\1"], vector_simplify=false) ≈ """
    4-element Vector{A}:
    A(1, "/usr/bin/bash", [1.0, 3.141592653589793, 7.5, 1.4142135623730951], 1.3f-17, 2.6f17, 1.3e-17, 2.6000000279170253e17)
    A(1, "/usr/bin/bash", [1.0, 3.141592653589793, 7.5, 1.4142135623730951], 1.3f-17, 2.6f17, 1.3e-17, 2.6000000279170253e17)
    """
    @test_throws ArgumentError parse_show([a, a, a, a]; repl=["a", "b"])
    # compact printing
    @test parse_show([1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
        context=:compact => true, mime=nothing, vector_simplify=false
    ) ≈ "[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]"
    @test parse_show([1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
        context=:compact => true, mime=nothing, vector_simplify=true
    ) ≈ "[ 1  10 ]"
end
