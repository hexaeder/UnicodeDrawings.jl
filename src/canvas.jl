"""
A grid cell is either a stroke (a set of arms) or a piece of text. Text cells hold one grapheme;
a wide grapheme is followed by a `CONT` cell so that columns stay aligned. Text from one `text!`
call shares a `run` number, so lint can tell two labels that touch from a single word.
"""
struct Cell
    arms::Arms
    style::Style
    text::String
    run::Int
end
Cell(arms, style, text) = Cell(arms, style, text, 0)
const BLANK = Cell(Arms(), SOLID, "")
const CONT = Cell(Arms(), SOLID, "\0")

isblank(c::Cell) = c == BLANK
isstroke(c::Cell) = !isempty(c.arms)
istext(c::Cell) = !isempty(c.text)

"""
    Canvas()

A sparse character grid with 1-based `(x, y)` coordinates, `x` being the column and `y` the row
counted downwards. Strokes drawn onto the same cell merge their arms.
"""
struct Canvas
    cells::Dict{Tuple{Int,Int},Cell}
end
# The CLI shows the newest canvas when a scene fails halfway.
const LAST_CANVAS = Ref{Any}(nothing)
const TEXT_RUNS = Ref(0)
Canvas() = LAST_CANVAS[] = Canvas(Dict{Tuple{Int,Int},Cell}())

Base.getindex(c::Canvas, x::Integer, y::Integer) = get(c.cells, (x, y), BLANK)

function extent(c::Canvas)
    isempty(c.cells) && return (0, 0)
    maximum(first, keys(c.cells)), maximum(last, keys(c.cells))
end

"""
    addarms!(c, x, y, arms; style=SOLID)

Merge `arms` into the cell. Where both sides have an arm in the same direction, the heavier one
wins, and a non-solid style wins over solid. Drawing a stroke over text is an error.
"""
function addarms!(c::Canvas, x, y, arms::Arms; style=SOLID)
    old = c[x, y]
    istext(old) && error("stroke at ($x, $y) would overwrite $(textname(c, x, y))")
    c.cells[(x, y)] = Cell(merge_arms(old.arms, arms), max(old.style, style), "")
    c
end

"""
    puttext!(c, x, y, str; over=false, run=0)

Write `str` starting at column `x`. Writing over anything already there is an error unless
`over=true`, which is how arrowheads and junction dots are placed on a wire.
"""
function puttext!(c::Canvas, x, y, str::AbstractString; over=false, run=0)
    for g in Base.Unicode.graphemes(str)
        if g == " "   # spaces stay blank, as in `parse_text`
            x += 1
            continue
        end
        w = textwidth(g)
        for (i, cell) in enumerate((Cell(Arms(), SOLID, String(g), run), ntuple(_ -> CONT, w - 1)...))
            old = c[x + i - 1, y]
            if !isblank(old) && !over
                what = istext(old) ? textname(c, x + i - 1, y) : "a stroke"
                error("text $(repr(str)) at ($x, $y) would overwrite $what")
            end
            c.cells[(x + i - 1, y)] = cell
        end
        x += max(w, 1)
    end
    c
end

# The text cell at (x, y) for a message, with the label it belongs to: the rest of its `text!`
# call, or the word around it.
function textname(c::Canvas, x, y)
    run = c[x, y].run
    xs = if run > 0
        [i for ((i, j), cell) in c.cells if j == y && cell.run == run]
    else
        l, r = x, x
        while istext(c[l - 1, y])
            l -= 1
        end
        while istext(c[r + 1, y])
            r += 1
        end
        [l, r]
    end
    label = join(cellchar(c[i, y]) for i in minimum(xs):maximum(xs) if c[i, y] != CONT)
    label == c[x, y].text ? "text $(repr(label))" : "text $(repr(c[x, y].text)) of $(repr(label))"
end

"""
    parse_text(str)

Read a finished diagram back into a canvas, so it can be linted or compared. Box-drawing
characters become strokes, everything else becomes text.
"""
function parse_text(str::AbstractString)
    '\t' in str && error("tabs are not supported, expand them first")
    c = Canvas()
    for (y, line) in enumerate(eachsplit(str, '\n'))
        x = 1
        for g in Base.Unicode.graphemes(line)
            ch = first(g)
            if length(g) == 1 && isstroke(ch)
                addarms!(c, x, y, CHAR_ARMS[ch]; style=CHAR_STYLE[ch])
                x += 1
            elseif g != " "
                puttext!(c, x, y, g)
                x += max(textwidth(g), 1)
            else
                x += 1
            end
        end
    end
    c
end

function cellchar(cell::Cell)
    istext(cell) && return cell.text
    isstroke(cell) || return " "
    ch = glyph(cell.arms, cell.style)
    isnothing(ch) ? "?" : string(ch)
end

"""
    render(c::Canvas)

The canvas as text, with trailing spaces and trailing empty lines removed. Arm combinations
Unicode has no character for render as `?`; `lint` reports them.
"""
function render(c::Canvas)
    xmax, ymax = extent(c)
    lines = map(1:ymax) do y
        rstrip(join(cellchar(c[x, y]) for x in 1:xmax if c[x, y] != CONT))
    end
    while !isempty(lines) && isempty(last(lines))
        pop!(lines)
    end
    join(lines, '\n')
end
