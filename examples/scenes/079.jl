# NetworkDynamics overview: triangles drawn over box edges, `∙` taps on wires, a `+` summing box.
c = Canvas()
xdot = "ẋ"  # x with combining dot, one column wide
edgelabel = "EdgeModel\n$xdot = f(x, φ, p, t)\nΦ = g(x, φ, p, t)"
e1 = box!(c, 4, 6, 21, 5; label=edgelabel, line=:heavy, align=:left, valign=:top)
v = box!(c, 28, 6, 21, 5; label="VertexModel\n$xdot = f(x, Φ, p, t)\nφ = g(x, p, t)",
         line=:double, align=:left, valign=:top)
e2 = box!(c, 52, 6, 21, 5; label=edgelabel, line=:heavy, align=:left, valign=:top)
sum = box!(c, 36, 12; label="+", line=:round)

# potential φ goes up from the vertex and down into both edges
wire!(c, (21, e1.top), (21, 3), (55, 3), (55, e2.top))
vline!(c, v.cx, 2, v.top)
# flow Φ comes out of both edges into the sum, and the sum feeds the vertex
wire!(c, (21, e1.bottom), (21, sum.cy), (sum.left, sum.cy))
wire!(c, (55, e2.bottom), (55, sum.cy), (sum.right, sum.cy))
vline!(c, v.cx, v.bottom, sum.top)
vline!(c, v.cx, sum.bottom, sum.bottom + 1; cap=(:half, :full))
# links to the neighbouring nodes
wire!(c, (3, 4), (7, 4), (7, e1.top)); wire!(c, (7, e1.bottom), (7, 12), (3, 12))
wire!(c, (73, 4), (69, 4), (69, e2.top)); wire!(c, (69, e2.bottom), (69, 12), (73, 12))

for x in (7, 21, 55, 69), y in (e1.top, e1.bottom)
    arrow!(c, x, y, :down; head=:triangle)
end
for y in (2, v.top, v.bottom, sum.bottom)
    arrow!(c, v.cx, y, :up; head=:triangle)
end
arrow!(c, sum.left, sum.cy, :right; head=:triangle); arrow!(c, sum.right, sum.cy, :left; head=:triangle)
for (x, y) in [(21, 3), (55, 3), (v.cx, 5), (v.cx, 11), (21, 13), (55, 13)]
    mark!(c, x, y, "∙")
end
for (x, y) in [(3, 4), (73, 4), (3, 12), (73, 12)]
    mark!(c, x, y, "⋯")
end
arrow!(c, 21, 2, :down); arrow!(c, 55, 2, :down)

text!(c, 19, 1, "δφ_in"); text!(c, 53, 1, "δφ_in")
text!(c, v.cx, 1, "more edges"; align=:center); text!(c, v.cx, 16, "more edges"; align=:center)
text!(c, 40, 4, "potential"); text!(c, 30, 5, "δφ_out →"); text!(c, 41, 5, "φ out")
text!(c, 16, 11, "flow"); text!(c, 23, 11, "Φ out"); text!(c, 31, 11, "δΦ_in →")
text!(c, 50, 11, "flow"); text!(c, 57, 11, "Φ out")
text!(c, 13, 13, "δΦ_out →"); text!(c, 56, 13, "← δΦ_out")
for x in (1, 75)
    text!(c, x, 4, "n\ne\nx\nt"); text!(c, x, 9, "n\no\nd\ne")
end
c
