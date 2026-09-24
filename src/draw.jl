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
Base.show(io::IO, b::Box) = print(io, "Box(left=$(b.left), right=$(b.right), top=$(b.top), ",
                                   "bottom=$(b.bottom), cx=$(b.cx), cy=$(b.cy))")

"""
    box!(c, x, y, w=nothing, h=nothing; label="", line=:light, dash=nothing,
         align=:center, valign=:middle, pad=1, over=false, clear=false) -> Box

A box with its top left corner at `(x, y)`. `w` and `h` count both walls. Without them the box
is sized around the label: the widest line plus `2 + 2pad` wide and the number of lines plus 2
tall. Widths are display widths, so `T₁` or `ẋ` take one column per character.

The label may have several lines. `align` (`:left`, `:center`, `:right`) and `valign` (`:top`,
`:middle`, `:bottom`) place it inside: `pad` columns from the side wall, and right under the top
wall or right over the bottom one. `line` and `dash` work
as for [`wire!`](@ref).

Edges join with strokes already on the canvas, like a wire does. With `clear=true` the box
first empties its rectangle, then joins its edges to every stroke or arrowhead that points at
it from outside. That drops a box onto an existing wire, which is how to insert a block into a
chain.
"""
function box!(c::Canvas, x, y, w=nothing, h=nothing; label="", line=:light, dash=nothing,
              align=:center, valign=:middle, pad=1, over=false, clear=false)
    lines = isempty(label) ? String[] : split(label, '\n')
    tw = maximum(textwidth, lines; init=0)
    w = something(w, tw + 2 + 2pad)
    h = something(h, length(lines) + 2)
    b = Box(x, y, w, h)
    if clear
        for yy in b.top:b.bottom, xx in b.left:b.right
            delete!(c.cells, (xx, yy))
        end
    end
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
    if clear
        weight, style = linestyle(line, dash)
        edge = [((xx, b.top), N) for xx in b.left:b.right]
        append!(edge, ((xx, b.bottom), S) for xx in b.left:b.right)
        append!(edge, ((b.left, yy), W) for yy in b.top:b.bottom)
        append!(edge, ((b.right, yy), E) for yy in b.top:b.bottom)
        for ((xx, yy), d) in edge
            dx, dy = OFFSETS[d]
            nb = c[xx + dx, yy + dy]
            wt = nb.arms[opposite(d)]
            # an arrowhead pointing at the box joins like the wire it sits on
            if get(ARROW_DIRS, nb.text, 0) == opposite(d)
                wt = c[xx + 2dx, yy + 2dy].arms[opposite(d)]
                wt == NONE && (wt = LIGHT)
            end
            wt != NONE && addarms!(c, xx, yy, setarm(Arms(), d, wt); style)
        end
    end
    b
end

"""
    tf!(c, x, y, num, den; line=:round, pad=1, prefix="") -> Box

A transfer-function block: `num` over `den` with a fraction bar on row `y`, so the block sits on
a signal wire drawn along `y`. `x` is the left edge, and the block spans rows `y-2` to `y+2`.

With a `prefix` like `"Kp +"` the block reads `Kp + Ki/s`: the prefix sits on the bar's row, in
front of a fraction one column wider than `num` and `den` on either side.
"""
function tf!(c::Canvas, x, y, num, den; line=:round, pad=1, prefix="")
    tw = max(textwidth(num), textwidth(den))
    if isempty(prefix)
        inner = tw + 2pad
        inner < 2 && (inner += 2)             # room for the bar, `╶╴` at least
        b = box!(c, x, y - 2, inner + 2, 5; label="$num\n\n$den", line, pad)
        hline!(c, b.left + 1, b.right - 1, y)
        return b
    end
    pw = textwidth(prefix)
    b = box!(c, x, y - 2, pw + tw + 5 + 2pad, 5; line)
    puttext!(c, b.left + 1 + pad, y, prefix)
    bar = b.left + 2 + pad + pw               # first cell of the bar, which is tw + 2 long
    hline!(c, bar, bar + tw + 1, y)
    for (row, t) in ((y - 1, num), (y + 1, den))
        puttext!(c, bar + 1 + (tw - textwidth(t)) ÷ 2, row, t)
    end
    b
