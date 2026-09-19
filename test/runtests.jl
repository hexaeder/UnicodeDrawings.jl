using UnicodeDrawings, Test
using UnicodeDrawings: errors

include("helpers.jl")

# Examples reproduced by a scene in `scenes/`.
SCENES = sort([splitext(f)[1] for f in readdir(SCENEDIR) if endswith(f, ".jl")])

# Lint errors the finished diagrams have on purpose (or that are small slips in the docs).
KNOWN_ERRORS = Dict(
    "008" => [(53, 8)],           # `────│` touches the inner box without joining it
    "098" => [(9, 5), (15, 5)],   # axis ticks under the curve
)

@testset "UnicodeDrawings" begin
    @testset "parse and render round trip" begin
        for f in EXFILES
            s = load_example(f)
            @test render(parse_text(s)) == normtext(s)
        end
    end

    @testset "junctions merge" begin
        c = Canvas()
        box!(c, 1, 1, 5, 3)
        wire!(c, (3, 3), (3, 5))
        wire!(c, (1, 2), (5, 2); over=true, cap=:full)
        @test render(c) == "┌───┐\n─────\n└─┬─┘\n  │\n  ╵"

        c = Canvas()
        box!(c, 1, 1, 5, 3; line=:heavy)
        vline!(c, 3, 1, 3)
        @test render(c) == "┏━┯━┓\n┃ │ ┃\n┗━┷━┛"
    end

    @testset "lint" begin
        @test isempty(lint("╶─┬─╴\n  │\n  ╵"))
        # a leader one column off: the `│` runs into the fraction bar
        slip = lint("╶─┬─╴\n   │\n   ╵")
        @test [(i.x, i.y) for i in errors(slip)] == [(4, 2)]
        @test any(i -> occursin("empty space", i.msg), slip)
        # a wire drawn over a box edge is a bridge, not an error
        @test isempty(errors(lint("  ║\n──────\n  ║")))
        @test locate("ab\nxδb", "b") == [(2, 1), (3, 2)]
    end

    @testset "lint on target examples" begin
        for n in ["011", "013", "055", "005", "007", "008", "098", "072", "074", "079", "053"]
            @test [(i.x, i.y) for i in errors(lint(example(n)))] == get(KNOWN_ERRORS, n, [])
        end
    end

    @testset "scene $n" for n in SCENES
        @test checkscene(n; show=false)
    end
end
