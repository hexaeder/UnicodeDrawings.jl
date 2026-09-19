module UnicodeDrawings

export Canvas, render, parse_text, lint, lintreport, ruler, locate
export box!, tf!, wire!, hline!, vline!, stroke!, text!, mark!, arrow!

include("glyphs.jl")
include("canvas.jl")
include("draw.jl")
include("lint.jl")
include("cli.jl")

Base.show(io::IO, ::MIME"text/plain", c::Canvas) = print(io, render(c))

# Run the common paths once while precompiling, so the CLI finds them already compiled.
if ccall(:jl_generating_output, Cint, ()) == 1
    let c = Canvas()
        b = box!(c, 5, 1; label="K\n\n1 + s T", line=:round)
        tf!(c, 40, 3, "1", "s T")
        box!(c, 20, 1, 8, 5; label="A", line=:heavy, align=:left, valign=:top)
        box!(c, 30, 1; label="B", line=:double)
        hline!(c, b.left + 1, b.right - 1, b.cy)
        wire!(c, (1, b.cy), (b.left, b.cy), (b.left, 7), (22, 7), (22, 5); cap=:full)
        wire!(c, (1, 2), (8, 2); over=true, line=:light)
        stroke!(c, 1, 9, '┼')
        text!(c, 3, 8, "in"; align=:right)
        mark!(c, 3, b.cy, "●"); arrow!(c, 4, b.cy, :right; head=:triangle)
        s = render(c)
        lintreport(devnull, s)
        ruler(devnull, s)
        locate(s, "●")
    end
    precompile(main, (Vector{String},))
end

end # module
