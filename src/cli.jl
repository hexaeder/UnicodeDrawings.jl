const USAGE = """
usage: udraw render <scene.jl> [--ruler] [-o <out.txt>]
       udraw lint   <diagram.txt | scene.jl>
       udraw ruler  <diagram.txt | scene.jl>
       udraw locate <diagram.txt | scene.jl> <pattern>
       udraw png    <diagram.txt | scene.jl> <out.png>
       udraw import <file>[:<line>] [-o <scene.jl>]
       udraw put    <scene.jl>
       udraw install-skill

A scene is a Julia file whose last value is a Canvas. `render` prints the diagram and reports
lint issues on stderr. A diagram file may be plain text or contain a ``` fenced block, in which
case the first block is used. `-` reads from stdin. `lint` on a source or markdown file checks every diagram block in it.
Exit status is 1 if lint finds errors.

`import` turns the diagram block at <line> of a file (a docstring, a markdown file, a plain
diagram) into a scene. `put` renders that scene and writes it back into the same block.
`png` renders the diagram as an image, in the bundled JuliaMono font. `install-skill` links
`skill/` into ~/.claude/skills so Claude finds the guide.
"""

"""
    runscene(path) -> Canvas

Evaluate a scene file in a fresh module that has UnicodeDrawings loaded.
"""
function runscene(path)
    m = Module(:Scene)
    Core.eval(m, :(using UnicodeDrawings))
    c = Base.include(m, path)
    c isa Canvas || error("$path must end with the Canvas, got a $(typeof(c))")
    c
end

# A failing scene is reported as its message plus the scene lines that led there, not as a
# full stacktrace, followed by what was drawn up to that point.
function scene_error(path, err)
    e = err isa LoadError ? err.error : err
    println(stderr, "error: ", sprint(showerror, e))
    for fr in stacktrace(catch_backtrace())
        String(fr.file) == abspath(path) && println(stderr, "  at $(path):$(fr.line)")
    end
    if LAST_CANVAS[] isa Canvas
        println(stderr, "drawn so far:")
        ruler(stderr, render(LAST_CANVAS[]))
    end
    1
end

function fenced(str)
    lines = split(str, '\n')
    i = findfirst(startswith("```"), lines)
    isnothing(i) && return str
    j = something(findnext(startswith("```"), lines, i + 1), length(lines) + 1)
    join(lines[i+1:j-1], '\n')
end

# A scene is a Julia file that makes a Canvas; any other file holds finished diagrams.
isscene(path) = endswith(path, ".jl") && occursin("Canvas()", read(path, String))

# The diagram text for a scene (rendered) or a text file (as is).
function diagram(path)
    isscene(path) && return render(runscene(path))
    fenced(path == "-" ? read(stdin, String) : read(path, String))
end

function report(str; io=stderr, name="lint")
    issues = lintreport(io, str)
    nerr = count(i -> i.level == :error, issues)
    lines = split(str, '\n')
    size = "$(maximum(textwidth, lines; init=0))×$(length(lines))"
    println(io, "$name: $nerr errors, $(length(issues) - nerr) warnings, $size")
    nerr == 0 ? 0 : 1
end

# Every diagram block of a source file, with issues reported at their line in the file.
function lint_file(path)
    lines = readlines(path)
    status = 0
    for b in diagram_blocks(lines)
        str = blocktext(lines, b)
        buf = IOBuffer()
        status = max(status, report(str; io=buf, name="$path:$(b[1])"))
        out = String(take!(buf))
        # issue positions are block-relative; shift them to file lines
        out = replace(out, r"^(\d+):(\d+):"m => m -> begin
            y, x = parse.(Int, split(m[1:end-1], ':'))
            "$path:$(y + b[1]):$(x + length(b[3])):"
        end)
        print(stderr, out)
    end
    status
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

function (@main)(args)
    isempty(args) && (print(stderr, USAGE); return 2)
    cmd, rest = args[1], args[2:end]
    if cmd == "render" && !isempty(rest)
        out = findfirst(==("-o"), rest)
        str = try
            render(runscene(rest[1]))
        catch err
            return scene_error(rest[1], err)
        end
        if "--ruler" in rest
            ruler(stdout, str)
        elseif isnothing(out)
            println(str)
        else
            write(rest[out+1], str * "\n")
        end
        return report(str)
    elseif cmd == "import" && !isempty(rest)
        m = match(r"^(.*?)(?::(\d+))?$", rest[1])
        scene = try
            import_file(m.captures[1], isnothing(m.captures[2]) ? nothing : parse(Int, m.captures[2]))
        catch err
            println(stderr, "error: ", sprint(showerror, err))
            return 1
        end
        out = findfirst(==("-o"), rest)
        isnothing(out) ? print(scene) : write(rest[out+1], scene)
    elseif cmd == "put" && length(rest) == 1
        path, line, new = try
            put_scene(rest[1])
        catch err
            return scene_error(rest[1], err)
        end
        println(stderr, "wrote $path:$line")
        return report(new)
    elseif cmd == "lint" && length(rest) == 1
        path = rest[1]
        return path == "-" || isscene(path) ? report(diagram(path)) : lint_file(path)
    elseif cmd == "ruler" && length(rest) == 1
        ruler(stdout, diagram(rest[1]))
    elseif cmd == "png" && length(rest) == 2
        png(diagram(rest[1]), rest[2])
    elseif cmd == "install-skill" && isempty(rest)
        return install_skill()
    elseif cmd == "locate" && length(rest) == 2
        for (x, y) in locate(diagram(rest[1]), rest[2])
            println("$x $y")
        end
    else
        print(stderr, USAGE)
        return 2
    end
    return 0
end
