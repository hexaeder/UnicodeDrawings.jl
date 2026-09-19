# compile_bus: the same MTKBus drawn twice, the second inside the compiled VertexModel shell.
# The interface wires are drawn `over` the double wall, so they cut it instead of joining it.
function mtkbus!(c, x, y)
    bus = box!(c, x, y, 22, 9; label="MTKBus", align=:left, valign=:top, pad=0)
    bb = box!(c, bus.left + 1, bus.top + 3; label="BusBar", pad=0)
    hub = bb.right + 1
    gen = box!(c, hub + 1, bus.top + 1; label="Generator", pad=0)
    load = box!(c, hub + 1, gen.bottom + 2; label="Load", pad=0)
    wire!(c, (gen.left, gen.cy), (hub, gen.cy), (hub, load.cy), (load.left, load.cy); line=:light)
    wire!(c, (bb.right, bb.cy), (hub, bb.cy)); mark!(c, hub, bb.cy, "o")
    bus
end

c = Canvas()
text!(c, 1, 7, "compile_bus(")
bus = mtkbus!(c, 13, 3)
text!(c, bus.right + 1, 7, ") =>")

vm = box!(c, 51, 1, 27, 12; label="VertexModel (compiled)", line=:double, align=:left, valign=:top)
inner = mtkbus!(c, vm.left + 3, vm.top + 2)
wire!(c, (49, 6), (inner.left - 1, 6); over=true, cap=:full); arrow!(c, inner.left - 1, 6, :right)
wire!(c, (49, 8), (inner.left - 1, 8); over=true, cap=:full); arrow!(c, 49, 8, :left)
text!(c, 41, 3, "Network"); text!(c, 40, 4, "interface")
text!(c, 41, 6, "current"); text!(c, 41, 8, "voltage")
c
