# Full REGC_C figure (EPRI 3002027129, Figure 4-3), as implemented. The E box and the rotation
# work in the PLL frame.
# Copied from PowerDynamicsLibrary docs/resources/REGC_C/fig4-3_scene.jl. Reproduces the REGC_C
# docstring block (examples/102) up to its empty first row.

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

# `|name⟩──→┤` into the left side of `b` on row y
function tagin!(c, b, y, name; len=3)
    x = b.left - len - textwidth(name) - 2
    text!(c, x, y, "|$name⟩")
    hline!(c, b.left - len, b.left, y; cap=(:full, :half))
    arrow!(c, b.left - 1, y, :right)
end

c = Canvas()
yq, yp = 6, 22                 # wire rows of the two current loops
xs = 36                        # Σ of the active loop, the reactive one sits 4 to the right

#### reactive current loop
text!(c, 1, yq - 1, "Iqcmd")
text!(c, 14, yq - 2, "Iqrmax (Qgen0 > 0)")
text!(c, 16, yq - 1, "/")
text!(c, 14, yq + 1, "/")
text!(c, 18, yq + 1, "s3")
text!(c, 14, yq + 2, "Iqrmin (Qgen0 < 0)"; align=:center)
piq = pi!(c, xs + 10, yq, "Kip", "Kii"; max="Imax", min="−Imax", state="s0")
hline!(c, 1, piq.left, yq)
mark!(c, 26, yq, "(−1)"); arrow!(c, 25, yq, :right)
mark!(c, xs + 3, yq, "(Σ)"); arrow!(c, xs + 2, yq, :right)
arrow!(c, piq.left - 1, yq, :right)

#### active current loop
text!(c, 1, yp - 1, "Ipcmd")
text!(c, 14, yp - 2, "rrpwr")
text!(c, 16, yp - 1, "/")
text!(c, 15, yp + 1, "s4")
pip = pi!(c, xs + 10, yp, "Kip", "Kii"; max="Imax", min="−Imax", state="s1")
hline!(c, 1, pip.left, yp)
mark!(c, 9, yp, "(×)"); arrow!(c, 8, yp, :right)
mark!(c, 21, yp, "(÷)"); arrow!(c, 20, yp, :right)
mark!(c, xs - 1, yp, "(Σ)"); arrow!(c, xs - 2, yp, :right)
arrow!(c, pip.left - 1, yp, :right)

#### source voltage
E = box!(c, piq.right + 19, 12; label="Eq = Vtq + re·Iq + xe·Ip\nEd = Vtd + re·Ip − xe·Iq", align=:left, line=:round)
wire!(c, (piq.right, yq), (E.cx, yq), (E.cx, E.top))
arrow!(c, E.cx, E.top - 1, :down); text!(c, piq.right + 2, yq - 1, "Iq")
wire!(c, (pip.right, yp), (E.cx, yp), (E.cx, E.bottom))
arrow!(c, E.cx, E.bottom + 1, :up); text!(c, pip.right + 2, yp - 1, "Ip")
xn = E.left - 3                # Vt node, feeds the E box and, further down, filter and PLL
text!(c, xn - 6, E.top + 2, "|Vt⟩"); hline!(c, xn - 2, E.left, E.top + 2; cap=(:full, :half))
arrow!(c, E.left - 1, E.top + 2, :right)

# the Te lags
yeq, yed = 10, 17
xv = E.right + 3               # where Eq and Ed turn towards their lag
lq = tf!(c, xv + 4, yeq, "1", "1 + s Te"); text!(c, lq.left + 1, lq.bottom + 1, "s5")
ld = tf!(c, xv + 4, yed, "1", "1 + s Te"); text!(c, ld.left + 1, ld.top - 1, "s6")
wire!(c, (E.right, E.top + 1), (xv, E.top + 1), (xv, yeq), (lq.left, yeq))
wire!(c, (E.right, E.top + 2), (xv, E.top + 2), (xv, yed), (ld.left, yed))
text!(c, E.right + 1, E.top, "Eq"); text!(c, E.right + 1, E.bottom, "Ed")
arrow!(c, lq.left - 1, yeq, :right); arrow!(c, ld.left - 1, yed, :right)

