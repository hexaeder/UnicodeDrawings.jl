using UnicodeDrawings, Test
using UnicodeDrawings: errors

include("helpers.jl")

# Examples reproduced by a scene in `examples/scenes/`.
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
        # one-character terms with pad=0 still leave room for the bar
        c = Canvas()
        tf!(c, 1, 3, "s", "1"; pad=0)
        @test render(c) == "╭───╮\n│ s │\n│╶─╴│\n│ 1 │\n╰───╯"
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
        # an arrowhead and the sum on it move with their vertical wire, the sign next to it too,
        # and the wire running into the sum stretches
        sum = "╶──→(Σ)────╴\n    +↑+\n     │\n╶────╯"
        for x in 4:6
            c = parse_text(sum)
            insertcols!(c, x, 3)
            @test render(c) == "╶─────→(Σ)────╴\n       +↑+\n        │\n╶───────╯"
        end
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

    @testset "import a docstring block, edit, render" begin
        mktempdir() do dir
            src = joinpath(dir, "model.jl")
            write(src, "\"\"\"\n    Lag()\n\n```\n$(example("011"))```\n\nText.\n\"\"\"\n")
            input = UnicodeDrawings.readinput("$src:5")
            @test (input.scene, input.dy) == (false, 4)
            scene = replace(UnicodeDrawings.import_scene(input.text), "\"K\"" => "\"K_p\"")
            @test occursin("in │   K_p   │ out", render(UnicodeDrawings.runscene(scene, "scene")))
            # the command line picks the same block
            out = joinpath(dir, "out.txt")
            @test redirect_stderr(() -> UnicodeDrawings.main(["render", "$src:5", "-o", out]), devnull) == 0
            @test read(out, String) == example("011")
        end
    end

    @testset "labels that touch" begin
        c = Canvas()
        text!(c, 1, 1, "uc"); text!(c, 3, 1, "Pmin")
        text!(c, 9, 1, "ab"); mark!(c, 11, 1, "+")    # a mark next to a label is fine
        @test [i.msg for i in lint(c)] == ["labels 'uc' and 'Pmin' touch"]
        @test isempty(lint(render(c)))                # the text alone can't tell
    end

    @testset "wire arrows" begin
        c = Canvas()
        b = box!(c, 8, 1; label="G")
        wire!(c, (1, 2), (b.left, 2); arrow=-2)
        wire!(c, (b.right, 2), (b.right + 2, 2), (b.right + 2, 4); arrow=(1, -1), head=:triangle)
        @test render(c) == "       ┌───┐\n╶─────→┤ G ▷─╮\n       └───┘ │\n             ▽"
    end

    @testset "insert into some rows" begin
        c = parse_text("╶─┤A├─┤B├─╴\n\n╶─┤C├─┤D├─╴")
        insertcols!(c, 6, 3; rows=3:3)
        @test render(c) == "╶─┤A├─┤B├─╴\n\n╶─┤C├────┤D├─╴"
    end

    @testset "scenes" begin
        # top-level loops update globals, as in the REPL
        c = UnicodeDrawings.runscene("c = Canvas()\nx = 1\nfor k in 1:2\n    x = box!(c, x, 1).right + 2\nend\nc", "s")
        @test render(c) == "┌──┐ ┌──┐\n└──┘ └──┘"
        @test repr(box!(Canvas(), 3, 1, 11, 5)) == "Box(left=3, right=13, top=1, bottom=5, cx=8, cy=3)"
    end

    @testset "import splits arrows from marks" begin
        scene = UnicodeDrawings.import_scene("╶──→(Σ)──╴\n     ↑\n     ╵")
        @test occursin("arrow!(c, 4, 1, :right)", scene) && occursin("mark!(c, 5, 1, \"(Σ)\")", scene)
        # a limit label centred over a box hangs off that box, not the next one
        scene = UnicodeDrawings.import_scene(" max\n┌───┐ ┌───┐\n│   ├─┤   │\n└───┘ └───┘")
        @test occursin("text!(c, b.cx, b.top - 1, \"max\"; align=:center)", scene)
    end

    @testset "sums, cleared boxes, collisions" begin
        # a wire leaving a sum mark is not running into a word
        @test isempty(lint("╶→(Σ)╴\n   │\n   ╵"))
        @test !isempty(lint("╶→(Sa╴\n   │\n   ╵"))
        # a box dropped behind an arrowhead joins through it
        c = Canvas()
        hline!(c, 1, 12, 2; arrow=-5)
        box!(c, 9, 1; label="Kg", pad=0, clear=true)
        @test split(render(c), '\n')[2] == "╶──────→┤Kg│"
        # a collision names the whole label it hits
        c = Canvas()
        text!(c, 1, 1, "__ Qmax")
        @test_throws r"text \"a\" of \"__ Qmax\"" vline!(c, 6, 1, 3)
    end

    @testset "tf! with a prefix" begin
        c = Canvas()
        tf!(c, 1, 3, "Ki", "s"; prefix="Kp +")
        s = render(c)
        @test s == "╭───────────╮\n│       Ki  │\n│ Kp + ╶──╴ │\n│       s   │\n╰───────────╯"
        scene = UnicodeDrawings.import_scene(s)
        @test occursin("tf!(c, 1, 3, \"Ki\", \"s\"; prefix=\"Kp +\")", scene)
    end

    @testset "render --width" begin
        mktempdir() do dir
            f = joinpath(dir, "d.txt")
            write(f, example("011"))
            run1(w) = redirect_stderr(() -> UnicodeDrawings.main(["render", f, "--width", w, "-o", joinpath(dir, "o")]), devnull)
            @test run1("20") == 0
            @test run1("19") == 1
        end
    end

    @testset "help from docstrings" begin
        all = sprint(UnicodeDrawings.apidocs)
        # drawing first, each shared docstring once
        @test findfirst("    box!(", all) < findfirst("# Julia API", all) < findfirst("    lint(", all)
        @test count("    vline!(", all) == 1
        one = sprint(io -> UnicodeDrawings.apidocs(io, "vline!"))
        @test occursin("hline!(", one) && !occursin("box!(", one)
        @test UnicodeDrawings.apidocs(devnull, "nope") == 1
    end

    @testset "scene $n" for n in SCENES
        @test checkscene(n; show=false)
    end
end
