---
name: udraw
description: Draw, edit and lint diagrams made of Unicode box-drawing characters (┌─┐ ╭─╮ ├─→┤): block diagrams, signal flow, component sketches. Use when such a diagram has to be made or changed in a docstring, a markdown file or a plain text file.
---

# Drawing with UnicodeDrawings

You write a scene, a short Julia file with primitives in it. The tool puts the characters on the
grid, merges crossing strokes into the right junctions and checks the result.

`udraw` is a Pkg app that runs from `~/.julia/dev/UnicodeDrawings`. Paths below, like
`examples/scenes/011.jl`, are relative to that directory.

## Workflow

1. Write `scene.jl`: `c = Canvas()`, then the primitives, and end the file with `c`.
   `udraw help` prints the reference for all of them (`box!`, `tf!`, `wire!`, `text!`,
   `mark!`, `arrow!`, …), and `udraw help wire!` a single one. Read it before the first scene.
2. Run `udraw render scene.jl` (or `-o out.txt` to write a file). It prints the diagram,
   then lint issues and a `lint: N errors, M warnings` line on stderr. If the scene fails,
   for example on a collision, you get the message, the scene line and the canvas drawn so far.
3. To fix placement, `udraw render scene.jl --ruler` shows column and row numbers, and
   `udraw render scene.jl --locate '┤'` gives the exact `x y` of each match. Use `--locate`
   when you need a column number. Counting columns off the ruler is easy to get wrong.
4. For overall balance, `udraw render scene.jl --png -o out.png` renders an image you can
   look at. With `--ruler` the numbers are in the image too.

`render` also takes a finished diagram instead of a scene: a text file, a block of a source
file as `src/Model.jl:LINE`, or `-` for stdin. It then prints it back with the lint report,
which is how to check a diagram that was drawn by hand.

## Writing a scene

`x` is the column and `y` the row, both starting at 1, with `y` counting downwards. Take
positions from boxes rather than writing numbers. `box!` returns a box with `left`, `right`,
`top`, `bottom`, `cx` and `cy`, so a wire written as `(g.right, g.cy)` stays attached when the
box grows.

Order matters. Draw boxes and wires first and marks, arrows and text last. Text refuses to
overwrite anything and a stroke refuses to overwrite text, so a collision is an error instead
of a silent mess. Text can't see strokes drawn after it, though, so check a centred label
against its neighbours' edges yourself.

To reuse part of a diagram, write a function `part!(c, x, y)` that draws it relative to
`(x, y)` and returns its outer box (see `examples/scenes/008.jl`).

## Editing an existing diagram

Diagrams live in docstrings and markdown; there is no scene file to keep. To change one:

1. `udraw import src/Model.jl:LINE -o scene.jl` turns the fenced block around `LINE` into a
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
   `insertrows!` does the same for rows, and `rows=`/`cols=` limits either to part of the
   drawing. After an insert, box variables still hold their old position, so for anything
   right of the cut add the inserted width yourself.
   `box!(…; clear=true)` empties its rectangle and joins its edges to whatever points at it.
3. `udraw render scene.jl -o new.txt`, then replace the lines between the fences with it,
   indented like the fence. Afterwards `udraw render src/Model.jl:LINE` checks the block in
   place. The scene can be thrown away.

The lint line ends with the size, like `96×15`, so a width limit is easy to check. `pad=0` on
a box saves two columns.

For a one-character fix, editing the text directly and checking it with `udraw render` is
quicker.

## Lint

An **error** is an arm that meets a stroke with no arm back, like `┬` above `─`. This is what
a one-column slip looks like, so fix it. The one deliberate case is a wire touching a wall
without joining it (`←──│`). Lint can't tell that apart from a slip, so if you meant it, leave
the error. An arrowhead in the last cell (`──→│`) avoids it.

A **warning** is a loose end (a full stroke pointing into empty space; a half-stroke `╶` is a
proper end and isn't reported), a stroke running into a word, a heavy arm meeting a light
one, or two labels that touch and read as one word. Finished diagrams have these on purpose (wire ends, axis ticks), so read them but don't
chase every one.

## Style

In a repository that already has diagrams, look at two or three of them before drawing (search
the docs and docstrings for `┌` or `╭`) and follow their choices: box and line styles,
arrowheads, how sums and limits are drawn, and how wide they get.

Without such a model, keep it plain. Arrowheads sit on the wire one cell before the box they
point into (`arrow=-2`), labels go above the wire, and a label keeps a column of space from any stroke.

## Example

`examples/scenes/` holds the scenes for the examples the tool reproduces exactly, with `104.jl`
and `105.jl` as larger block diagrams. Start with `011.jl`:

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
