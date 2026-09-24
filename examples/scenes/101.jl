# Full REEC_C figure (EPRI 3002027129, Figure 4-7 with the storage part of Figure 4-12).

# PI block `kp + ki/s` as a fraction, wire along y, clamp limits in the __/ notation, state
# label under the right corner
function pi!(c, x, y, kp, ki; max, min, state)
    inner = " $kp + " * " "^(textwidth(ki) + 2) * " "
    b = box!(c, x, y - 2, textwidth(inner) + 2, 5; line=:round)
    xb = b.left + 1 + textwidth(" $kp + ")
    text!(c, b.left + 2, y, "$kp +")
    hline!(c, xb, xb + textwidth(ki) + 1, y)
    text!(c, xb + 1, y - 1, ki)
    text!(c, xb + 1 + textwidth(ki) ÷ 2, y + 1, "s")
    text!(c, b.right - 1, b.top - 2, "__ $max")
    text!(c, b.right - 2, b.top - 1, "/")
    text!(c, b.left + 5, b.bottom + 1, "$min __/"; align=:right)
    text!(c, b.right - 2, b.bottom + 1, state)
    b
end

# clamp on a bare wire along y; the slope crosses the wire at x + 1
function clampw!(c, x, y; max=nothing, min=nothing)
    isnothing(max) || (text!(c, x + 2, y - 1, "/"); text!(c, x + 3, y - 2, "__ $max"))
    isnothing(min) || text!(c, x, y + 1, "$min __/"; align=:right)
end

# structural switch: input 1 on the wire row y, input 0 two rows below, output on row y
function flag!(c, x, y, name)
    b = box!(c, x, y - 1, textwidth(name) + 6, 5)
    text!(c, b.left + 1, y, "== 1")
    text!(c, b.left + 1, y + 2, "== 0")
    text!(c, b.cx + 1, y + 1, name; align=:center)
    b
end

# summing point on the wire at column x, fed from the left
function sum!(c, x, y)
    mark!(c, x - 1, y, "(Σ)"); arrow!(c, x - 2, y, :right)
end

# parameter from below into (x, y): arrow, a stub, and the name under it
function from_below!(c, x, y, name)
    vline!(c, x, y + 1, y + 2); arrow!(c, x, y + 1, :up)
    text!(c, x, y + 3, name; align=:center)
end

# a frozen block: dashed arrow into its top, labelled above it, or beside it where a wire is close
function freeze!(c, b; side=false)
    x = side ? b.left + 2 : b.cx
    wire!(c, (x, b.top - 3), (x, b.top - 1); dash=2); arrow!(c, x, b.top - 1, :down)
    if side
        text!(c, x + 2, b.top - 3, "Freeze state if\nVoltage_dip = 1")
    else
        text!(c, x, b.top - 4, "Freeze state if Voltage_dip = 1"; align=:center)
    end
end

# `|name⟩──` arriving from the left, the wire starting flush at the bracket
tag!(c, x, y, name) = (text!(c, x, y, "|$name⟩"); x + textwidth(name) + 2)
# `──|name⟩` leaving to the right at column x
tagout!(c, x, y, name) = text!(c, x, y, "|$name⟩")

c = Canvas()

#### injection from the voltage error
ya = 5
vf = tf!(c, 8, ya, "1", "1 + s Trv"); text!(c, vf.left + 1, vf.bottom + 1, "s0")
hline!(c, tag!(c, 1, ya, "Vt"), vf.left, ya; cap=(:full, :half)); arrow!(c, vf.left - 1, ya, :right)
text!(c, vf.right + 1, ya - 1, "Vt_filt")
db = box!(c, 35, ya - 1; label="deadband", line=:round); text!(c, db.cx, db.bottom + 1, "dbd1, dbd2"; align=:center)
kqv = box!(c, db.right + 4, ya - 1; label="Kqv", line=:round)
hline!(c, vf.right, db.left, ya); sum!(c, 30, ya); text!(c, 28, ya + 1, "−")
from_below!(c, 30, ya, "Vref0")
arrow!(c, db.left - 1, ya, :right)
hline!(c, db.right, kqv.left, ya); arrow!(c, kqv.left - 1, ya, :right)

