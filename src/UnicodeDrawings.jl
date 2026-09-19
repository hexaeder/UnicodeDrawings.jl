module UnicodeDrawings

export Canvas, render, parse_text, lint, lintreport, ruler, locate
export box!, wire!, hline!, vline!, stroke!, text!, mark!, arrow!

include("glyphs.jl")
include("canvas.jl")
include("draw.jl")
include("lint.jl")

Base.show(io::IO, ::MIME"text/plain", c::Canvas) = print(io, render(c))

end # module
