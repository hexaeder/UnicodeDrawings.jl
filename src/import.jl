# Turning a finished diagram back into a scene, and writing an edited scene back in place.
#
# The picture is the source of truth. `import_scene` guesses primitives (boxes, transfer-function
# blocks, wires, labels, marks) so that an agent can edit the diagram as code. Every guess is
# checked by drawing it, and whatever the guesses don't explain becomes a per-cell fix-up at the
# end, so rendering the imported scene always gives back the original exactly.

const P = Tuple{Int,Int}
step(p::P, d) = (p[1] + OFFSETS[d][1], p[2] + OFFSETS[d][2])
armat(A, p, d) = get(A, p, Arms())[d]

# Arms of every stroke, plus the arms a wire would have under a mark such as `→`, `●` or `(Σ)`.
function implied_arms(O::Canvas)
    A = Dict{P,Arms}()
    for (p, cell) in O.cells
        isstroke(cell) && (A[p] = cell.arms)
    end
    for (p, cell) in O.cells
        istext(cell) || continue
        a = Arms()
        for d in 1:4
            nb = O[step(p, d)...]
            isstroke(nb) && nb.arms[opposite(d)] != NONE && (a = setarm(a, d, nb.arms[opposite(d)]))
        end
        isempty(a) || (A[p] = a)
    end
    # A few marks in a row on a line, like `→●` or `(Σ)`, carry the wire through.
    for p in sort(collect(keys(A))), d in (E, S)
        istext(O[p...]) || continue
        wt = armat(A, p, opposite(d))
        (wt != NONE && armat(A, p, d) == NONE) || continue
        run = [p]
        q = step(p, d)
        while length(run) <= 4 && istext(O[q...]) && armat(A, q, d) == NONE
            push!(run, q)
            q = step(q, d)
        end
        (istext(O[q...]) && armat(A, q, d) == wt) || continue
        push!(run, q)
        for (i, r) in enumerate(run)
            a = get(A, r, Arms())
            i < length(run) && (a = setarm(a, d, wt))
            i > 1 && (a = setarm(a, opposite(d), wt))
            A[r] = a
        end
    end
    A
end

function find_boxes(O::Canvas, A)
    boxes = Tuple{Box,Weight}[]
    for p in sort(collect(keys(A)); by=q -> (q[2], q[1]))
        isstroke(O[p...]) || continue
        wt = armat(A, p, E)
        (wt != NONE && armat(A, p, S) == wt && armat(A, p, N) == NONE && armat(A, p, W) == NONE) || continue
        x, y = p
        x2 = x + 1
        found = false
        while !found && armat(A, (x2, y), W) == wt
            if armat(A, (x2, y), S) == wt
                y2 = y + 1
                while armat(A, (x2, y2), N) == wt
                    if armat(A, (x2, y2), W) == wt && closes(A, x, y, x2, y2, wt)
                        push!(boxes, (Box(x, y, x2 - x + 1, y2 - y + 1), wt))
                        found = true
                        break
                    end
                    armat(A, (x2, y2), S) == wt || break
                    y2 += 1
                end
            end
            armat(A, (x2, y), E) == wt || break
            x2 += 1
        end
    end
    boxes
end

function closes(A, x, y, x2, y2, wt)
    all(xx -> armat(A, (xx, y2), E) == wt && armat(A, (xx, y2), W) == wt, x+1:x2-1) &&
        armat(A, (x, y2), N) == wt && armat(A, (x, y2), E) == wt &&
        all(yy -> armat(A, (x, yy), N) == wt && armat(A, (x, yy), S) == wt, y+1:y2-1)
end

inside(b::Box, p) = b.left <= p[1] <= b.right && b.top <= p[2] <= b.bottom
contains(a::Box, b::Box) = a != b && inside(a, (b.left, b.top)) && inside(a, (b.right, b.bottom))

# The text a label could explain: plain text in the interior, outside nested boxes.
function owned_text(O, A, b::Box, nested)
    owned = Set{P}()
    for y in b.top+1:b.bottom-1, x in b.left+1:b.right-1
        p = (x, y)
        istext(O[x, y]) && !haskey(A, p) && !any(n -> inside(n, p), nested) && push!(owned, p)
    end
    owned
