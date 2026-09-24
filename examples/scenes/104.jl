# IEEE AC1C exciter (Fig. 9) with the AC rotating exciter (Fig. 8), without OEL/UEL inputs.

c = Canvas()
y = 5                     # forward path
s1, s2 = 8, 14            # summing points

lead = tf!(c, s2 + 4, y, "1 + s T_C", "1 + s T_B")
reg = tf!(c, lead.right + 3, y, "K_A", "1 + s T_A")
lim = box!(c, reg.right + 3, y - 1; label="lim", line=:round)
s3 = lim.right + 5
exc = tf!(c, s3 + 4, y, "1", "s T_E")
tap = exc.right + 2       # V_E is tapped here for V_FE and F_EX
fex = box!(c, tap + 2, y + 3; label="F_EX(K_C I_FD/V_E)", line=:round)
mul = fex.cx
vfelabel = "V_E (K_E + S_E(V_E)) + K_D I_FD"
vfe = box!(c, tap - 3 - (textwidth(vfelabel) + 3), y + 7; label=vfelabel, line=:round)
rate = tf!(c, lead.left + 2, vfe.cy, "s K_F", "1 + s T_F")

# forward path
hline!(c, 1, s1 - 1, y; arrow=-2)
hline!(c, s1 + 1, s2 - 1, y; arrow=-2)
hline!(c, s2 + 1, lead.left, y; arrow=-2)
hline!(c, lead.right, reg.left, y; arrow=-2)
hline!(c, reg.right, lim.left, y; arrow=-2)
hline!(c, lim.right, s3 - 1, y; arrow=-2)
hline!(c, s3 + 1, exc.left, y; arrow=-2)
hline!(c, exc.right, mul - 1, y; arrow=-2)
wire!(c, (mul + 1, y), (mul + 7, y))

# inputs from above and below the summing points
wire!(c, (s1, y + 3), (s1, y)); arrow!(c, s1, y + 1, :up)
wire!(c, (s2, y - 3), (s2, y)); arrow!(c, s2, y - 1, :down)

# exciter internals: V_E feeds F_EX and V_FE, V_FE goes back to both sums
wire!(c, (tap, y), (tap, vfe.cy), (vfe.right, vfe.cy)); arrow!(c, vfe.right + 1, vfe.cy, :left)
wire!(c, (tap, fex.cy), (fex.left, fex.cy)); arrow!(c, fex.left - 1, fex.cy, :right)
wire!(c, (fex.cx, fex.bottom + 2), (fex.cx, fex.bottom)); arrow!(c, fex.cx, fex.bottom + 1, :up)
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
text!(c, lim.right + 2, y - 1, "E_FE"); text!(c, tap + 1, y - 1, "V_E")
text!(c, mul + 4, y - 1, "E_FD")
text!(c, fex.cx, fex.bottom + 3, "I_FD"; align=:center)
c
