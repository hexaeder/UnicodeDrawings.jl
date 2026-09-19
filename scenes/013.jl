# The PT1 block of 011 as a reusable function, placed with limiter annotations around it.
function pt1!(c, x, y)
    tf = box!(c, x + 4, y; label="K\n\n1 + s T", line=:round)
    hline!(c, tf.left + 1, tf.right - 1, tf.cy)
    wire!(c, (x, tf.cy), (tf.left, tf.cy))
    wire!(c, (tf.right, tf.cy), (tf.right + 5, tf.cy))
    text!(c, tf.left - 2, tf.cy - 1, "in"; align=:right)
    text!(c, tf.right + 2, tf.cy - 1, "out")
    tf
end

c = Canvas()
tf = pt1!(c, 3, 3)
text!(c, tf.right - 2, tf.top - 2, "__ outMax")
text!(c, tf.right - 3, tf.top - 1, "/")
text!(c, 1, tf.bottom + 1, "outMin __/")
c
