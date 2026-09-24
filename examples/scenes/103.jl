# WTGWGO_A figure (EPRI 3002027129, Figure 4-26), as implemented: the voltage filter and the
# box with Pref_out through one dip.

c = Canvas()

X = 34                    # left wall of the box
A = X + 14                # plot axis
r = 3                     # top row of the plot axis
L1, L2, L3 = r + 1, r + 5, r + 9   # levels Pref_in, Pwgo2, Pwgo1
ax = r + 11               # time axis
t0 = A + 7
t1 = t0 + 20
t2 = t1 + 4
t3 = t2 + 12
t4 = t3 + 4
te = t4 + 8

sb = box!(c, X, r - 2, te + 7 - X, 18)

# plot axes
wire!(c, (A, r), (A, ax), (te + 1, ax); line=:light, cap=(:full, :full))
for y in (L1, L2, L3); stroke!(c, A, y, '┤'); end
for x in (t0, t1); stroke!(c, x, ax, '┴'); end

# Pref_out through the dip and the recovery path
wire!(c, (A, L1), (t0, L1), (t0, L3), (t1, L3); cap=:full)
wire!(c, (t2, L2), (t3, L2); cap=:full)
wire!(c, (t4, L1), (te, L1); cap=:full)
for k in 1:3
    text!(c, t1 + k, L3 - k, "╱")
    text!(c, t3 + k, L2 - k, "╱")
end

# events below the axis
wire!(c, (t0, ax), (t0, ax + 2), (t0 + 1, ax + 2); line=:light)
wire!(c, (t1, ax), (t1, ax + 2), (t1 + 1, ax + 2); line=:light)

# inputs and output
tf = box!(c, 8, ax + 2 - 2; label="1\n\n1 + s Tfltr", line=:round)
hline!(c, tf.left + 1, tf.right - 1, tf.cy)
wire!(c, (5, tf.cy), (tf.left, tf.cy); cap=(:full, :half))
wire!(c, (tf.right, tf.cy), (X, tf.cy))
wire!(c, (10, L1), (X, L1); cap=(:full, :half))
wire!(c, (sb.right, L2), (sb.right + 4, L2); cap=(:half, :full))

arrow!(c, tf.left - 1, tf.cy, :right)
arrow!(c, X - 1, tf.cy, :right)
arrow!(c, X - 1, L1, :right)
arrow!(c, sb.right + 4, L2, :right)

text!(c, 1, tf.cy, "|Vt⟩")
text!(c, 1, L1, "|Pref_in⟩")
text!(c, sb.right + 5, L2, "|Pref_out⟩")
text!(c, tf.right + 2, tf.cy - 1, "Vt_filt")
text!(c, tf.left + 1, tf.bottom + 1, "s0")

text!(c, A, r - 1, "Pref_out"; align=:center)
text!(c, A - 2, L1, "Pref_in"; align=:right)
text!(c, A - 2, L2, "Pwgo2"; align=:right)
text!(c, A - 2, L3, "Pwgo1"; align=:right)
text!(c, te + 3, ax, "t")
text!(c, t1, L3 - 2, "rpw1"; align=:right)
text!(c, t3, L2 - 2, "rpw2"; align=:right)
text!(c, (t2 + t3) ÷ 2, L2 - 1, "thold"; align=:center)

text!(c, A - 2, ax + 1, "dip"; align=:right)
for (s, a, b) in (("0", A, t0), ("1", t0, t1), ("0", t1, te))
    text!(c, (a + b + 1) ÷ 2, ax + 1, s; align=:center)
end
text!(c, t0 + 3, ax + 2, "Vt_filt < Vwgo")
text!(c, t1 + 3, ax + 2, "Vt_filt > Vwgo + eps")
text!(c, t1 + 3, ax + 3, "t_vdip_end = t")
c
