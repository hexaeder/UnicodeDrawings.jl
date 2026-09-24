# MTKBus constructor: the call on the left, the resulting nested bus on the right.
c = Canvas()
text!(c, 1, 5, "MTKBus(")
gen = box!(c, 9, 4; label="Generator", pad=0)
wire!(c, (8, 5), (gen.left, 5)); mark!(c, 8, 5, "o")
text!(c, gen.right + 1, 5, ",")
load = box!(c, 23, 4; label="Load", pad=0)
wire!(c, (22, 5), (load.left, 5)); mark!(c, 22, 5, "o")
text!(c, load.right + 1, 5, ") =>")

bus = box!(c, 34, 1, 22, 9; label="MTKBus", align=:left, valign=:top, pad=0)
bb = box!(c, bus.left + 1, bus.top + 2; label="BusBar", pad=0)
hub = bb.right + 1  # column of the connection point
gen = box!(c, hub + 1, bus.top + 1; label="Generator", pad=0)
load = box!(c, hub + 1, gen.bottom + 1; label="Load", pad=0)
wire!(c, (gen.left, gen.cy), (hub, gen.cy), (hub, load.cy), (load.left, load.cy); line=:light)
wire!(c, (bb.right, bb.cy), (hub, bb.cy)); mark!(c, hub, bb.cy, "o")
text!(c, bus.left + 2, bus.bottom - 1, "+ SystemBase")
c
