# UnicodeDrawings

A small Julia tool for drawing box diagrams like the ones in the PowerDynamics and
NetworkDynamics docstrings. You write a scene of boxes, wires and labels in a few lines of Julia,
and `udraw` places the characters, merges crossing strokes into the right junctions and lints
the result.

```julia
c = Canvas()
tf = tf!(c, 5, 3, "K", "1 + s T")
hline!(c, tf.left - 4, tf.left, tf.cy)
hline!(c, tf.right, tf.right + 5, tf.cy)
text!(c, tf.left - 2, tf.top + 1, "in"; align=:right)
text!(c, tf.right + 2, tf.top + 1, "out")
c
```
```
$ udraw render pt1.jl
    ╭─────────╮
 in │    K    │ out
╶───┤╶───────╴├────╴
    │ 1 + s T │
    ╰─────────╯
lint: 0 errors, 0 warnings, 20×5
```

It is mainly meant to be driven by Claude, which gets the characters right but tends to slip a
column. The tool does the column arithmetic, and a skill tells Claude how to use it. It works
just as well by hand.

## Installation

### Install `udraw` as an app

You need Julia 1.12 or newer, nothing else. In the Pkg REPL (press `]` in Julia):

```
pkg> app dev https://github.com/hexaeder/UnicodeDrawings.jl
```

This clones the repository into `~/.julia/dev/UnicodeDrawings` and puts the `udraw` launcher in
`~/.julia/bin`. Since it is a dev install, the launcher runs the code in that clone, so a
`git pull` there is all an update takes. The Claude skill refers to that directory for the
example scenes.

Make sure `~/.julia/bin` is on your `PATH` so you can call `udraw` from the terminal.

The launcher remembers the Julia binary it was installed with. After removing that Julia
version, run `app dev` again.

Without installing, `bin/udraw` in the repository does the same thing.

### Install the Claude skill

```sh
udraw install-skill
```

This symlinks `skill/` to `~/.claude/skills/udraw`, so Claude Code picks up `skill/SKILL.md` in
new sessions and uses it whenever a diagram has to be drawn or changed. Since it is a link, the
skill follows the repository as well.

## Usage

```
udraw render <scene.jl> [--ruler] [-o <out.txt>]
udraw lint   <diagram.txt | scene.jl | source file>
udraw ruler  <diagram.txt | scene.jl>
udraw locate <diagram.txt | scene.jl> <pattern>
udraw png    <diagram.txt | scene.jl> <out.png>
udraw import <file>[:<line>] [-o <scene.jl>]
udraw put    <scene.jl>
udraw install-skill
```

### Drawing a new diagram

A scene is a Julia file that starts with `c = Canvas()`, calls the drawing primitives and ends
with `c`. The primitives are `box!`, `tf!` (a transfer-function block), `wire!`, `hline!`,
`vline!`, `text!`, `mark!`, `arrow!` and `stroke!`. `skill/SKILL.md` describes them, with the
coordinate conventions and the styles found in the existing diagrams.

`udraw render scene.jl` prints the diagram to stdout and the lint report to stderr. If two
things land on the same cell, rendering stops with the scene line that caused it and the
diagram drawn so far.

To find out where things landed, `--ruler` adds column and row numbers, and `udraw locate` prints
the exact `x y` of each match of a pattern:

```
$ udraw render pt1.jl --ruler
           1         2
  12345678901234567890
1     ╭─────────╮
2  in │    K    │ out
3 ╶───┤╶───────╴├────╴
4     │ 1 + s T │
5     ╰─────────╯
$ udraw render pt1.jl -o pt1.txt; udraw locate pt1.txt '┤'
5 3
```

### Editing a diagram in a docstring

Diagrams live in docstrings and markdown files, so there is no scene to keep around. Instead,
`import` rebuilds a scene from the fenced block at a given line, and `put` writes the edited
scene back into the same block:

```sh
udraw import src/Library/building_blocks.jl:52 -o scene.jl
$EDITOR scene.jl
udraw put scene.jl
```

The imported scene reproduces the block exactly. Boxes, transfer-function blocks, wires and
labels come back as primitives, and anything not recognised becomes per-cell fix-ups at the end
of the scene. `put` refuses to write if the block was changed by hand since the import.

### Checking a diagram

`udraw lint` checks the arms of every box character against its neighbours, which is what a
one-column slip breaks. On a source or markdown file it checks every diagram block in it and
reports issues at their line in the file. Errors are misaligned strokes and set the exit status
to 1. Warnings are loose ends and the like, which finished diagrams often have on purpose.

### PNG

```sh
udraw png diagram.txt out.png
```

renders a diagram, or a scene, as an image, which helps with spacing and balance. The font is
the bundled JuliaMono and system fonts are ignored, so the result looks the same everywhere.

## Repository

- `src/`: the package. `glyphs.jl` and `canvas.jl` model the grid, `draw.jl` has the
  primitives, `lint.jl` the checks, `import.jl` the import/put round trip, `png.jl` the image
  output and `cli.jl` the command line.
- `assets/`: JuliaMono Regular with its license (SIL Open Font License 1.1).
- `skill/SKILL.md`: the guide for Claude, and the most complete description of the primitives.
- `examples/`: 97 diagrams collected from PowerDynamics, NetworkDynamics and
  PowerDynamicsLibrary. Each file starts with `# source: path:lines`. `tools/extract.py` found
  them, and false positives such as file trees and REPL output were removed by hand.
- `scenes/`: scenes that reproduce 15 of the examples exactly, including the large REEC_C,
  REGC_C and WTGWGO_A diagrams. They are the test suite.
- `designs/`: new diagrams drawn with the tool, the IEEE AC1C exciter and the DEGOV1 governor.

Tests run on the `test` environment, a workspace that sees the package:

```sh
julia --project=test test/runtests.jl
```

A CLI call takes about 0.6 s, mostly Julia's own startup. A precompile workload at the end of
the module keeps the rest low.

## How it works

For a language model the hard part of these diagrams is not the characters but the columns.
Text arrives as a stream of tokens, so whether a `│` sits under a `┬` has to be counted, not
seen. The tool makes that arithmetic explicit and checks it.

- **Scenes with integer coordinates.** Every primitive is placed at an explicit column and row,
  usually relative to a box (`tf.right + 2`). There is no auto-routing. Claude picks every
  coordinate, but can compute it instead of counting.
- **Merging strokes.** Each box character is stored as four arms (N E S W) with a weight. Strokes
  on the same cell add their arms, and a lookup picks the character, so `─` over `│` becomes
  `┼` and a wire ending on a box side becomes `┤`.
- **Collisions are errors.** Text never overwrites anything and a stroke never overwrites text,
  so a misplaced label fails loudly instead of producing a mess.
- **A linter instead of eyes.** A box character with an arm pointing at a neighbour that has no
  arm back is misaligned. This catches most slips without a screenshot.
- **The examples are the spec.** The primitive set is what it takes to reproduce the collected
  diagrams exactly, and `scenes/` keeps it that way.

Rough families among the collected diagrams:

- transfer-function blocks (`╭─┤╶──╴├─╮` with in/out stubs): building_blocks, basic_blocks
- nested composition boxes (`MTKBus`, `MTKLine`, compiled `VertexModel` with `╔═╗` shell)
- signal-flow and feedback loops (`(+)`, `▷ ◁ △ ▽` arrowheads on box edges, `╭╮╰╯` corners)
- one-line grid sketches (`╺┯━┷╸` busbars, `(~)` generators)
- annotations (`╶─┬─╴` underbraces pointing at code, `⎫⎬⎭` braces)
- small plots (hysteresis, saturation)