end

function rowtext(O, y, x1, x2)
    join(O[x, y] == CONT ? "" : isblank(O[x, y]) ? " " : O[x, y].text for x in x1:x2)
end

# Candidate labels: all the interior text, or just the first phrase as a title.
function label_candidates(O, b::Box, owned)
    rows = sort(unique(last.(collect(owned))))
    isempty(rows) && return String[]
    lines = String[]
    for y in first(rows):last(rows)
        xs = sort([p[1] for p in owned if p[2] == y])
        if isempty(xs)
            push!(lines, "")
        elseif all(x -> (x, y) in owned || isblank(O[x, y]), first(xs):last(xs))
            push!(lines, rowtext(O, y, first(xs), last(xs)))
        else
            lines = nothing
            break
        end
    end
    y = first(rows)
    xs = sort([p[1] for p in owned if p[2] == y])
    stop = findfirst(i -> xs[i+1] - xs[i] > 2, 1:length(xs)-1)
    title = rowtext(O, y, first(xs), isnothing(stop) ? last(xs) : xs[stop])
    cands = isnothing(lines) ? [title] : unique([join(lines, '\n'), title])
end

# Draws the primitive on an empty canvas; it counts if all of its text matches the picture.
function trial(O, owned, f)
    tc = Canvas()
    try
        f(tc)
    catch
        return nothing
    end
    texts = [p for (p, cell) in tc.cells if istext(cell)]
    all(p -> p in owned && O[p...] == tc[p...], texts) || return nothing
    tc
end

lineword(wt, round) = wt == HEAVY ? :heavy : wt == DOUBLE ? :double : round ? :round : :light

fmt(v::Union{Symbol,AbstractString}) = repr(v)
fmt(v::Tuple) = "(" * join(fmt.(v), ", ") * ")"
fmt(v) = string(v)
kwstring(pairs) = isempty(pairs) ? "" : "; " * join(("$k=$(fmt(v))" for (k, v) in pairs), ", ")

function varname(label, taken)
    m = match(r"^[\p{L}_][\p{L}\p{N}_]*", label)
    w = isnothing(m) ? "" : lowercase(m.match)
    base = isempty(w) || !isletter(first(w)) ? "b" :
           w == "c" || isdefined(Base, Symbol(w)) || isdefined(@__MODULE__, Symbol(w)) ? "$(w)_" : w
    name, i = base, 1
    while name in taken
        i += 1
        name = "$base$i"
    end
    push!(taken, name)
    name
end

