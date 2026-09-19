# Drawing with UnicodeDrawings

This is the guide for drawing a box diagram, written for Claude. You write a scene, a short
Julia file with primitives in it. The tool puts the characters on the grid, merges crossing
strokes into the right junctions and checks the result.

## Workflow

1. Write `scene.jl`: `c = Canvas()`, then the primitives, and end the file with `c`.
2. Run `bin/udraw render scene.jl` (or `-o out.txt` to write a file). It prints the diagram,
   then lint issues and a `lint: N errors, M warnings` line on stderr. If the scene fails,
   for example on a collision, you get the message, the scene line and the canvas drawn so far.
3. To fix placement, `udraw render scene.jl --ruler` shows column and row numbers, and
   `udraw locate out.txt '┤'` gives the exact `x y` of each match. Use `locate`, not the
   ruler, when you need a column number. Counting columns off the ruler is easy to get wrong.
4. For overall balance, `tools/screenshot.sh out.txt out.png` renders a PNG.

`udraw lint file.txt` checks a diagram that was drawn by hand. If the file has a ```` ``` ````
fence, only the first fenced block is checked.

## Editing an existing diagram

Diagrams live in docstrings and markdown; there is no scene file to keep. To change one:

1. `bin/udraw import src/Model.jl:LINE -o scene.jl` turns the fenced block around `LINE` into a
   scene (without `:LINE` it lists the blocks when there are several). Rendering the imported
   scene gives back the diagram exactly: boxes, `tf!` blocks, wires, labels and marks are
   recognised, and whatever isn't ends up as per-cell fix-ups at the bottom.
2. Edit the scene. Wire ends on a box and text next to a box are written relative to it
   (`tf.right + 2`), so they move when the box grows. Everything else has plain coordinates.
   To make room for something new, don't shift coordinates by hand. Append to the end of the
   scene instead:
   ```julia
   insertcols!(c, lim.left, 6)    # 6 empty columns before `lim`; crossing wires stretch
   lv = box!(c, lim.left + 1, lim.top; label="LV", pad=0, clear=true)   # drops onto the wire: ┤LV├
   ```
   `insertrows!` does the same for rows. After an insert, box variables still hold their old
   position, so for anything right of the cut add the inserted width yourself.
   `box!(…; clear=true)` empties its rectangle and joins its edges to whatever points at it.
3. `bin/udraw put scene.jl` renders the scene and replaces the block in the original file. It
   refuses if the block was changed by hand since the import; import again then. Keep the
   `# udraw:` first line intact, it says where the block is. The scene can be edited and put
   again as often as you like, and thrown away afterwards.

`udraw lint src/Model.jl` checks every diagram block in the file. The lint line ends with the
size, like `96×15`, so a width limit is easy to check. `pad=0` on a box saves two columns.

For a one-character fix, editing the text directly and running `udraw lint` is quicker.

## Coordinates

`x` is the column and `y` the row, both starting at 1, with `y` counting downwards. Take
positions from boxes rather than writing numbers where you can. A box has `left`, `right`,
`top` and `bottom` (the columns and rows of its edges) and `cx`, `cy` (its middle, rounded
up and to the left when the size is even).

`w` and `h` count both walls. A box sized around its label is as wide as the widest label
line plus `2 + 2·pad` (`pad=1` by default) and as tall as the number of lines plus 2. Widths
are display widths, so `T₁`, `s²` and `ẋ` take one column per character, as you'd expect.

## Primitives

| call | draws |
|---|---|
| `box!(c, x, y, w, h; label, line, align, valign, pad)` | a box; without `w, h` it is sized around the label |
| `tf!(c, x, y, num, den)` | a transfer-function block, `num` over `den`, with the fraction bar on row `y` |
| `wire!(c, (x1, y1), (x2, y2), ...; line, cap, over)` | an orthogonal path through the points |
| `hline!(c, x1, x2, y)`, `vline!(c, x, y1, y2)` | a one-segment wire |
| `text!(c, x, y, str; align)` | text; `\n` continues on the next row |
| `mark!(c, x, y, str)` | text on top of a stroke: `●`, `o`, `(+)`, `∙` |
| `arrow!(c, x, y, dir; head)` | an arrowhead on top of a stroke |
| `stroke!(c, x, y, '┤')` | add the arms of one box character, for details like axis ticks |

