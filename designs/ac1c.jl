# IEEE AC1C exciter (Fig. 9) with the AC rotating exciter (Fig. 8), without OEL/UEL inputs.

# Wire from `x1` to `x2` on row `y`, arrowhead just before `x2`.
function flow!(c, x1, x2, y)
    wire!(c, (x1, y), (x2, y))
    arrow!(c, x2 - 1, y, :right)
end

c = Canvas()
y = 5                     # forward path
s1, s2 = 10, 17           # summing points

lead = tf!(c, s2 + 5, y, "1 + s T_C", "1 + s T_B")
reg = tf!(c, lead.right + 4, y, "K_A", "1 + s T_A")
lim = box!(c, reg.right + 4, y - 1; label="lim", line=:round)
s3 = lim.right + 5
exc = tf!(c, s3 + 4, y, "1", "s T_E")
tap = exc.right + 3       # V_E is tapped here for V_FE and F_EX
fex = box!(c, tap + 3, y + 3; label="F_EX(K_C I_FD / V_E)", line=:round)
mul = fex.cx
vfelabel = "V_E (K_E + S_E(V_E)) + K_D I_FD"
vfe = box!(c, tap - 3 - (textwidth(vfelabel) + 3), y + 7; label=vfelabel, line=:round)
rate = tf!(c, lead.left + 2, vfe.cy, "s K_F", "1 + s T_F")

# forward path
flow!(c, 1, s1 - 1, y)
flow!(c, s1 + 1, s2 - 1, y)
flow!(c, s2 + 1, lead.left, y)
flow!(c, lead.right, reg.left, y)
flow!(c, reg.right, lim.left, y)
flow!(c, lim.right, s3 - 1, y)
flow!(c, s3 + 1, exc.left, y)
flow!(c, exc.right, mul - 1, y)
wire!(c, (mul + 1, y), (mul + 7, y))

# inputs from above and below the summing points
wire!(c, (s1, y + 3), (s1, y)); arrow!(c, s1, y + 1, :up)
wire!(c, (s2, y - 3), (s2, y)); arrow!(c, s2, y - 1, :down)

# exciter internals: V_E feeds F_EX and V_FE, V_FE goes back to both sums
wire!(c, (tap, y), (tap, vfe.cy), (vfe.right, vfe.cy)); arrow!(c, vfe.right + 1, vfe.cy, :left)
wire!(c, (tap, fex.cy), (fex.left, fex.cy)); arrow!(c, fex.left - 1, fex.cy, :right)
wire!(c, (fex.right + 5, fex.cy), (fex.right, fex.cy)); arrow!(c, fex.right + 1, fex.cy, :left)
wire!(c, (mul, fex.top), (mul, y)); arrow!(c, mul, y + 1, :up)
wire!(c, (vfe.left, vfe.cy), (rate.right, vfe.cy)); arrow!(c, rate.right + 1, vfe.cy, :left)
wire!(c, (s3, vfe.top), (s3, y)); arrow!(c, s3, y + 1, :up)
wire!(c, (rate.left, rate.cy), (s2, rate.cy), (s2, y)); arrow!(c, s2, y + 1, :up)

for x in (s1, s2, s3)
    mark!(c, x - 1, y, "(Σ)")
end
mark!(c, mul - 1, y, "(×)")
mark!(c, tap, y, "●"); mark!(c, tap, fex.cy, "●")

# signal names and signs
text!(c, 1, y - 1, "V_REF")
text!(c, s1 + 1, y + 1, "-"); text!(c, s1, y + 4, "V_C"; align=:center)
text!(c, s2 + 1, y - 1, "+"); text!(c, s2, y - 4, "V_S"; align=:center)
text!(c, s2 + 1, y + 1, "-"); text!(c, s2 - 2, y + 2, "V_F"; align=:right)
text!(c, s3 + 1, y + 1, "-"); text!(c, s3 - 2, y + 3, "V_FE"; align=:right)
text!(c, reg.right - 1, reg.top - 1, "V_Amax"); text!(c, reg.right - 1, reg.bottom + 1, "V_Amin")
text!(c, lim.left, lim.top - 1, "E_FEmax"); text!(c, lim.left, lim.bottom + 1, "E_FEmin")
text!(c, exc.right, exc.top - 1, "V_Emax(I_FD, V_E)"; align=:right); text!(c, exc.right, exc.bottom + 1, "V_Emin"; align=:right)
text!(c, lim.right + 2, y - 1, "E_FE"); text!(c, tap, y - 1, "V_E"; align=:center)
text!(c, mul + 4, y - 1, "E_FD")
text!(c, fex.right + 7, fex.cy, "I_FD")
c
