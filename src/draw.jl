# `line` names the look of a stroke: its weight plus, for light lines, the corner shape.
function linestyle(line::Symbol, dash)
    weight, style = line === :light  ? (LIGHT, SOLID) :
                    line === :round  ? (LIGHT, ROUND) :
                    line === :heavy  ? (HEAVY, SOLID) :
                    line === :double ? (DOUBLE, SOLID) :
                    error("unknown line $(repr(line)), use :light, :round, :heavy or :double")
    if !isnothing(dash)
        style = dash == 2 ? DASH2 : dash == 3 ? DASH3 : dash == 4 ? DASH4 : error("dash must be 2, 3 or 4")
    end
    weight, style
end

function setarm(a::Arms, d, wt)
    t = collect(a.a)
    t[d] = wt
    Arms(Tuple(t))
end

"""
    wire!(c, points...; line=:round, dash=nothing, cap=:half, over=false)

An orthogonal path through `points`, each an `(x, y)` tuple. The first and last cell only get an
arm pointing along the wire, so a wire ending in open space shows as a half-stroke `╶`, and a
wire ending on a box edge turns it into a junction like `┤`. With `cap=:full` the ends are full
strokes instead; `cap` can also be a tuple to set the two ends separately.

With `over=true` the wire replaces what is underneath instead of joining it. A wire drawn
across a box edge that way leaves a gap in the edge rather than a crossing.
"""
function wire!(c::Canvas, points::Tuple{Int,Int}...; line=:round, dash=nothing, cap=:half, over=false)
    weight, style = linestyle(line, dash)
    arms = Dict{Tuple{Int,Int},Arms}()
    dirs = Int[]
    for (p, q) in zip(points, Base.tail(points))
        p == q && continue
        p[1] == q[1] || p[2] == q[2] || error("wire segment $p → $q is not horizontal or vertical")
        d = p[1] == q[1] ? (q[2] > p[2] ? S : N) : (q[1] > p[1] ? E : W)
        push!(dirs, d)
        dx, dy = OFFSETS[d]
        cur = p
        while cur != q
            nxt = (cur[1] + dx, cur[2] + dy)
            arms[cur] = setarm(get(arms, cur, Arms()), d, weight)
            arms[nxt] = setarm(get(arms, nxt, Arms()), opposite(d), weight)
            cur = nxt
        end
    end
    caps = cap isa Symbol ? (cap, cap) : cap
    if !isempty(dirs)
        caps[1] === :full && (arms[first(points)] = setarm(arms[first(points)], opposite(first(dirs)), weight))
        caps[2] === :full && (arms[last(points)] = setarm(arms[last(points)], last(dirs), weight))
    end
    for ((x, y), a) in arms
        if over
            c.cells[(x, y)] = Cell(a, style, "")
        else
            addarms!(c, x, y, a; style)
        end
    end
    c
end

"""
    stroke!(c, x, y, ch::Char; over=false)

Merge the arms of box-drawing character `ch` into the cell. This is the escape hatch for
details no wire produces, such as a tick mark on a plot axis. With `over=true` the cell becomes
exactly `ch`, whatever was there.
"""
function stroke!(c::Canvas, x, y, ch::Char; over=false)
    over || return addarms!(c, x, y, CHAR_ARMS[ch]; style=CHAR_STYLE[ch])
    c.cells[(x, y)] = Cell(CHAR_ARMS[ch], CHAR_STYLE[ch], "")
    c
end

"""
    erase!(c, x, y)

Clear the cell.
"""
erase!(c::Canvas, x, y) = (delete!(c.cells, (x, y)); c)

hline!(c::Canvas, x1, x2, y; kw...) = wire!(c, (x1, y), (x2, y); kw...)
vline!(c::Canvas, x, y1, y2; kw...) = wire!(c, (x, y1), (x, y2); kw...)

"""
    text!(c, x, y, str; align=:left, over=false)

Write `str` with its first column at `x` (or centered on `x`, or ending at `x`, depending on
`align`). A string with newlines continues on the following rows. Writing onto a stroke is an
error unless `over=true`.
"""
function text!(c::Canvas, x, y, str::AbstractString; align=:left, over=false)
    for (i, line) in enumerate(split(str, '\n'))
        w = textwidth(line)
        x0 = align === :left ? x : align === :center ? x - (w - 1) ÷ 2 : align === :right ? x - w + 1 :
             error("unknown align $(repr(align))")
        puttext!(c, x0, y + i - 1, line; over)
    end
    c