#### reactive path
yb = 16
xiq = 146                      # Σ where the injection joins
text!(c, 1, yb - 1, "pfaref")
tn = box!(c, 9, yb - 1; label="tan", line=:round)
hline!(c, 1, tn.left, yb); arrow!(c, tn.left - 1, yb, :right)
pf = tf!(c, 8, yb - 4, "1", "1 + s Tp"); text!(c, pf.right - 2, pf.top - 1, "s1")
hline!(c, tag!(c, 1, yb - 4, "Pe"), pf.left, yb - 4; cap=(:full, :half)); arrow!(c, pf.left - 1, yb - 4, :right)
wire!(c, (pf.right, yb - 4), (22, yb - 4), (22, yb - 1)); arrow!(c, 22, yb - 1, :down)
mf = flag!(c, 25, yb, "PfFlag")
hline!(c, tn.right, mf.left, yb); mark!(c, 21, yb, "(×)"); arrow!(c, 20, yb, :right); arrow!(c, mf.left - 1, yb, :right)
hline!(c, tag!(c, 1, yb + 2, "Qext"), mf.left, yb + 2; cap=(:full, :half)); arrow!(c, mf.left - 1, yb + 2, :right)
text!(c, mf.right + 2, yb - 1, "Qcmd")

pq = pi!(c, 61, yb, "Kqp", "Kqi"; max="Vmax", min="Vmin", state="s2")
mv = flag!(c, 79, yb, "VFlag")
pv = pi!(c, 113, yb, "Kvp", "Kvi"; max="Iqmax", min="Iqmin", state="s3")
mq = flag!(c, 131, yb, "QFlag")
hline!(c, mf.right, pq.left, yb); clampw!(c, 48, yb; max="Qmax", min="Qmin")
sum!(c, 53, yb); arrow!(c, pq.left - 1, yb, :right)
wire!(c, (tag!(c, 45, yb + 3, "Qgen"), yb + 3), (53, yb + 3), (53, yb + 1); cap=(:full, :half))
arrow!(c, 53, yb + 1, :up); text!(c, 54, yb + 1, "−")
hline!(c, pq.right, mv.left, yb); arrow!(c, mv.left - 1, yb, :right)
hline!(c, mv.right, pv.left, yb); clampw!(c, 98, yb; max="Vmax", min="Vmin")
sum!(c, 104, yb); arrow!(c, pv.left - 1, yb, :right)
hline!(c, pv.right, mq.left, yb); arrow!(c, mq.left - 1, yb, :right)
hline!(c, mq.right, 164, yb; cap=(:half, :full)); sum!(c, xiq, yb); clampw!(c, 151, yb; max="Iqmax", min="Iqmin")
tagout!(c, 165, yb, "Iqcmd")
# the injection comes down into the last sum
wire!(c, (kqv.right, ya), (xiq, ya), (xiq, yb - 1)); clampw!(c, 65, ya; max="Iqh1", min="Iql1")
arrow!(c, xiq, yb - 1, :down); text!(c, kqv.right + 2, ya - 1, "Iqv")
# s2 and s3 freeze together
wire!(c, (pq.cx, pq.top - 3), (pv.cx, pq.top - 3); dash=2)
for p in (pq, pv)
    wire!(c, (p.cx, p.top - 3), (p.cx, p.top - 1); dash=2); arrow!(c, p.cx, p.top - 1, :down)
end
text!(c, (pq.cx + pv.cx) ÷ 2, pq.top - 4, "Freeze state if Voltage_dip = 1"; align=:center)

# Qcmd straight to the voltage regulator, or divided by the voltage past both regulators
yc = yb + 10
wire!(c, (40, yb), (40, yc), (100, yc)); mark!(c, 40, yb, "●")
wire!(c, (77, yc), (77, yb + 2), (mv.left, yb + 2)); mark!(c, 77, yc, "●"); arrow!(c, mv.left - 1, yb + 2, :right)
mark!(c, 100, yc, "(÷)"); arrow!(c, 99, yc, :right)
lq = tf!(c, 107, yc, "1", "1 + s Tiq"); text!(c, lq.left + 1, lq.bottom + 1, "s4"); freeze!(c, lq; side=true)
hline!(c, 103, lq.left, yc; cap=(:full, :half)); arrow!(c, lq.left - 1, yc, :right)
wire!(c, (lq.right, yc), (129, yc), (129, yb + 2), (mq.left, yb + 2)); arrow!(c, mq.left - 1, yb + 2, :right)
x = tag!(c, 91, yb + 3, "Vt_filt")
wire!(c, (x, yb + 3), (104, yb + 3), (104, yb + 1); cap=(:full, :half)); arrow!(c, 104, yb + 1, :up); text!(c, 105, yb + 1, "−")
vline!(c, 101, yb + 3, yc - 1); mark!(c, 101, yb + 3, "●"); arrow!(c, 101, yc - 1, :down)
text!(c, 100, yc - 3, "0.01 __/"; align=:right)

