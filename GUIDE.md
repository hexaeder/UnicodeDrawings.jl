# Drawing with UnicodeDrawings

This is the guide for drawing a box diagram, written for Claude. You write a scene, a short
Julia file with primitives in it. The tool puts the characters on the grid, merges crossing
strokes into the right junctions and checks the result.

## Workflow

1. Write `scene.jl`: `c = Canvas()`, then the primitives, and end the file with `c`.
2. Run `bin/udraw render scene.jl`. It prints the diagram and lists lint issues on stderr.
3. To fix placement, `udraw render scene.jl --ruler` shows column and row numbers, and
   `udraw locate out.txt '┤'` gives the exact `x y` of each match. Use `locate`, not the
   ruler, when you need a column number. Counting columns off the ruler is easy to get wrong.
4. For overall balance, `tools/screenshot.sh out.txt out.png` renders a PNG.

`udraw lint file.txt` checks a diagram that was drawn by hand. If the file has a ```` ``` ````
fence, only the first fenced block is checked.

## Coordinates

`x` is the column and `y` the row, both starting at 1, with `y` counting downwards. Take
positions from boxes rather than writing numbers where you can. A box has `left`, `right`,
`top` and `bottom` (the columns and rows of its edges) and `cx`, `cy` (its middle).

## Primitives

| call | draws |
|---|---|
| `box!(c, x, y, w, h; label, line, align, valign, pad)` | a box; without `w, h` it is sized around the label |
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
- `align` is `:left`, `:center` or `:right`. For `text!` it says which end of the text sits
  at `x`. For a box label it places the label inside the box, `pad` columns from the edge.

Order matters. Draw boxes and wires first and marks, arrows and text last. Text refuses to
overwrite a stroke and a stroke refuses to overwrite text, so a collision is an error instead
of a silent mess.

To reuse part of a diagram, write a function `part!(c, x, y)` that draws it relative to
`(x, y)` and returns its outer box (see `scenes/008.jl`).

## Lint

An **error** is an arm that meets a stroke with no arm back, like `┬` above `─`. This is what
a one-column slip looks like, so fix it. The one deliberate case is a wire touching a wall
without joining it (`←──│`). Lint can't tell that apart from a slip, so if you meant it, leave
the error. An arrowhead in the last cell (`──→│`) avoids it. A **warning** is a loose end, a stroke running
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
