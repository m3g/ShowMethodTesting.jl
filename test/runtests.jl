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
    end
    Base.show(io::IO, ::MIME"text/plain", a::A) = print(io, "Object with Int($(a.x)), $(a.path) and $(a.vec)")
    a = A(1, "/usr/bin/bash", [1.0, π, 7.5, √2])
    @test parse_show(a) ≈ "Object with Int(1), /usr/bin/bash and [1.0, 3.1415, 7.5, 1.4142]"
    @test "Object with Int(1), /usr/bin/bash and [1.0, 3.1415, 7.5, 1.4142]" ≈ parse_show(a)
    @test parse_show("Object with Int(1), /usr/bin/bash and [1.0, 3.1415, 7.5, 1.4142]") ≈ parse_show(a)
    @test_throws AssertionError parse_show(a) ≈ "Object with Int(2), /usr/bin/bash and [1.0, 3.141592653589793, 7.5, 1.4142135623730951]"
    @test !isapprox(parse_show(a), "Object with Int(2), /usr/bin/bash and [1.0, 3.141592653589793, 7.5, 1.4142135623730951]"; assertion_error=false)
    # Test show method
    @test contains(repr("text/plain", parse_show(a)), "Object with Int( 1 )")
    @test parse_show([a, a, a, a]; repl=Dict("/usr/bin/bash" => "", r"^((?:[^\n]*\n){3}).*"s => s"\1")) ≈ """
        4 -element Vector{A}:
        Object with Int( 1 ),  and [ 1.0 1.4142135623730951 ]
        Object with Int( 1 ),  and [ 1.0 1.4142135623730951 ]
    """
end