"""
    import_scene(str; check=true) -> String

Scene code that reproduces the diagram `str` exactly, with boxes, wires, labels and marks found
where possible and per-cell fix-ups for the rest. `check=false` skips running the scene, which
finds the fix-ups, and is only for precompiling.
"""
function import_scene(str::AbstractString; check=true)
    O = parse_text(str)
    A = implied_arms(O)
    R = copy(A)                  # arms not yet explained by a primitive
    consumed = Set{P}()          # text explained by a label
    code = String[]
    taken = Set{String}()
    named = Tuple{String,Box}[]  # boxes by variable name, for anchors

    boxes = find_boxes(O, A)
    !isempty(boxes) && push!(code, "# boxes")
    for (b, wt) in boxes
        nested = [n for (n, _) in boxes if contains(b, n)]
        owned = owned_text(O, A, b, nested)
        cell = O[b.left, b.top]
        line = lineword(wt, cell.style == ROUND)
        dash = O[b.left+1, b.top].style in (DASH2, DASH3, DASH4) ? Int(O[b.left+1, b.top].style) - Int(DASH2) + 2 : nothing
        opts = Pair{Symbol,Any}[]
        line != :light && push!(opts, :line => line)
        isnothing(dash) || push!(opts, :dash => dash)
        call, tc, name = nothing, nothing, ""
        for label in label_candidates(O, b, owned)
            ls = split(label, '\n')
            # a transfer-function block: numerator, fraction bar, denominator
            if length(ls) == 3 && isempty(ls[2]) && b.h == 5 && isnothing(dash)
                for pad in (1, 0, 2, 3)
                    t = trial(O, owned, c -> tf!(c, b.x, b.y + 2, ls[1], ls[3]; line, pad))
                    (isnothing(t) || extent(t) != (b.right, b.bottom)) && continue
                    all(x -> haskey(A, (x, b.y + 2)), b.left+1:b.right-1) || continue
                    tfopts = Pair{Symbol,Any}[]
                    line != :round && push!(tfopts, :line => line)
                    pad != 1 && push!(tfopts, :pad => pad)
                    call = "tf!(c, $(b.x), $(b.y + 2), $(repr(String(ls[1]))), $(repr(String(ls[3])))$(kwstring(tfopts)))"
                    tc, name = t, "tf"
                    break
                end
                isnothing(call) || break
            end
            for pad in (1, 0, 2, 3)   # sized around the label
                t = trial(O, owned, c -> box!(c, b.x, b.y; label, line, dash, pad))
                (isnothing(t) || extent(t) != (b.right, b.bottom)) && continue
                extra = pad == 1 ? Pair{Symbol,Any}[] : Pair{Symbol,Any}[:pad => pad]
                call = "box!(c, $(b.x), $(b.y)$(kwstring([:label => label; opts; extra])))"
                tc, name = t, label
                break
            end
            isnothing(call) || break
            for align in (:center, :left, :right), valign in (:middle, :top, :bottom), pad in (1, 0, 2, 3)
                t = trial(O, owned, c -> box!(c, b.x, b.y, b.w, b.h; label, line, dash, align, valign, pad))
                isnothing(t) && continue
                extra = Pair{Symbol,Any}[]
                align != :center && push!(extra, :align => align)
                valign != :middle && push!(extra, :valign => valign)
                pad != 1 && push!(extra, :pad => pad)
                call = "box!(c, $(b.x), $(b.y), $(b.w), $(b.h)$(kwstring([:label => label; opts; extra])))"
                tc, name = t, label
                break
            end
            isnothing(call) || break
        end
        if isnothing(call)
            tc = Canvas()
            box!(tc, b.x, b.y, b.w, b.h; line, dash)
            call = "box!(c, $(b.x), $(b.y), $(b.w), $(b.h)$(kwstring(opts)))"
        end
        name = varname(name, taken)
        push!(code, "$name = $call")
        push!(named, (name, b))
        for (p, cell) in tc.cells
            if isstroke(cell)
                a = get(R, p, Arms())
                R[p] = Arms(ntuple(d -> cell.arms[d] != NONE ? NONE : a[d], 4))
            elseif istext(cell)
                push!(consumed, p)
            end
        end
    end
    filter!(kv -> !isempty(kv[2]), R)

    wires = trace_wires(R, O, named)
    !isempty(wires) && push!(code, "", "# wires")
    append!(code, wires)

    texts = text_code(O, A, consumed, named)
    !isempty(texts) && push!(code, "", "# text and marks")
    append!(code, texts)

    # Whatever the primitives above don't reproduce is set cell by cell.
    body = join(code, '\n')
    check || return body
    T = evalscene(body)
    fixes = String[]
    xmax, ymax = max.(extent(O), extent(T))
    for y in 1:ymax, x in 1:xmax
        o, t = O[x, y], T[x, y]
        (o == CONT || cellchar(o) == cellchar(t) && (o == CONT) == (t == CONT)) && continue
        push!(fixes, istext(o) ? "mark!(c, $x, $y, $(repr(o.text)))" :
                     isstroke(o) ? "stroke!(c, $x, $y, $(repr(only(cellchar(o)))); over=true)" :
                     "erase!(c, $x, $y)")
    end
    if !isempty(fixes)
        body *= "\n\n# cells the primitives above don't reproduce\n" * join(fixes, '\n')
    end
    render(evalscene(body)) == render(O) || error("import does not reproduce the diagram")
    "c = Canvas()\n\n" * body * "\n\nc\n"
end

function evalscene(body)
    m = Module(:Import)
    Core.eval(m, :(using UnicodeDrawings))
    Base.include_string(m, "c = Canvas()\n" * body * "\nc")
end

