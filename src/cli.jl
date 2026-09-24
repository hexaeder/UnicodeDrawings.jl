const USAGE = """
usage: udraw render <input> [--ruler] [--locate <pattern>] [--png] [-o <out>]
       udraw import <input> [-o <scene.jl>]
       udraw help [<name>]
       udraw install-skill

<input> is a scene (a Julia file whose last value is a Canvas) or a finished diagram, as a file
or `-` for stdin. In a file with ``` fenced blocks, such as a docstring or markdown file,
`file:LINE` picks the block around that line.

`render` prints the diagram and reports lint issues on stderr; the exit status is 1 if lint
finds errors. `--ruler` adds column and row numbers, `--locate` prints the `x y` of each match
instead of the diagram, and `--png` renders an image, which needs `-o`.

`import` turns a diagram into a scene that reproduces it, to be edited and rendered again.
`help` prints the reference for writing scenes, taken from the docstrings, or the entry
for one `<name>` like `box!`. `install-skill` links `skill/` into ~/.claude/skills so Claude finds the guide.
"""

"""
    runscene(path) -> Canvas

Evaluate a scene file in a fresh module that has UnicodeDrawings loaded. Scenes run with the
scoping of the REPL, so a loop at top level can update a variable like `x += 10`.
"""
runscene(path) = scene_result(path, m -> Base.include(softscope, m, path))
runscene(code, name) = scene_result(name, m -> Base.include_string(softscope, m, code, name))

# The REPL's soft scope, as in `REPL.softscope`.
function softscope(@nospecialize ex)
    ex isa Expr || return ex
    ex.head === :toplevel && return Expr(:toplevel, map(softscope, ex.args)...)
    ex.head in (:meta, :import, :using, :export, :module, :error, :incomplete, :thunk) && return ex
    ex.head === :global && all(x -> x isa Symbol, ex.args) && return ex
    Expr(:block, Expr(:softscope, true), ex)
end

function scene_result(name, run)
    m = Module(:Scene)
    Core.eval(m, :(using UnicodeDrawings))
    c = run(m)
    c isa Canvas || error("$name must end with the Canvas, got a $(typeof(c))")
    c
end

# A failing scene is reported as its message plus the scene lines that led there, not as a
# full stacktrace, followed by what was drawn up to that point.
function scene_error(name, err)
    e = err isa LoadError ? err.error : err
    println(stderr, "error: ", sprint(showerror, e))
    for fr in stacktrace(catch_backtrace())
        String(fr.file) in (name, abspath(name)) && println(stderr, "  at $(name):$(fr.line)")
    end
    if LAST_CANVAS[] isa Canvas
        println(stderr, "drawn so far:")
        ruler(stderr, render(LAST_CANVAS[]))
    end
    1
end

"""
    readinput(arg) -> NamedTuple

What `arg` names: scene code or a diagram, and a name for messages. For a block of a larger
file, `dy` and `dx` are its offset in the file, so lint can report file positions.
"""
function readinput(arg)
    m = match(r"^(.*?)(?::(\d+))?$", arg)
    path = m.captures[1]
    line = isnothing(m.captures[2]) ? nothing : parse(Int, m.captures[2])
    text = path == "-" ? read(stdin, String) : read(path, String)
    name = path == "-" ? "stdin" : path
    if (path == "-" || endswith(path, ".jl")) && occursin("Canvas()", text)
        return (; scene=true, text, name, dy=0, dx=0)
    end
    lines = split(text, '\n')
    b = pick_block(lines, line, name)
    (; scene=false, text=blocktext(lines, b), name, dy=b[1], dx=textwidth(b[3]))
end

# Lint issues on stderr, at file positions for a block of a larger file.
# `diagram` is the scene's canvas, which knows more than its text (which labels are separate).
function report(str, diagram, input)
    buf = IOBuffer()
    issues = lintreport(buf, diagram)
    out = String(take!(buf))
    if input.dy > 0
        out = replace(out, r"^(\d+):(\d+):"m => m -> begin
            y, x = parse.(Int, split(m[1:end-1], ':'))
            "$(input.name):$(y + input.dy):$(x + input.dx):"
        end)
    end
    print(stderr, out)
    nerr = count(i -> i.level == :error, issues)
    lines = split(str, '\n')
    size = "$(maximum(textwidth, lines; init=0))×$(length(lines))"
    label = input.dy > 0 ? "$(input.name):$(input.dy)" : "lint"
    println(stderr, "$label: $nerr errors, $(length(issues) - nerr) warnings, $size")
    nerr == 0 ? 0 : 1
end

function render_cmd(input, opts)
    diagram = if input.scene
        try
            input.name == "stdin" ? runscene(input.text, "stdin") : runscene(input.name)
        catch err
            return scene_error(input.name, err)
        end
    else
        input.text
    end
    str = diagram isa Canvas ? render(diagram) : diagram
    out = get(opts, "-o", nothing)
    shown = get(opts, "--ruler", false) ? sprint(ruler, str) : str * "\n"
    if haskey(opts, "--locate")
        hits = join(("$x $y\n" for (x, y) in locate(str, opts["--locate"])))
        isnothing(out) ? print(hits) : write(out, hits)
    elseif get(opts, "--png", false)
        isnothing(out) && (println(stderr, "error: --png needs -o <out.png>"); return 2)
        png(chomp(shown), out)
    else
        isnothing(out) ? print(shown) : write(out, shown)
    end
    report(str, diagram, input)
