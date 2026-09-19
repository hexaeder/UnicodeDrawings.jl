# Unicode diagrams

`examples/` holds 94 diagrams collected from PowerDynamics, NetworkDynamics and
PowerDynamicsLibrary (src and docs). Each file starts with `# source: path:lines`. They were
collected by `tools/extract.py` and then sorted by hand to drop false positives such as rename
tables, file trees and REPL output.

`tools/screenshot.sh diagram.txt out.png [w] [h]` renders a diagram to PNG with Playwright's
headless Chromium (already in `~/.cache/ms-playwright`). The `pre` uses line-height 1.0 so
vertical strokes join up.

Rough families:

- transfer-function blocks (`╭─┤╶──╴├─╮` with in/out stubs): building_blocks, basic_blocks
- nested composition boxes (`MTKBus`, `MTKLine`, compiled `VertexModel` with `╔═╗` shell)
- signal-flow / feedback loops (`(+)`, `▷ ◁ △ ▽` arrowheads on box edges, `╭╮╰╯` corners)
- one-line grid sketches (`╺┯━┷╸` busbars, `(~)` generators)
- annotations (`╶─┬─╴` underbraces pointing at code, `⎫⎬⎭` braces)
- small plots (hysteresis, saturation)

## Idea: how Claude could draw these

The hard part for a language model is not the characters. It is the columns. The text arrives
as a token stream, so "is this `│` under that `┬`" has to be counted, not seen. So the plan is
to make the column arithmetic explicit and let tools check it.

1. **Scene description, rendered by a script.** A small DSL of primitives with integer
   coordinates: `box(x,y,w,h, style, label)`, `wire(path=[(x,y),…], style)`,
   `arrow(x,y,dir)`, `text(x,y,str)`. The renderer puts them on a character grid and merges
   crossing strokes into the right junction (`─` over `│` → `┼`, a wire hitting a box side
   → `┤`). Those merges are the fiddly part, and a lookup table on "which arms are present"
   gets them right every time.
2. **Hand-placed details stay hand-placed.** Arrowheads, `(+)` summing points and labels are
   placed explicitly as primitives. No auto-routing; Claude picks every coordinate.
3. **A linter instead of eyes.** For every box-drawing char, check that its arms match its
   neighbours (a `┬` needs something with an up-arm below it). This catches most misalignment
   without a screenshot. A render-to-PNG step can come later for looks, since a picture helps
   with spacing and balance but not with a one-column slip.
4. **Examples as the spec.** Take a handful of files from `examples/`, write their scene
   description, and check that the renderer reproduces them exactly. The primitives needed for
   that are the primitive set. The skill/agent spec then becomes the DSL, the style conventions
   visible in the examples, and a few worked scene/output pairs.