# Orthogonal paths through the remaining arms. Paths start at loose ends, run straight through
# junctions and stop where weight or corner style changes.
function trace_wires(R, O, named)
    conn(p, d) = (a = armat(R, p, d); a != NONE && armat(R, step(p, d), opposite(d)) == a)
    used = Set{Tuple{P,Int}}()
    free(p, d) = conn(p, d) && !((p, d) in used)
    use!(p, d) = (push!(used, (p, d)); push!(used, (step(p, d), opposite(d))))
    deg(p) = count(d -> conn(p, d), 1:4)
    dangling(p, d) = armat(R, p, d) != NONE && !conn(p, d)
    cornerstyle(p) = (st = O[p...].style; !isstroke(O[p...]) ? nothing : st == ROUND ? :round : :sharp)
    dashof(p) = (st = O[p...].style; st in (DASH2, DASH3, DASH4) ? Int(st) - Int(DASH2) + 2 : isstroke(O[p...]) ? 0 : nothing)

    function walk(p, d)
        pts = [p]
        wt = armat(R, p, d)
        corner, dash = nothing, nothing
        d0, cur = d, p
        while true
            use!(cur, d)
            nxt = step(cur, d)
            if deg(nxt) == 2
                nd = only(e for e in 1:4 if e != opposite(d) && conn(nxt, e))
                ok = free(nxt, nd) && armat(R, nxt, nd) == wt
                if ok && nd == d
                    ds = dashof(nxt)
                    if !isnothing(ds)
                        dash = something(dash, ds)
                        ok = ds == dash
                    end
                elseif ok
                    cs = cornerstyle(nxt)
                    if !isnothing(cs)
                        corner = something(corner, cs)
                        ok = cs == corner
                    end
                end
                if ok
                    nd != d && push!(pts, nxt)
                    cur, d = nxt, nd
                    continue
                end
            elseif deg(nxt) > 2 && free(nxt, d) && armat(R, nxt, d) == wt
                cur = nxt
                continue
            end
            push!(pts, nxt)
            break
        end
        caps = (dangling(p, opposite(d0)) ? :full : :half, dangling(last(pts), d) ? :full : :half)
        wirecode(pts, wt, something(corner, :round), something(dash, 0), caps, named)
    end

    code = String[]
    cells = sort(collect(keys(R)); by=q -> (q[2], q[1]))
    for pass in (p -> deg(p) == 1, p -> deg(p) > 2, p -> true)
        for p in cells
            pass(p) || continue
            for d in 1:4
                free(p, d) && push!(code, walk(p, d))
            end
        end
    end
    code
end

# Coordinates relative to a box, so that what hangs off a box moves with it.
xrel(n, b, x) = x == b.left ? "$n.left" : x == b.right ? "$n.right" : x == b.cx ? "$n.cx" :
                x < b.left ? "$n.left - $(b.left - x)" : x > b.right ? "$n.right + $(x - b.right)" :
                "$n.left + $(x - b.left)"
yrel(n, b, y) = y == b.top ? "$n.top" : y == b.bottom ? "$n.bottom" : y == b.cy ? "$n.cy" :
                y < b.top ? "$n.top - $(b.top - y)" : y > b.bottom ? "$n.bottom + $(y - b.bottom)" :
                "$n.top + $(y - b.top)"
onedge(b, p) = (p[1] in (b.left, b.right) && b.top <= p[2] <= b.bottom) ||
               (p[2] in (b.top, b.bottom) && b.left <= p[1] <= b.right)

# Expressions for the points of a wire: ends on a box edge use that box's anchors, and the
# coordinates a segment shares with an anchored end follow it.
function wirepoints(pts, named)
    xs = Any[string(p[1]) for p in pts]
    ys = Any[string(p[2]) for p in pts]
    for (k, nb) in ((1, 2), (length(pts), length(pts) - 1))
        i = findfirst(((n, b),) -> onedge(b, pts[k]), named)
        isnothing(i) && continue
        n, b = named[i]
        xs[k], ys[k] = xrel(n, b, pts[k][1]), yrel(n, b, pts[k][2])
        # the neighbouring point shares one coordinate; a free straight end hangs off the box
        q = pts[nb]
        horizontal = q[2] == pts[k][2]
        horizontal ? (ys[nb] = ys[k]) : (xs[nb] = xs[k])
        if length(pts) == 2 && !any(((_, b2),) -> onedge(b2, q), named)
            horizontal ? (xs[nb] = xrel(n, b, q[1])) : (ys[nb] = yrel(n, b, q[2]))
        end
    end
    xs, ys