end

function import_cmd(input, opts)
    input.scene && (println(stderr, "error: $(input.name) is a scene already"); return 1)
    scene = try
        import_scene(input.text)
    catch err
        println(stderr, "error: ", sprint(showerror, err))
        return 1
    end
    from = input.dy > 0 ? "$(input.name):$(input.dy)" : input.name
    scene = "# imported from $from\n" * scene
    out = get(opts, "-o", nothing)
    isnothing(out) ? print(scene) : write(out, scene)
    0
end

# Positional arguments and options, or nothing if an option lacks its value.
function parseargs(args)
    pos, opts = String[], Dict{String,Any}()
    i = 1
    while i <= length(args)
        a = args[i]
        if a in ("-o", "--locate")
            i < length(args) || return nothing
            opts[a] = args[i+1]
            i += 2
        else
            a in ("--ruler", "--png") ? (opts[a] = true) : push!(pos, a)
            i += 1
        end
    end
    pos, opts
end

"""
    apidocs(io, name=nothing)

The docstrings of the public API: the drawing part (`Canvas`, `Box` and the `!` functions) first,
then the rest, each in source order. With `name`, just that entry.
"""
function apidocs(io::IO, name=nothing)
    m = @__MODULE__
    meta = Base.Docs.meta(m)
    entries = []
    for s in (names(m)..., :Box)
        b = Base.Docs.Binding(m, s)
        haskey(meta, b) || continue
        for d in values(meta[b].docs)
            text = join(d.text)
            # a docstring shared by two names (hline!, vline!) is printed once
            any(e -> e.text == text, entries) && continue
            startswith(text, "    ") || (text = "    $s\n\n" * text)
            drawing = s in (:Canvas, :Box) || endswith(string(s), "!")
            push!(entries, (; s, text, drawing, pos=(!drawing, string(d.data[:path]), d.data[:linenumber])))
        end
    end
    if !isnothing(name)
        # a shared docstring is found by any of the signatures it starts with
        signs(l) = l == "    $name" || startswith(l, "    $name(")
        e = filter(e -> any(signs, split(e.text, '\n')), entries)
        isempty(e) && (println(io, "no entry for $name"); return 1)
        foreach(x -> println(io, x.text), e)
        return 0
    end
    sort!(entries; by=e -> e.pos)
    println(io, "# Drawing\n\nA scene is Julia code: `c = Canvas()`, then the calls below, and `c` as the last value.\n")
    for (i, e) in enumerate(entries)
        i > 1 && e.drawing != entries[i-1].drawing &&
            println(io, "# Julia API\n\nFor using the package from Julia rather than through `udraw`.\n")
        println(io, e.text)
    end
    return 0
end

"""
    install_skill(dir) -> Int

Link `skill/` in the package into Claude's skill directory. It is a symlink, so the installed
skill is the file in the repository and editing the guide needs no reinstall.
"""
function install_skill(dir=joinpath(homedir(), ".claude", "skills"))
    src = joinpath(pkgdir(@__MODULE__), "skill")
    dst = joinpath(dir, "udraw")
    if ispath(dst) && !islink(dst)
        println(stderr, "error: $dst exists and is not a symlink")
        return 1
    end
    mkpath(dir)
    islink(dst) && rm(dst)
    symlink(src, dst)
    println("$dst -> $src")
    # The guide names the package directory, so a moved package sends Claude to a dead path.
    root = Base.contractuser(pkgdir(@__MODULE__))
    if !occursin(root, read(joinpath(src, "SKILL.md"), String))
        println(stderr, "warning: SKILL.md does not mention $root, paths in it may be stale")
    end
    return 0
end

# `udraw help | head` closes the pipe early, which is not an error.
function (@main)(args)
    try
        udraw(args)
    catch err
        err isa Base.IOError && err.code == Base.UV_EPIPE || rethrow()
        0
    end
end

function udraw(args)
    isempty(args) && (print(stderr, USAGE); return 2)
    cmd = args[1]
    cmd == "install-skill" && length(args) == 1 && return install_skill()
    cmd == "help" && length(args) <= 2 && return apidocs(stdout, get(args, 2, nothing))
    cmd in ("-h", "--help") && (print(USAGE); return 0)
    parsed = parseargs(args[2:end])
    if cmd ∉ ("render", "import") || isnothing(parsed) || length(parsed[1]) != 1
        print(stderr, USAGE)
        return 2
    end
    pos, opts = parsed
    input = try
        readinput(only(pos))
    catch err
        println(stderr, "error: ", sprint(showerror, err))
        return 1
    end
    cmd == "render" ? render_cmd(input, opts) : import_cmd(input, opts)
end
