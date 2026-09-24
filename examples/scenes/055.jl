# Feedback loop: wires first, then arrowheads and `●` junctions on top of them.
c = Canvas()
dev = box!(c, 13, 2; label="Device TF G(s)", line=:round)
grid = box!(c, 13, 6, dev.w, 3; label="Grid TF Z(s)", line=:round)
y1, y2 = dev.cy, grid.cy
wire!(c, (6, y1), (dev.left, y1))
wire!(c, (dev.right, y1), (dev.right + 8, y1))
wire!(c, (35, y1), (35, y2), (grid.right, y2))
wire!(c, (9, y1), (9, y2), (grid.left, y2))
arrow!(c, 8, y1, :right); mark!(c, 9, y1, "●"); arrow!(c, dev.left - 1, y1, :right)
arrow!(c, dev.right + 1, y1, :right); mark!(c, 35, y1, "●")
arrow!(c, grid.right + 1, y2, :left); arrow!(c, grid.left - 1, y2, :left)
text!(c, 1, y1, "δu_dq")
text!(c, dev.right + 10, y1, "i_dq")
text!(c, 1, y2, "(bus\n voltage)")
text!(c, 14, dev.top - 1, "(Admittance-like)")
text!(c, 14, grid.bottom + 1, "(Impedance-like)")
c