end

function wirecode(pts, wt, corner, dash, caps, named=Tuple{String,Box}[])
    opts = Pair{Symbol,Any}[]
    line = lineword(wt, corner == :round)
    length(pts) > 2 && line != :round && push!(opts, :line => line)
    length(pts) == 2 && line in (:heavy, :double) && push!(opts, :line => line)
    dash > 0 && push!(opts, :dash => dash)
    caps != (:half, :half) && push!(opts, :cap => caps[1] == caps[2] ? caps[1] : caps)
    kw = kwstring(opts)
    xs, ys = wirepoints(pts, named)
    if length(pts) == 2 && pts[1][2] == pts[2][2]
        "hline!(c, $(xs[1]), $(xs[2]), $(ys[1])$kw)"
    elseif length(pts) == 2
        "vline!(c, $(xs[1]), $(ys[1]), $(ys[2])$kw)"
    else
        "wire!(c, $(join(("($x, $y)" for (x, y) in zip(xs, ys)), ", "))$kw)"
    end
end

const ARROW_NAMES = Dict(ch => (head, dir) for (head, chars) in ARROWHEADS
                         for (dir, ch) in zip((:up, :right, :down, :left), chars))

# Text outside labels, one call per phrase. A phrase sitting on a wire becomes a mark.
# A position next to a box, as an expression relative to it: to the right, to the left (then
# right-aligned) or just above or below.
function textanchor(x1, x2, y, named)
    best, dist = nothing, 5
    for (n, b) in named
        near = b.top - 1 <= y <= b.bottom + 1
        if near && 0 < x1 - b.right < dist
            best, dist = ("$(xrel(n, b, x1)), $(yrel(n, b, y))", ""), x1 - b.right
        elseif near && 0 < b.left - x2 < dist
            best, dist = ("$(xrel(n, b, x2)), $(yrel(n, b, y))", "; align=:right"), b.left - x2
        elseif (y == b.top - 1 || y == b.bottom + 1) && b.left <= x1 && x2 <= b.right && dist > 1
            best, dist = ("$(xrel(n, b, x1)), $(yrel(n, b, y))", ""), 1
        end
    end
    something(best, ("$x1, $y", ""))
end

function text_code(O, A, consumed, named=Tuple{String,Box}[])
    code = String[]
    xmax, ymax = extent(O)
    for y in 1:ymax
        x = 1
        tokens = []
        while x <= xmax
            if istext(O[x, y]) && O[x, y] != CONT && !((x, y) in consumed)
                x0 = x
                while x <= xmax && istext(O[x, y]) && !((x, y) in consumed)
                    x += 1
                end
                # a mark keeps a stray bracket, but a word touching it is text of its own
                onwire = [xx for xx in x0:x-1 if haskey(A, (xx, y))]
                if isempty(onwire)
                    push!(tokens, (x0, x - 1, false))
                else
                    a, b = first(onwire), last(onwire)
                    a - x0 >= 2 ? push!(tokens, (x0, a - 1, false)) : (a = x0)
                    x - 1 - b >= 2 ? append!(tokens, [(a, b, true), (b + 1, x - 1, false)]) :
                                     push!(tokens, (a, x - 1, true))
                end
            else
                x += 1
            end
        end
        merged = []
        for t in tokens
            if !isempty(merged) && !last(merged)[3] && !t[3] && t[1] == last(merged)[2] + 2
                merged[end] = (last(merged)[1], t[2], false)
            else
                push!(merged, t)
            end
        end
        for (x1, x2, onwire) in merged
            s = rowtext(O, y, x1, x2)
            pos, align = textanchor(x1, x2, y, named)
            if onwire && length(s) == 1 && haskey(ARROW_NAMES, only(s))
                head, dir = ARROW_NAMES[only(s)]
                push!(code, "arrow!(c, $pos, :$dir" * (head == :arrow ? ")" : "; head=:$head)"))
            else
                push!(code, (onwire ? "mark!" : "text!") * "(c, $pos, $(repr(s))$align)")
            end
        end
    end
    code