end

"""
    mark!(c, x, y, str)

Text placed on top of whatever is there, such as `●` on a wire or `(+)` at a junction.
"""
mark!(c::Canvas, x, y, str::AbstractString; kw...) = text!(c, x, y, str; over=true, kw...)

const ARROWHEADS = Dict(
    :arrow      => ('↑', '→', '↓', '←'),
    :triangle   => ('△', '▷', '▽', '◁'),
    :solid      => ('▲', '▶', '▼', '◀'),
    :small      => ('▵', '▹', '▿', '◃'),
    :smallsolid => ('▴', '▸', '▾', '◂'),
)
const DIRSYMS = Dict(:up => N, :right => E, :down => S, :left => W)

"""
    arrow!(c, x, y, dir; head=:arrow)

An arrowhead pointing `dir` (`:up`, `:right`, `:down`, `:left`), drawn over whatever is there.
`head` picks the family: `:arrow` (→), `:triangle` (▷), `:solid` (▶), `:small` (▹) or
`:smallsolid` (▸).
"""
arrow!(c::Canvas, x, y, dir::Symbol; head=:arrow) = mark!(c, x, y, string(ARROWHEADS[head][DIRSYMS[dir]]))

"""
A placed box. Besides `x, y, w, h` it has the anchors `left`, `right`, `top`, `bottom` (the
columns and rows of its edges) and `cx`, `cy` (the middle, rounded towards the top left).
"""
struct Box
    x::Int
    y::Int
    w::Int
    h::Int
end

function Base.getproperty(b::Box, s::Symbol)
    s === :left   ? getfield(b, :x) :
    s === :right  ? getfield(b, :x) + getfield(b, :w) - 1 :
    s === :top    ? getfield(b, :y) :
    s === :bottom ? getfield(b, :y) + getfield(b, :h) - 1 :
    s === :cx     ? getfield(b, :x) + (getfield(b, :w) - 1) ÷ 2 :
    s === :cy     ? getfield(b, :y) + (getfield(b, :h) - 1) ÷ 2 :
    getfield(b, s)
end
Base.propertynames(::Box) = (:x, :y, :w, :h, :left, :right, :top, :bottom, :cx, :cy)

"""
    box!(c, x, y, w=nothing, h=nothing; label="", line=:light, dash=nothing,
         align=:center, valign=:middle, pad=1, over=false) -> Box

A box with its top left corner at `(x, y)`. Without `w` and `h` it is sized around the label,
with `pad` spaces on either side. The label may have several lines; `align=:left` puts it `pad`
columns in from the left edge.

Edges join with strokes already on the canvas, like a wire does.
"""
function box!(c::Canvas, x, y, w=nothing, h=nothing; label="", line=:light, dash=nothing,
              align=:center, valign=:middle, pad=1, over=false)
    lines = isempty(label) ? String[] : split(label, '\n')
    tw = maximum(textwidth, lines; init=0)
    w = something(w, tw + 2 + 2pad)
    h = something(h, length(lines) + 2)
    b = Box(x, y, w, h)
    wire!(c, (b.left, b.top), (b.right, b.top), (b.right, b.bottom), (b.left, b.bottom), (b.left, b.top);
          line, dash, over)
    innerw, innerh = w - 2, h - 2
    ytop = b.top + 1 + (valign === :top ? 0 : valign === :middle ? (innerh - length(lines)) ÷ 2 :
                        valign === :bottom ? innerh - length(lines) : error("unknown valign $(repr(valign))"))
    for (i, l) in enumerate(lines)
        lw = textwidth(l)
        xl = align === :left ? b.left + 1 + pad : align === :center ? b.left + 1 + (innerw - lw) ÷ 2 :
             align === :right ? b.right - pad - lw : error("unknown align $(repr(align))")
        puttext!(c, xl, ytop + i - 1, l)
    end
    b
end

"""
    tf!(c, x, y, num, den; line=:round, pad=1) -> Box

A transfer-function block: `num` over `den` with a fraction bar on row `y`, so the block sits on
a signal wire drawn along `y`. `x` is the left edge.
"""
function tf!(c::Canvas, x, y, num, den; line=:round, pad=1)
    b = box!(c, x, y - 2; label="$num\n\n$den", line, pad)
    hline!(c, b.left + 1, b.right - 1, y)
    b
end
