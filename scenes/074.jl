# Machine with AVR and governor: heavy outer boxes, light wires crossing their walls as `╂`.
c = Canvas()
m = box!(c, 6, 5, 11, 5; label="Machine", line=:heavy)
avr = box!(c, 22, 2, 26, 6; label="AVR", line=:heavy, align=:left, valign=:top, pad=0)
gov = box!(c, 22, 8, 26, 6; label="Gov", line=:heavy, align=:left, valign=:top)

# AVR chain, right to left: measured voltage → Lag → (-) → PI → Lag → Efd
lag1 = box!(c, 41, 3; label="Lag", line=:round, pad=0)
pi = box!(c, 30, 4; label="PI", line=:round)
lag2 = box!(c, 24, 4; label="Lag", line=:round, pad=0)
wire!(c, (m.cx + 3, m.top), (m.cx + 3, 1), (49, 1), (49, lag1.cy), (lag1.right, lag1.cy))
wire!(c, (lag1.left, lag1.cy), (38, lag1.cy), (38, 6), (41, 6))
wire!(c, (37, pi.cy), (pi.right, pi.cy))
wire!(c, (pi.left, pi.cy), (lag2.right, lag2.cy))
wire!(c, (lag2.left, lag2.cy), (19, lag2.cy), (19, 6), (m.right, 6))
mark!(c, 37, pi.cy, "(-)")
arrow!(c, m.cx + 3, 4, :up)
for (x, y) in [(46, 4), (40, 4), (40, 6), (36, 5), (29, 5), (23, 5), (17, 6)]
    arrow!(c, x, y, :left)
end

# Governor: Pref → Droop → Lag → machine, with the speed fed back around the bottom
droop = box!(c, 32, 9; label="Droop\nR", line=:round, pad=0)
lag3 = box!(c, 24, 10; label="Lag", line=:round, pad=0)
wire!(c, (41, 10), (droop.right, 10))
wire!(c, (droop.left, 11), (lag3.right, 11))
wire!(c, (lag3.left, 11), (19, 11), (19, 8), (m.right, 8))
wire!(c, (droop.right, 11), (49, 11), (49, 14), (m.cx + 3, 14), (m.cx + 3, m.bottom))
arrow!(c, m.cx + 3, 10, :down)
for (x, y) in [(40, 10), (40, 11), (30, 11), (23, 11), (17, 8)]
    arrow!(c, x, y, :left)
end

wire!(c, (2, m.cy), (m.left, m.cy)); mark!(c, 2, m.cy, "o")
text!(c, 1, 6, "(t)")
text!(c, 8, 3, "Vmeas"); text!(c, 8, 11, "ωmeas"); text!(c, 18, 4, "Efd")
text!(c, 42, 6, "Vref"); text!(c, 42, 10, "Pref")
c