end

"""
    wire!(c, points...; line=:round, dash=nothing, cap=:half, over=false, arrow=nothing, head=:arrow)

An orthogonal path through `points`, each an `(x, y)` tuple. The first and last cell only get an
arm pointing along the wire, so a wire ending in open space shows as a half-stroke `╶`, and a
wire ending on a box edge turns it into a junction like `┤`. With `cap=:full` the ends are full
strokes instead; `cap` can also be a tuple to set the two ends separately.

`line` is `:light`, `:round` (light with rounded corners), `:heavy` or `:double`. `dash=2`, `3`
or `4` draws the straight cells with that many dashes each (`╌`, `┄`, `┈`); corners and ends
stay solid, so a short dashed wire hardly looks dashed.

With `over=true` the wire replaces what is underneath instead of joining it. A wire drawn
across a box edge that way leaves a gap in the edge rather than a crossing.

`arrow` puts arrowheads on the wire, pointing the way it runs. It counts cells along the wire:
`1` is the first cell, `-1` the last and `-2` the one before, and a tuple like `(2, -2)` places
several. `head` picks their shape, as for [`arrow!`](@ref).
"""
function wire!(c::Canvas, points::Tuple{Int,Int}...; line=:round, dash=nothing, cap=:half,
               over=false, arrow=nothing, head=:arrow)
    weight, style = linestyle(line, dash)
    arms = Dict{Tuple{Int,Int},Arms}()
    dirs = Int[]
    path = [(first(points), 0)]              # the cells in order, with the way the wire runs
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
            push!(path, (nxt, d))
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
    length(path) > 1 && (path[1] = (path[1][1], path[2][2]))
    for i in something(arrow, ())
        (x, y), d = path[i > 0 ? i : end + 1 + i]
        mark!(c, x, y, string(ARROWHEADS[head][d]))
    end
    c
end

"""
    hline!(c, x1, x2, y; kw...)
    vline!(c, x, y1, y2; kw...)

A straight wire along row `y` or column `x`, with the keywords of [`wire!`](@ref).
"""
hline!(c::Canvas, x1, x2, y; kw...) = wire!(c, (x1, y), (x2, y); kw...)
@doc (@doc hline!) vline!(c::Canvas, x, y1, y2; kw...) = wire!(c, (x, y1), (x, y2); kw...)

"""
    text!(c, x, y, str; align=:left, over=false)

Write `str` starting at column `x`. With `align=:center` its middle character sits at `x`
(rounded left), with `align=:right` its last one. A string with newlines continues on the
following rows. Writing onto a stroke is an error unless `over=true`.
"""
function text!(c::Canvas, x, y, str::AbstractString; align=:left, over=false)
    run = over ? 0 : (TEXT_RUNS[] += 1)
    for (i, line) in enumerate(split(str, '\n'))
        w = textwidth(line)
        x0 = align === :left ? x : align === :center ? x - (w - 1) ÷ 2 : align === :right ? x - w + 1 :
             error("unknown align $(repr(align))")
        puttext!(c, x0, y + i - 1, line; over, run)
    end
    c
end

"""
    mark!(c, x, y, str; align=:left)

Text placed on top of whatever is there, such as `●` on a wire or `(+)` at a junction. `align`
works as for [`text!`](@ref).
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
const ARROW_DIRS = Dict(string(ch) => d for heads in values(ARROWHEADS) for (d, ch) in enumerate(heads))

"""
    arrow!(c, x, y, dir; head=:arrow)

An arrowhead pointing `dir` (`:up`, `:right`, `:down`, `:left`), drawn over whatever is there.
`head` picks the family: `:arrow` (→), `:triangle` (▷), `:solid` (▶), `:small` (▹) or
`:smallsolid` (▸).
"""
arrow!(c::Canvas, x, y, dir::Symbol; head=:arrow) = mark!(c, x, y, string(ARROWHEADS[head][DIRSYMS[dir]]))

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

"""
    insertcols!(c, x, n; rows=nothing)
    insertrows!(c, y, n; cols=nothing)

