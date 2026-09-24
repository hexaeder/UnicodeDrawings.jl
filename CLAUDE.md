# UnicodeDrawings

A small Julia tool that lets Claude draw box-drawing diagrams like the ones in PowerDynamics and
NetworkDynamics docstrings. Claude writes a list of primitives, the tool renders them to text (and
PNG via `udraw png`). The column arithmetic is the part a language model gets wrong, so
the tool does it.

`README.md` has the idea in more detail and `examples/` holds the collected diagrams.

## Layout

- `src/glyphs.jl`: each box character as four weighted arms (N E S W), plus line styles.
- `src/canvas.jl`: the grid. Stroke cells merge arms, text cells hold graphemes.
  `parse_text` reads a finished diagram back, and `render` writes one.
- `src/draw.jl`: the primitives (`box!`, `wire!`, `text!`, `mark!`, `arrow!`, `stroke!`).
- `src/lint.jl`: `lint`, `ruler`, `locate`.
- `src/png.jl`: diagram → SVG → PNG with `resvg_jll` and the vendored JuliaMono in `assets/`.
- `src/import.jl`: diagram → scene (`import_scene`), and the `import`/`put` round trip on
  fenced blocks in files. Guesses are checked by drawing them; leftovers become fix-ups.
- `src/cli.jl`: `main`, run by `bin/udraw` or the installed `udraw` app through
  `julia -m UnicodeDrawings`.
- `scenes/NNN.jl` reproduce `examples/NNN_*`.
- `skill/SKILL.md` is the guide for Claude. `udraw install-skill` symlinks the directory into
  `~/.claude/skills`, so the installed skill is this file.

The picture is the source of truth. Scenes are throwaway: import, edit, put back.

Develop in a REPL on the `test` env (a workspace, so it sees the package). The CLI pays the
startup cost on every call, which the precompile workload at the end of the module keeps low.

## Next

- Target list is done (011 013 055 005 007 074 079 053 098 072 008). More scenes from
  `examples/` will show which primitives are missing (braces `⎫⎬⎭`, diagonals `╱`).
- Lint the diagrams in the PowerDynamics/NetworkDynamics docstrings directly from the source files.
