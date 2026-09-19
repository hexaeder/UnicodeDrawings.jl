# UnicodeDrawings

A small Julia tool that lets Claude draw box-drawing diagrams like the ones in PowerDynamics and
NetworkDynamics docstrings. Claude writes a list of primitives, the tool renders them to text (and
PNG via `tools/screenshot.sh`). The column arithmetic is the part a language model gets wrong, so
the tool does it.

`README.md` has the idea in more detail and `examples/` holds the collected diagrams.

## Plan

- Primitives with integer coordinates: boxes (light, rounded, heavy, double) with a label, wires
  given as orthogonal paths, arrowheads, free text, and groups so a diagram can be reused inside
  another one.
- Anchors instead of raw coordinates where possible (`box.right`, `box.top + 3`), and helpers for
  text width and for sizing a box around its label.
- Crossing strokes merge into the right junction (`┼`, `┤`, `╂`, ...) through a table keyed on
  which arms are present. No auto-routing: arrowheads, `(+)` points and labels are placed by hand.
- A linter checks that every box-drawing char's arms match its neighbours, and a ruler/grid dump
  shows where things landed. The PNG is for overall balance, not for alignment.
- Core has no dependencies. Use it from a warm REPL, with a thin CLI wrapper on top.

## First targets

Reproduce these exactly, as tests:

- `examples/011_*` transfer-function block (start here)
- `examples/055_*` feedback loop with `●` junctions
- then `005_*` MTKBus, `007_*` CompositeInjector, `098_*` hysteresis plot, `072_*` code
  annotation, `074_*` nested AVR/Gov (mixed heavy/light junctions), `079_*` ND overview
  (arrowheads inside box edges), `053_*` grid sketch, `011`'s limited variant `013_*`, and
  `008_*` compile_bus (groups, double boxes).