Open a gap of `n` columns before column `x` (or `n` rows before row `y`). Everything from there
on moves over, and strokes that cross the gap are stretched, so wires stay connected. Meant for
inserting something into the middle of a finished drawing, such as an imported diagram.

`rows` (or `cols`) limits the insert to part of the drawing, like one row of blocks. Wires that
leave that part are cut, so check the lint afterwards.
"""
insertcols!(c::Canvas, x, n; rows=nothing) = _insert!(c, x, n, E, rows)
@doc (@doc insertcols!) insertrows!(c::Canvas, y, n; cols=nothing) = _insert!(c, y, n, S, cols)

function _insert!(c::Canvas, at, n, d, span)
    k = d == E ? 1 : 2                        # the coordinate that moves
    step(p, dir, s=1) = (p[1] + s * OFFSETS[dir][1], p[2] + s * OFFSETS[dir][2])
    # Text sitting on a line across the cut, like an arrowhead on a vertical wire, has to move
    # with that line. So does text stacked onto such a cell, like the `Σ` above the arrow.
    across = d == E ? (N, S) : (W, E)
    anchored = Set(p for (p, cell) in c.cells if istext(cell) &&
                   any(dir -> c[step(p, dir)...].arms[opposite(dir)] != NONE, across))
    todo = collect(anchored)
    while !isempty(todo)
        p = pop!(todo)
        for dir in across
            q = step(p, dir)
            istext(c[q...]) && q ∉ anchored && (push!(anchored, q); push!(todo, q))
        end
    end
    # Each row gets its own cut. Where the cut splits a phrase, the phrase stays in one piece
    # and the row is cut after it, unless the phrase holds an anchored cell. Then the row is cut
    # before the word with that cell, so the word moves along with it.
    function rowcut(pos)
        istext(c[pos(at - 1)...]) || return at
        wordgap(i) = d == E && !isstroke(c[pos(i)...]) && istext(c[pos(i + 1)...])
        i = at
        while pos(i) ∉ anchored && (istext(c[pos(i)...]) || wordgap(i))
            i += 1
        end
        pos(i) in anchored || return i
        while istext(c[pos(i - 1)...]) && pos(i - 1) ∉ anchored
            i -= 1
        end
        i
    end
    posfn(o) = k == 1 ? (i -> (i, o)) : (i -> (o, i))
    cuts = Dict(o => rowcut(posfn(o)) for o in unique(p[3-k] for p in keys(c.cells))
                if isnothing(span) || o in span)
    moves(p) = haskey(cuts, p[3-k]) && p[k] >= cuts[p[3-k]]
    moved = Dict((moves(p) ? (d == E ? (p[1] + n, p[2]) : (p[1], p[2] + n)) : p) => cell
                 for (p, cell) in c.cells)
    # The line that points across the gap from one side: a stroke's arm, or the stroke just
    # behind a one-cell mark like `●`.
    function arm(p, dir)
        cell = c[p...]
        isstroke(cell) && return cell.arms[dir]
        behind = c[step(p, dir, -1)...]
        istext(cell) && isstroke(behind) ? behind.arms[dir] : NONE
    end
    for (o, g) in cuts
        pos = posfn(o)
        l, r = c[pos(g - 1)...], c[pos(g)...]
        lw, rw = arm(pos(g - 1), d), arm(pos(g), opposite(d))
        # a line runs on across the gap if the other side continues it or is text it runs into
        w = lw != NONE && (lw == rw || (rw == NONE && istext(r))) ? lw :
            rw != NONE && lw == NONE && istext(l) ? rw : NONE
        w == NONE && continue
        style = isstroke(l) && l.style in (DASH2, DASH3, DASH4) ? l.style : SOLID
        arms = d == E ? Arms(NONE, w, NONE, w) : Arms(w, NONE, w, NONE)
        for j in 0:n-1
            moved[pos(g + j)] = Cell(arms, style, "")
        end
    end
    empty!(c.cells)
    merge!(c.cells, moved)
    c
end
