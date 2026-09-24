struct Issue
    x::Int
    y::Int
    level::Symbol  # :error or :warning
    msg::String
end

# A stroke may end on a symbol (arrowhead, `●`, `(+)`, `(Σ)`) or on `o`, but not on a word.
function endsonword(c::Canvas, x, y)
    c[x - 1, y].text == "(" && c[x + 1, y].text == ")" && return false
    any(ch -> ch != 'o' && (isletter(ch) || isdigit(ch)), c[x, y].text)
end

# A straight line through the cell along the other axis than direction `d`.
function crosses(cell::Cell, d)
    a = cell.arms
    a[d] == NONE && a[opposite(d)] == NONE && a[mod1(d + 1, 4)] != NONE && a[mod1(d + 3, 4)] != NONE
end

# Two `text!` labels side by side read as one word, like `uc` and `Pmin` as `ucPmin`.
function touching(c::Canvas, x, y)
    run = c[x, y].run
    x2 = x + 1
    while c[x2, y] == CONT
        x2 += 1
    end
    nb = c[x2, y]
    (nb.run > 0 && nb.run != run) || return nothing
    word(xs) = join(c[i, y].text for i in xs if c[i, y] != CONT)
    x1, x3 = x, x2
    while c[x1 - 1, y].run == run || (c[x1 - 1, y] == CONT && c[x1 - 2, y].run == run)
        x1 -= 1
    end
    while c[x3 + 1, y].run == nb.run || c[x3 + 1, y] == CONT
        x3 += 1
    end
    "labels '$(word(x1:x))' and '$(word(x2:x3))' touch"
end

"""
    lint(c::Canvas) -> Vector{Issue}

Check that every stroke connects to its neighbours. An arm that meets a stroke without a
matching arm back is an error, since that is what a one-column slip looks like. Loose ends,
strokes running into text and weight mismatches are only warnings, because finished diagrams use
them on purpose (wire ends, axis ticks).

Two things pass silently: a line drawn straight over another one (a bridge, which leaves the
crossed line with a gap), and a line dashed with single spaces.
"""
function lint(c::Canvas)
    issues = Issue[]
    xmax, ymax = extent(c)
    for y in 1:ymax, x in 1:xmax
        cell = c[x, y]
        cell.run > 0 && (t = touching(c, x, y)) !== nothing && push!(issues, Issue(x, y, :warning, t))
        isstroke(cell) || continue
        ch = cellchar(cell)
        ch == "?" && push!(issues, Issue(x, y, :error, "no character for arms $(cell.arms.a)"))
        for d in 1:4
            wt = cell.arms[d]
            wt == NONE && continue
            dx, dy = OFFSETS[d]
            nb = c[x + dx, y + dy]
            beyond = c[x + 2dx, y + 2dy]
            where = "$(DIRNAMES[d]) arm of '$ch'"
            if isstroke(nb)
                back = nb.arms[opposite(d)]
                if back == NONE
                    crosses(nb, d) && beyond.arms[opposite(d)] != NONE && continue
                    push!(issues, Issue(x, y, :error, "$where meets '$(cellchar(nb))', which has no arm back"))
                elseif back != wt && d in (E, S)  # report a mismatch once, not from both sides
                    push!(issues, Issue(x, y, :warning, "$where is $wt but meets $back in '$(cellchar(nb))'"))
                end
            elseif isblank(nb)
                beyond.arms[opposite(d)] != NONE && continue
                push!(issues, Issue(x, y, :warning, "$where points at empty space"))
            elseif endsonword(c, x + dx, y + dy)
                push!(issues, Issue(x, y, :warning, "$where runs into text '$(nb.text)'"))
            end
        end
    end
    sort!(issues; by=i -> (i.level != :error, i.y, i.x))
end
lint(str::AbstractString) = lint(parse_text(str))
errors(issues) = filter(i -> i.level == :error, issues)

"""
    lintreport([io,] diagram)

Lint a diagram, given as text or as a `Canvas`, and print each issue under its line with a
caret. Returns the issues.
"""
function lintreport(io::IO, c::Canvas)
    lines = split(render(c), '\n')
    issues = lint(c)
    for is in issues
        println(io, "$(is.y):$(is.x): $(is.level): ", is.msg)
        println(io, "    ", lines[is.y])
        println(io, "    ", " "^(is.x - 1), "^")
    end
    issues
end
lintreport(io::IO, str::AbstractString) = lintreport(io, parse_text(str))
lintreport(d) = lintreport(stdout, d)

"""
    ruler([io,] str)

Print the diagram with column numbers above and row numbers on the left, to see where things
landed.
"""
function ruler(io::IO, str::AbstractString)
    lines = split(str, '\n')
    width = maximum(textwidth, lines; init=0)
    pad = " "^(ndigits(length(lines)) + 1)
    println(io, pad, join(x % 10 == 0 ? string(x ÷ 10 % 10) : " " for x in 1:width))
    println(io, pad, join(string(x % 10) for x in 1:width))
    for (y, line) in enumerate(lines)
        println(io, lpad(y, length(pad) - 1), " ", line)
    end
end
ruler(str::AbstractString) = ruler(stdout, str)

"""
    locate(str, pattern) -> Vector{Tuple{Int,Int}}

The `(x, y)` display positions where `pattern` (a string or character) occurs in the diagram.
Reading columns off a ruler is easy to get wrong; this gives them exactly.
"""
function locate(str::AbstractString, pattern)
    pattern = string(pattern)
    hits = Tuple{Int,Int}[]
    for (y, line) in enumerate(split(str, '\n'))
        for r in findall(pattern, line; overlap=true)
            push!(hits, (textwidth(line[1:prevind(line, first(r))]) + 1, y))
        end
    end
    hits
end
