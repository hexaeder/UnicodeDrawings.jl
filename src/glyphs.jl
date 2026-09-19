@enum Weight::UInt8 NONE LIGHT HEAVY DOUBLE

# Directions index into the arm tuple, clockwise from north.
const N, E, S, W = 1, 2, 3, 4
const DIRNAMES = ("north", "east", "south", "west")
const OFFSETS = ((0, -1), (1, 0), (0, 1), (-1, 0))
opposite(d) = mod1(d + 2, 4)

"""
    Arms(n, e, s, w)

The four strokes leaving a cell, each with its own weight. Every box-drawing character is one
such combination, which is what lets crossing strokes merge into the right junction.
"""
struct Arms
    a::NTuple{4,Weight}
end
Arms(n, e, s, w) = Arms((n, e, s, w))
Arms() = Arms(NONE, NONE, NONE, NONE)
Base.getindex(a::Arms, d::Integer) = a.a[d]
Base.isempty(a::Arms) = all(==(NONE), a.a)
merge_arms(a::Arms, b::Arms) = Arms(max.(a.a, b.a))

# One line per character: the arms as N E S W with `.` none, `l` light, `h` heavy, `d` double.
# A trailing flag gives the line style for characters that only differ in looks.
const GLYPH_SPEC = """
─ .l.l
━ .h.h
│ l.l.
┃ h.h.
┌ .ll.
┍ .hl.
┎ .lh.
┏ .hh.
┐ ..ll
┑ ..lh
┒ ..hl
┓ ..hh
└ ll..
┕ lh..
┖ hl..
┗ hh..
┘ l..l
┙ l..h
┚ h..l
┛ h..h
├ lll.
┝ lhl.
┞ hll.
┟ llh.
┠ hlh.
┡ hhl.
┢ lhh.
┣ hhh.
┤ l.ll
┥ l.lh
┦ h.ll
┧ l.hl
┨ h.hl
┩ h.lh
┪ l.hh
┫ h.hh
┬ .lll
┭ .llh
┮ .hll
┯ .hlh
┰ .lhl
┱ .lhh
┲ .hhl
┳ .hhh
┴ ll.l
┵ ll.h
┶ lh.l
┷ lh.h
┸ hl.l
┹ hl.h
┺ hh.l
┻ hh.h
┼ llll
┽ lllh
┾ lhll
┿ lhlh
╀ hlll
╁ llhl
╂ hlhl
╃ hllh
╄ hhll
╅ llhh
╆ lhhl
╇ hhlh
╈ lhhh
╉ hlhh
╊ hhhl
╋ hhhh
═ .d.d
║ d.d.
╒ .dl.
╓ .ld.
╔ .dd.
╕ ..ld
╖ ..dl
╗ ..dd
╘ ld..
╙ dl..
╚ dd..
╛ l..d
╜ d..l
╝ d..d
╞ ldl.
╟ dld.
╠ ddd.
╡ l.ld
╢ d.dl
╣ d.dd
╤ .dld
╥ .ldl
╦ .ddd
╧ ld.d
╨ dl.l
╩ dd.d
╪ ldld
╫ dldl
╬ dddd
╭ .ll. round
╮ ..ll round
╯ l..l round
╰ ll.. round
╴ ...l
╵ l...
╶ .l..
╷ ..l.
╸ ...h
╹ h...
╺ .h..
╻ ..h.
╼ .h.l
╽ l.h.
╾ .l.h
╿ h.l.
┄ .l.l dash3
┅ .h.h dash3
┆ l.l. dash3
┇ h.h. dash3
┈ .l.l dash4
┉ .h.h dash4
┊ l.l. dash4
┋ h.h. dash4
╌ .l.l dash2
╍ .h.h dash2
╎ l.l. dash2
╏ h.h. dash2
"""

@enum Style::UInt8 SOLID ROUND DASH2 DASH3 DASH4

const CHAR_ARMS = Dict{Char,Arms}()
const CHAR_STYLE = Dict{Char,Style}()
const STYLED_CHAR = Dict{Tuple{Arms,Style},Char}()

function _load_glyphs()
    weight = Dict('.' => NONE, 'l' => LIGHT, 'h' => HEAVY, 'd' => DOUBLE)
    styles = Dict("round" => ROUND, "dash2" => DASH2, "dash3" => DASH3, "dash4" => DASH4)
    for line in eachsplit(GLYPH_SPEC, '\n'; keepempty=false)
        ch, code, flag... = split(line)
        c = only(ch)
        arms = Arms(Tuple(weight[k] for k in code))
        style = isempty(flag) ? SOLID : styles[only(flag)]
        CHAR_ARMS[c] = arms
        CHAR_STYLE[c] = style
        STYLED_CHAR[(arms, style)] = c
    end
end
_load_glyphs()

isstroke(c::Char) = haskey(CHAR_ARMS, c)

"""
    glyph(arms, style=SOLID)

The box-drawing character for a set of arms, or `nothing` if Unicode has none (for example a
heavy arm meeting a double one). A style with no matching character falls back to solid.
"""
function glyph(arms::Arms, style::Style=SOLID)
    get(STYLED_CHAR, (arms, style)) do
        get(STYLED_CHAR, (arms, SOLID), nothing)
    end
end
