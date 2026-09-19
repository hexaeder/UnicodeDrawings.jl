# DEGOV1 diesel governor: control box, actuator, throttle integrator, droop feedback.
c = Canvas()
R = 5  # main signal row

# summing point with three inputs on the left and the droop feedback from below
sum = box!(c, 10, R - 2, 7, 5; label="Σ", line=:round)
for (y, name, sign) in [(R - 1, "ω_ref", "+"), (R, "ω", "−"), (R + 1, "P_setp", "+")]
    wire!(c, (8, y), (sum.left, y))
    arrow!(c, sum.left - 1, y, :right)
    text!(c, 6, y, name; align=:right)
    text!(c, sum.left + 1, y, sign)
end
text!(c, sum.cx + 1, sum.bottom - 1, "−")

# forward path
cb = box!(c, sum.right + 4, R - 2; label="1 + s T₃\n\n1 + s T₁ + s² T₁ T₂", line=:round)
act = box!(c, cb.right + 4, R - 2; label="K (1 + s T₄)\n\n(1 + s T₅)(1 + s T₆)", line=:round)
int = box!(c, act.right + 4, R - 2; label="1\n\ns", line=:round)
mul = box!(c, int.right + 6, R - 1, 3, 3; label="×", line=:round)
for b in (cb, act, int)
    hline!(c, b.left + 1, b.right - 1, b.cy)
end
wire!(c, (sum.right, R), (cb.left, R))
wire!(c, (cb.right, R), (act.left, R))
wire!(c, (act.right, R), (int.left, R))
wire!(c, (int.right, R), (mul.left, R))
wire!(c, (mul.right, R), (mul.right + 7, R))
wire!(c, (mul.cx, mul.bottom + 2), (mul.cx, mul.bottom))
jx = int.right + 3
for b in (cb, act, int, mul)
    arrow!(c, b.left - 1, R, :right)
end
arrow!(c, mul.cx, mul.bottom + 1, :up)
text!(c, mul.cx, mul.bottom + 3, "ω")
text!(c, mul.right + 2, R - 1, "P_turb")
text!(c, cb.cx, cb.bottom + 1, "control box"; align=:center)
text!(c, act.cx, act.bottom + 1, "actuator"; align=:center)

# non-windup limits on the throttle integrator
text!(c, int.right - 2, int.top - 2, "__ Tmax")
text!(c, int.right - 3, int.top - 1, "/")
text!(c, int.left + 3, int.bottom + 1, "Tmin __/"; align=:right)

# droop feedback: DroopControl selects throttle (0) or measured power (1)
mux = box!(c, 50, int.bottom + 2, 5, 7)
text!(c, mux.right - 1, mux.top + 1, "0")
text!(c, mux.right - 1, mux.bottom - 1, "1")
text!(c, mux.right, mux.bottom + 1, "DroopControl"; align=:right)
lag = box!(c, mux.right + 4, mux.bottom - 3; label="1\n\n1 + s Tₑ", line=:round)
hline!(c, lag.left + 1, lag.right - 1, lag.cy)
droop = box!(c, 30, mux.cy - 1; label="Droop", line=:round)

wire!(c, (jx, R), (jx, mux.top + 1), (mux.right, mux.top + 1))
wire!(c, (lag.right + 6, lag.cy), (lag.right, lag.cy))
wire!(c, (lag.left, lag.cy), (mux.right, lag.cy))
wire!(c, (mux.left, mux.cy), (droop.right, mux.cy))
wire!(c, (droop.left, mux.cy), (sum.cx, mux.cy), (sum.cx, sum.bottom))
mark!(c, jx, R, "●")
arrow!(c, mux.right + 1, mux.top + 1, :left)
arrow!(c, mux.right + 1, lag.cy, :left)
arrow!(c, lag.right + 1, lag.cy, :left)
arrow!(c, droop.right + 1, mux.cy, :left)
arrow!(c, sum.cx, sum.bottom + 1, :up)
text!(c, lag.right + 8, lag.cy, "P_gen")
text!(c, jx - 2, int.bottom + 2, "throttle"; align=:right)
c