#### current limits
cl = box!(c, 140, yb + 13, 21, 9; label="current limit\nlogic\n\nPqflag", line=:light)
vq = box!(c, 128, cl.top + 1; label="VDLq", line=:round)
vp = box!(c, 128, cl.bottom - 3; label="VDLp", line=:round)
text!(c, 115, vq.cy, "|Vt_filt⟩")
hline!(c, 124, vq.left, vq.cy; cap=(:full, :half)); wire!(c, (125, vq.cy), (125, vp.cy), (vp.left, vp.cy)); mark!(c, 125, vq.cy, "●")
arrow!(c, vq.left - 1, vq.cy, :right); arrow!(c, vp.left - 1, vp.cy, :right)
hline!(c, vq.right, cl.left, vq.cy); arrow!(c, cl.left - 1, vq.cy, :right)
hline!(c, vp.right, cl.left, vp.cy); arrow!(c, cl.left - 1, vp.cy, :right)
# limits up to the Iqcmd clamp, the command back down
vline!(c, 147, cl.top, yb + 2; dash=2); arrow!(c, 147, yb + 2, :up)
vline!(c, 159, yb, cl.top; dash=2); mark!(c, 159, yb, "●"); arrow!(c, 159, cl.top - 1, :down)

#### active path
yp = cl.bottom + 6
text!(c, 12, yp - 2, "dPmax"); text!(c, 14, yp - 1, "/")
text!(c, 12, yp + 1, "/"); text!(c, 12, yp + 2, "dPmin"; align=:center); text!(c, 16, yp + 1, "s6")
lp = tf!(c, 24, yp, "1", "1 + s Tpord"); freeze!(c, lp)
text!(c, lp.right - 1, lp.top - 2, "__ Pmax"); text!(c, lp.right - 2, lp.top - 1, "/")
text!(c, lp.left + 5, lp.bottom + 1, "Pmin __/"; align=:right); text!(c, lp.right - 2, lp.bottom + 1, "s5")
hline!(c, tag!(c, 1, yp, "Pref"), lp.left, yp; cap=(:full, :half)); arrow!(c, lp.left - 1, yp, :right)
hline!(c, lp.right, 164, yp; cap=(:half, :full)); text!(c, lp.right + 2, yp - 1, "Pord")
# the division by the voltage and the Paux sum, with room between them
xd, xs = 65, 78
mark!(c, xd - 1, yp, "(÷)"); arrow!(c, xd - 2, yp, :right)
text!(c, xd - 14, yp - 3, "|Vt_filt⟩"); wire!(c, (xd - 5, yp - 3), (xd, yp - 3), (xd, yp - 1); cap=(:full, :half)); arrow!(c, xd, yp - 1, :down)
clampw!(c, xd - 2, yp - 3; min="0.01")
sum!(c, xs, yp)
wire!(c, (tag!(c, xs - 12, yp + 2, "Paux"), yp + 2), (xs, yp + 2), (xs, yp + 1); cap=(:full, :half)); arrow!(c, xs, yp + 1, :up)
clampw!(c, 144, yp; max="Ipmax", min="Ipmin")
tagout!(c, 165, yp, "Ipcmd")
vline!(c, 148, cl.bottom, yp - 3; dash=2); arrow!(c, 148, yp - 3, :down)
vline!(c, 159, yp, cl.bottom; dash=2); mark!(c, 159, yp, "●"); arrow!(c, 159, cl.bottom + 1, :up)

#### state of charge
ys = yp + 7
si = tf!(c, 90, ys, "1", "s T"); text!(c, si.left + 1, si.top - 1, "s7")
# the integrator runs freely, only the state of charge is clamped
lg = box!(c, 128, ys - 1; label="SOC ≥ SOCmax: Ipmin = 0\nSOC ≤ SOCmin: Ipmax = 0", line=:light)
hline!(c, tag!(c, 82, ys, "Pe"), si.left, ys; cap=(:full, :half)); arrow!(c, si.left - 1, ys, :right)
hline!(c, si.right, lg.left, ys); arrow!(c, lg.left - 1, ys, :right)
sum!(c, 101, ys); text!(c, 99, ys - 1, "−")
from_below!(c, 101, ys, "SOCini"); text!(c, 102, ys + 1, "+")
clampw!(c, 115, ys; max="SOCmax", min="SOCmin"); text!(c, 120, ys - 1, "SOC")
# the gates only narrow the window the current limit logic sets
vline!(c, 138, lg.top, yp + 2; dash=2); arrow!(c, 138, yp + 2, :up)
# crosses the Ipcmd wire without joining it
vline!(c, 150, lg.top, yp + 1; dash=2); text!(c, 150, yp - 1, "↑")
text!(c, 136, yp + 3, "further clamps\ndown to 0"; align=:right)
text!(c, 152, yp + 3, "further clamps\ndown to 0")
text!(c, 146, cl.bottom + 2, "Ipmax, Ipmin = −Ipmax"; align=:right)
c
