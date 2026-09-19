# One-line grid sketch: heavy busbars, light branches joining them as `┯ ┷ ┿`.
c = Canvas()
hline!(c, 6, 12, 2; line=:heavy); text!(c, 5, 2, "2")
hline!(c, 2, 8, 4; line=:heavy); text!(c, 1, 4, "1")
hline!(c, 15, 19, 4; line=:heavy); text!(c, 20, 4, "4")
hline!(c, 6, 13, 6; line=:heavy); text!(c, 14, 6, "3")
vline!(c, 7, 2, 6)
vline!(c, 11, 2, 6)
wire!(c, (12, 6), (12, 5), (17, 5), (17, 3))
vline!(c, 9, 1, 2); mark!(c, 8, 1, "(~)")
vline!(c, 3, 4, 5); mark!(c, 2, 5, "(~)")
vline!(c, 9, 6, 7); mark!(c, 7, 7, "(GFM)")
mark!(c, 15, 3, "(GFL)")
c
