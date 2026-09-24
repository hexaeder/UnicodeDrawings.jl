# UnicodeDrawings

A small Julia tool for drawing box diagrams out of Unicode box-drawing characters, like the
ones in the PowerDynamics and NetworkDynamics docstrings. It is mainly meant to be used by
Claude, which gets the characters right but tends to put them a column off. It works just as
well by hand.

## Installation

With Julia 1.12 or newer, in the Pkg REPL (press `]`):

```
pkg> app dev https://github.com/hexaeder/UnicodeDrawings.jl
```

This clones the repository to `~/.julia/dev/UnicodeDrawings` and installs the `udraw` command
into `~/.julia/bin`, which has to be on your `PATH`. `udraw install-skill` then makes the tool
available to Claude Code.

## How it works

You describe the picture as a short Julia script, a *scene*: boxes, wires, arrows and labels at
integer column and row positions. `udraw render` turns the scene into text:

```julia
c = Canvas()
g = tf!(c, 12, 3, "K", "1 + s T")
wire!(c, (1, 3), (g.left, 3))
wire!(c, (g.right, 3), (g.right + 8, 3))
wire!(c, (g.right + 4, 3), (g.right + 4, 7), (7, 7), (7, 4); cap=(:full, :full))
mark!(c, 6, 3, "(Σ)")
arrow!(c, 7, 4, :up)
arrow!(c, 10, 3, :right)
mark!(c, g.right + 4, 3, "●")
text!(c, 1, 2, "u")
text!(c, g.right + 8, 2, "y"; align=:right)
text!(c, 8, 5, "−")
c
```
```
           ╭─────────╮
u          │    K    │       y
╶────(Σ)─→─┤╶───────╴├───●───╴
      ↑    │ 1 + s T │   │
      │−   ╰─────────╯   │
      │                  │
      ╰──────────────────╯
```

Positions can be computed from other elements (`g.right + 4`), so nothing has to be counted.
Where strokes meet, the tool picks the right junction: the wire ending on the box edge turns
`│` into `┤`, and the corners of the feedback path come out rounded. If two things land on the
same cell, rendering stops with an error instead of producing a mess. Every result is also
checked for strokes that don't line up with their neighbours.

The primitives:

| call | draws |
|---|---|
| `box!(c, x, y, w, h; label)` | a box, or one sized around its label when `w, h` are left out |
| `tf!(c, x, y, num, den)` | a transfer-function block, `num` over `den` |
| `wire!(c, (x1, y1), (x2, y2), ...)` | a wire along horizontal and vertical segments |
| `hline!(c, x1, x2, y)`, `vline!(c, x, y1, y2)` | a straight wire |
| `text!(c, x, y, str)` | a label |
| `mark!(c, x, y, str)` | a symbol on a wire, like `●` or `(+)` |
| `arrow!(c, x, y, dir)` | an arrowhead on a wire |
| `stroke!(c, x, y, '┤')` | a single box character, for details like axis ticks |

Boxes and wires come in `:light`, `:round`, `:heavy` and `:double` line styles, and dashed.
`skill/SKILL.md` has the full description, with all options and the conventions of the
existing diagrams.

## Usage

```
udraw render <input> [--ruler] [--locate <pattern>] [--png] [-o <out>]
udraw import <input> [-o <scene.jl>]
```

- `udraw render scene.jl` prints the diagram, and any problems it found on stderr.
- `--ruler` adds column and row numbers, to see where things landed.
- `--png -o out.png` renders an image instead. It uses the bundled JuliaMono font, so it looks
  the same on every machine.
- `udraw import` goes the other way: it turns a finished diagram into a scene that reproduces
  it, so an existing diagram can be changed by editing the scene.

The input can also be a finished diagram, a file or `-` for stdin. For a Julia source or
markdown file, `file:LINE` picks the diagram block around that line.

## Repository

- `src/`: the package. `canvas.jl` and `glyphs.jl` hold the grid, `draw.jl` the primitives,
  `lint.jl` the checks, `import.jl` the import, `png.jl` the image output and `cli.jl` the
  command line.
- `skill/SKILL.md`: the guide for Claude.
- `examples/`: 99 diagrams collected from PowerDynamics, NetworkDynamics and
  PowerDynamicsLibrary, each with its source location. `examples/scenes/` has scenes that
  reproduce 17 of them exactly. Together they are the test suite.
- `assets/`: the JuliaMono font with its license (SIL Open Font License 1.1).