rot = box!(c, lq.right + 6, yeq - 2, 14, yed - yeq + 5; label="·e^{j·s8}", line=:round)
hline!(c, lq.right, rot.left, yeq); arrow!(c, rot.left - 1, yeq, :right)
hline!(c, ld.right, rot.left, yed); arrow!(c, rot.left - 1, yed, :right)
text!(c, lq.right + 1, yeq - 1, "Eq′"); text!(c, ld.right + 1, yed - 1, "Ed′")
# the source voltage E, in network coordinates, behind the source impedance to the terminal
xE = rot.right + 5
zs = box!(c, xE + 5, rot.cy - 1; label="re + j·xe")
xT = zs.right + 5
hline!(c, rot.right, zs.left, rot.cy)
hline!(c, zs.right, xT, rot.cy; cap=(:half, :full))
arrow!(c, xE - 1, rot.cy, :right)
mark!(c, xE, rot.cy, "o"); text!(c, xE, rot.cy + 1, "E"; align=:center)
mark!(c, xT, rot.cy, "o"); text!(c, xT, rot.cy + 1, "terminal"; align=:center)

#### measurement: voltage filter and PLL, current in the PLL frame
yf = 31
fl = tf!(c, 44, yf, "1", "1 + s Tfltr"); text!(c, fl.left + 1, fl.bottom + 1, "s2")
vline!(c, xn, E.top + 2, yf); hline!(c, fl.right, xn, yf)
mark!(c, xn, E.top + 2, "●"); arrow!(c, fl.right + 1, yf, :left)
stroke!(c, xn, yp, '│'; over=true)
# Vdiv, only with RateFlag = 1
wire!(c, (fl.left, yf), (10, yf), (10, yp + 1); dash=2)
wire!(c, (22, yf), (22, yp + 1); dash=2)
mark!(c, 22, yf, "●"); arrow!(c, 10, yp + 1, :up); arrow!(c, 22, yp + 1, :up)
text!(c, fl.left - 5, yf - 1, "Vt_f")

tv = box!(c, xn + 4, yf - 1, 7, 3; label="T⁻¹", line=:round)
hline!(c, xn, tv.left, yf); arrow!(c, tv.left - 1, yf, :right); mark!(c, xn, yf, "●")
pll = pi!(c, tv.right + 7, yf, "Kppll", "Kipll"; max="wmax", min="wmin", state="s7")
hline!(c, tv.right, pll.left, yf); arrow!(c, pll.left - 1, yf, :right); text!(c, tv.right + 2, yf - 1, "Vq")
ig = tf!(c, pll.right + 7, yf, "1", "s")
hline!(c, pll.right, ig.left, yf); arrow!(c, ig.left - 1, yf, :right); text!(c, pll.right + 2, yf - 1, "Δω")
text!(c, ig.right + 2, yf - 1, "s8")

yi = yf + 4
ti = box!(c, fl.right + 3, yi - 1, 11, 3; label="T⁻¹", line=:round)
tagin!(c, ti, yi, "It"; len=4)
wire!(c, (ig.right, yf), (ig.right + 4, yf), (ig.right + 4, yi), (ti.right, yi)); arrow!(c, ti.right + 1, yi, :left)
vline!(c, tv.cx, yi, tv.bottom); mark!(c, tv.cx, yi, "●"); arrow!(c, tv.cx, tv.bottom + 1, :up)
text!(c, tv.cx + 2, yi + 1, "angle")
# measured currents back to the loops
xip, xiq = ti.left + 2, ti.left + 8
wire!(c, (xip, ti.top), (xip, yp + 5), (xs, yp + 5), (xs, yp + 1))
wire!(c, (xiq, ti.top), (xiq, yq + 5), (xs + 4, yq + 5), (xs + 4, yq + 1))
for (x, y) in ((xip, yf), (xiq, yf), (xiq, yp))
    stroke!(c, x, y, '│'; over=true)
end
arrow!(c, xs, yp + 1, :up); text!(c, xs + 1, yp + 1, "−")
arrow!(c, xs + 4, yq + 1, :up); text!(c, xs + 5, yq + 1, "−")
text!(c, xs + 1, yp + 4, "Ip′"); text!(c, xs + 5, yq + 4, "Iq′")
c
