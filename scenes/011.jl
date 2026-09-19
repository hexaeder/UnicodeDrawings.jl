# PT1 transfer-function block: in/out wires join the box edges, the fraction bar floats inside.
c = Canvas()
tf = box!(c, 5, 1; label="K\n\n1 + s T", line=:round)
hline!(c, tf.left + 1, tf.right - 1, tf.cy)
wire!(c, (1, tf.cy), (tf.left, tf.cy))
wire!(c, (tf.right, tf.cy), (tf.right + 5, tf.cy))
text!(c, tf.left - 2, tf.cy - 1, "in"; align=:right)
text!(c, tf.right + 2, tf.cy - 1, "out")
c
