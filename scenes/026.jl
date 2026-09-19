# Busbar with its interface: current in, voltage out, and the terminal on the right.
c = Canvas()
bb = box!(c, 12, 1, 12, 5; label="Busbar")
# these wires stop one cell short of the box, so they point at it without joining
wire!(c, (9, 2), (bb.left - 1, 2); cap=:full); arrow!(c, bb.left - 1, 2, :right)
wire!(c, (9, 4), (bb.left - 1, 4); cap=:full); arrow!(c, 9, 4, :left)
wire!(c, (bb.right, bb.cy), (bb.right + 4, bb.cy)); mark!(c, bb.right + 4, bb.cy, "o")
text!(c, 7, 2, "i_lines"; align=:right); text!(c, 7, 4, "u_bus"; align=:right)
text!(c, bb.right + 3, 2, "(t)")
c