end

# Diagram blocks in a file: fenced blocks, as (fence line, closing line, indent). A file without
# fences is one block, reported with fence line 0.
function diagram_blocks(lines)
    blocks = Tuple{Int,Int,String}[]
    i = 1
    while i <= length(lines)
        m = match(r"^(\s*)```", lines[i])
        if isnothing(m)
            i += 1
            continue
        end
        j = findnext(l -> startswith(l, m.captures[1] * "```"), lines, i + 1)
        isnothing(j) && break
        push!(blocks, (i, j, m.captures[1]))
        i = j + 1
    end
    isempty(blocks) && !isempty(lines) && push!(blocks, (0, length(lines) + 1, ""))
    blocks
end

blocktext(lines, (i, j, indent)) =
    join((startswith(l, indent) ? l[nextind(l, 0, length(indent) + 1):end] : l for l in lines[i+1:j-1]), '\n')

# FNV-1a over the diagram with trailing spaces dropped, to notice edits between import and put.
function diagram_hash(str)
    h = 0x811c9dc5
    for b in codeunits(normalize_diagram(str))
        h = (h ⊻ b) * 0x01000193
    end
    string(h; base=16, pad=8)
end
normalize_diagram(str) = render(parse_text(str))

"""
    import_file(path, line=nothing) -> String

Scene code for the diagram block of `path` that contains `line` (or the only one). The first
line of the scene records where it came from, so that `put_scene` can write it back.
"""
function import_file(path, line=nothing)
    lines = readlines(path)
    blocks = diagram_blocks(lines)
    if !isnothing(line)
        filter!(b -> b[1] <= line <= b[2] || b[1] == 0, blocks)
    end
    if length(blocks) != 1
        msg = isempty(blocks) ? "no diagram block found" :
              "$(length(blocks)) diagram blocks, pick one with $path:LINE:\n" *
              join(("  line $(b[1]): $(first(split(blocktext(lines, b), '\n'), 1)...)" for b in blocks), '\n')
        error(msg)
    end
    str = blocktext(lines, only(blocks))
    "# udraw: $(abspath(path)):$(only(blocks)[1]) $(diagram_hash(str))\n" *
    "# Edit freely; `udraw put` on this file writes the rendered diagram back to that block.\n" *
    import_scene(str)
end

"""
    put_scene(scenepath) -> (path, fence line, new diagram)

Render an imported scene and replace its diagram block in the original file. Refuses if the
block changed since the import. Afterwards the scene's header points at the new diagram, so the
scene can be edited and put again.
"""
function put_scene(scenepath)
    scene = readlines(scenepath)
    m = isempty(scene) ? nothing : match(r"^# udraw: (.+):(\d+) ([0-9a-f]{8})$", first(scene))
    isnothing(m) && error("$scenepath has no `# udraw:` header from `udraw import`")
    path, line, h = m.captures[1], parse(Int, m.captures[2]), m.captures[3]
    isfile(path) || error("$path, where the diagram came from, does not exist")
    lines = split(read(path, String), '\n')
    blocks = diagram_blocks(lines)
    at = findfirst(b -> b[1] == line && diagram_hash(blocktext(lines, b)) == h, blocks)
    if isnothing(at)   # the file moved around it; look for the unchanged diagram
        hits = findall(b -> diagram_hash(blocktext(lines, b)) == h, blocks)
        length(hits) == 1 || error("the diagram in $path changed since the import, import it again")
        at = only(hits)
    end
    LAST_CANVAS[] = nothing
    new = render(runscene(scenepath))
    i, j, indent = blocks[at]
    newlines = [isempty(l) ? l : indent * l for l in split(new, '\n')]
    write(path, join([lines[1:i]; newlines; lines[j:end]], '\n'))
    scene[1] = "# udraw: $path:$i $(diagram_hash(new))"
    write(scenepath, join(scene, '\n') * "\n")
    path, i, new
end
