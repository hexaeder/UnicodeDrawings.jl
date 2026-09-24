using resvg_jll: resvg

# JuliaMono is vendored, so a PNG looks the same on every machine. Its cells are 0.6 em wide,
# and the row height is the font's own line height.
const FONT = joinpath(@__DIR__, "..", "assets", "JuliaMono-Regular.ttf")
const CELL_W = 0.6
const CELL_H = 1.175

"""
    svg(str; size=16) -> String

The diagram as an SVG with one `<text>` per row in JuliaMono.
"""
function svg(str; size=16)
    lines = split(str, '\n')
    margin = size ÷ 2
    w = ceil(Int, maximum(textwidth, lines; init=0) * CELL_W * size + 2margin)
    h = ceil(Int, length(lines) * CELL_H * size + 2margin)
    esc(s) = replace(s, '&' => "&amp;", '<' => "&lt;", '>' => "&gt;")
    io = IOBuffer()
    println(io, """<svg xmlns="http://www.w3.org/2000/svg" width="$w" height="$h">""")
    println(io, """<rect width="100%" height="100%" fill="white"/>""")
    for (i, l) in enumerate(lines)
        # the baseline is the font's ascent, 0.95 em, below the top of the row
        y = margin + ((i - 1) * CELL_H + 0.95) * size
        println(io, """<text x="$margin" y="$y" font-family="JuliaMono" font-size="$size" """,
                """xml:space="preserve">$(esc(l))</text>""")
    end
    println(io, "</svg>")
    String(take!(io))
end

"""
    png(str, out; zoom=2)

Render the diagram to a PNG file at `out` with resvg.
"""
function png(str, out; zoom=2)
    mktempdir() do dir
        path = joinpath(dir, "diagram.svg")
        write(path, svg(str))
        run(`$(resvg()) --skip-system-fonts --use-font-file $FONT --zoom $zoom $path $out`)
    end
    out
end
