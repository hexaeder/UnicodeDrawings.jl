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

    @testset "tf!" begin
        c = Canvas()
        b = tf!(c, 1, 3, "K", "1 + s T")
        @test (b.left, b.right, b.top, b.bottom) == (1, 11, 1, 5)
        @test split(render(c), '\n')[3] == "│╶───────╴│"
    end

    @testset "insert and clear" begin
        c = parse_text("╶───┤ ab cd")
        insertcols!(c, 3, 2)
        @test render(c) == "╶─────┤ ab cd"
        c = parse_text("ab cd")
        insertcols!(c, 2, 2)
        @test render(c) == "ab cd"
        c = parse_text("│\n┴")
        insertrows!(c, 2, 1)
        @test render(c) == "│\n│\n┴"
        c = Canvas()
        hline!(c, 1, 10, 2; cap=:full)
        box!(c, 4, 1; label="LV", pad=0, clear=true)
        @test render(c) == "   ┌──┐\n───┤LV├───\n   └──┘"
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

    @testset "import reproduces every example" begin
        for f in EXFILES
            s = load_example(f)
            @test render(UnicodeDrawings.evalscene(UnicodeDrawings.import_scene(s))) == normtext(s)
        end
    end

    @testset "large diagrams import with few fix-ups" begin
        # the two in 103 are axis ticks, which only `stroke!` draws
        for (n, most) in ["101" => 0, "102" => 0, "103" => 2]
            @test nfixups(UnicodeDrawings.import_scene(example(n))) <= most
        end
    end

    @testset "import, edit, put" begin
        mktempdir() do dir
            src = joinpath(dir, "model.jl")
            write(src, "\"\"\"\n    Lag()\n\n```asciiart\n$(example("011"))\n```\n\nText.\n\"\"\"\n")
            scene = joinpath(dir, "scene.jl")
            write(scene, UnicodeDrawings.import_file(src, 5))
            write(scene, replace(read(scene, String), "\"K\"" => "\"K_p\""))
            UnicodeDrawings.put_scene(scene)
            @test occursin("in │   K_p   │ out", read(src, String))
            @test endswith(read(src, String), "```\n\nText.\n\"\"\"\n")
            # a second edit goes through, a hand edit in between is refused
            write(scene, replace(read(scene, String), "\"K_p\"" => "\"K_i\""))
            UnicodeDrawings.put_scene(scene)
            @test occursin("K_i", read(src, String))
            write(src, replace(read(src, String), "K_i" => "K_x"))
            @test_throws ErrorException UnicodeDrawings.put_scene(scene)
        end
    end

    @testset "scene $n" for n in SCENES
        @test checkscene(n; show=false)
    end
end
