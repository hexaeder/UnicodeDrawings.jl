# Code annotation: underbraces with a leader down to their label.
c = Canvas()
text!(c, 1, 1, "VIndex(  1,    :symbolic_swing₊ω)\nVIndex(:swing, :symbolic_swing₊θ)")
hline!(c, 8, 13, 3); vline!(c, 10, 3, 4)
hline!(c, 16, 32, 3); vline!(c, 24, 3, 6)
text!(c, 1, 5, "Index/name of vertex")
text!(c, 10, 7, "Name of parameter/state")
c
