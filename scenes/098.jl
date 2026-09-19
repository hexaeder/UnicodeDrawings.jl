# Hysteresis plot: sharp corners, full-stroke line ends, axis ticks via `stroke!`.
c = Canvas()
wire!(c, (5, 2), (5, 5), (20, 5); line=:light, cap=(:half, :full))
wire!(c, (5, 4), (15, 4), (15, 2), (20, 2); line=:light, cap=:full)
wire!(c, (9, 4), (9, 2), (20, 2); line=:light, cap=(:half, :full))
stroke!(c, 5, 2, '┤'); stroke!(c, 5, 4, '┼')
stroke!(c, 9, 5, '┴'); stroke!(c, 15, 5, '┴')
arrow!(c, 12, 2, :left; head=:smallsolid); arrow!(c, 12, 4, :right; head=:smallsolid)
arrow!(c, 9, 3, :down; head=:smallsolid); arrow!(c, 15, 3, :up; head=:smallsolid)
text!(c, 2, 1, "out")
text!(c, 3, 2, "1"); text!(c, 3, 4, "0")
text!(c, 22, 5, "in")
text!(c, 8, 6, "off"); text!(c, 15, 6, "on")
c