- `line` is `:light`, `:round` (light with rounded corners), `:heavy` or `:double`. Boxes
  default to `:light` and wires to `:round`. `dash=2, 3, 4` gives dashed lines.
- A wire's ends are half-strokes (`╶──╴`) in open space and junctions (`┤`) on a box edge.
  `cap=:full` makes the ends plain `─`. It can be a tuple like `(:half, :full)`.
- Strokes on the same cell merge: a wire ending on a box edge turns `│` into `┤`, and a light
  wire on a heavy edge makes `┷`. With `over=true` a wire replaces what is under it instead,
  so crossing a box wall leaves a gap (`──────` straight through `║`).
- `dir` is `:up`, `:right`, `:down` or `:left`. `head` is `:arrow` (→), `:triangle` (▷),
  `:solid` (▶), `:small` (▹) or `:smallsolid` (▸).
- `align` is `:left`, `:center` or `:right`. For `text!` it says what sits at `x`: the first
  character, the middle one (rounded left) or the last. For a box label it places the label
  inside the box, `pad` columns from the edge.

Order matters. Draw boxes and wires first and marks, arrows and text last. Text refuses to
overwrite anything and a stroke refuses to overwrite text, so a collision is an error instead
of a silent mess. Text can't see strokes drawn after it, though, so check a centred label
against its neighbours' edges yourself.

To reuse part of a diagram, write a function `part!(c, x, y)` that draws it relative to
`(x, y)` and returns its outer box (see `scenes/008.jl`).

## Lint

An **error** is an arm that meets a stroke with no arm back, like `┬` above `─`. This is what
a one-column slip looks like, so fix it. The one deliberate case is a wire touching a wall
without joining it (`←──│`). Lint can't tell that apart from a slip, so if you meant it, leave
the error. An arrowhead in the last cell (`──→│`) avoids it. A **warning** is a loose end (a full stroke pointing into empty space; a
half-stroke `╶` is a proper end and isn't reported), a stroke running
into a word, or a heavy arm meeting a light one. Finished diagrams have these on purpose (wire
ends, axis ticks), so read them but don't chase every one.

## Conventions in the existing diagrams

- Transfer-function blocks are `:round` boxes. In/out wires end in half-strokes, with the
  signal name above the wire.
- Components are `:light` boxes. Containers (bus, AVR, governor) are `:heavy` and compiled
  models are `:double`.
- Arrowheads sit on the wire, usually one cell before the box they point into. A wire can
  also stop one cell short and put its arrow there (`──→│`), which points at the box without
  joining it. Don't use `over=true` for that, because it cuts the wall. In the
  NetworkDynamics diagrams, triangles (`▽ △`) sit on the box edge itself.
- `o` is a terminal or connection point, and `●` or `∙` is a junction where a signal splits.
- A summing point is either a mark on the wire, `(Σ)` or `(+)`, with the inputs arriving from
  the sides and a `+`/`-` next to each arrow, or a small box labelled `Σ` with the signs
  written inside next to each input (better for three or more inputs).
- Limits of a block go above and below its right corner (`V_Amax` / `V_Amin`), or use the
  `__ max` / `min __/` notation of `scenes/013.jl`.
- Leave a column of space between a label and a wire, or end the wire with a half-stroke.

## Example

`scenes/` holds the scenes for the examples the tool reproduces exactly. Start with `011.jl`:

```julia
c = Canvas()
tf = box!(c, 5, 1; label="K\n\n1 + s T", line=:round)
hline!(c, tf.left + 1, tf.right - 1, tf.cy)
wire!(c, (1, tf.cy), (tf.left, tf.cy))
wire!(c, (tf.right, tf.cy), (tf.right + 5, tf.cy))
text!(c, tf.left - 2, tf.cy - 1, "in"; align=:right)
text!(c, tf.right + 2, tf.cy - 1, "out")
c
```
```
    ╭─────────╮
 in │    K    │ out
╶───┤╶───────╴├────╴
    │ 1 + s T │
    ╰─────────╯
```
