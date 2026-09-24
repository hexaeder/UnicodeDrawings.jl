# Each example file holds one diagram, nothing else.
load_example(path) = read(path, String)
example(num) = load_example(joinpath(EXDIR, "$num.txt"))
EXDIR = joinpath(@__DIR__, "..", "examples")
EXFILES = filter(endswith(".txt"), readdir(EXDIR; join=true))

# Rendered output drops trailing spaces and trailing empty lines.
function normtext(s)
    ls = rstrip.(split(s, '\n'))
    while !isempty(ls) && isempty(last(ls))
        pop!(ls)
    end
    join(ls, '\n')
end

runscene = UnicodeDrawings.runscene
SCENEDIR = joinpath(@__DIR__, "..", "examples", "scenes")
function checkscene(num; show=true)
    # scenes that start drawing further down render leading empty rows, which blocks don't have
    got = replace(render(runscene(joinpath(SCENEDIR, "$num.jl"))), r"\A\n+" => "")
    want = normtext(example(num))
    if show && got != want
        println("got:"); ruler(got); println("want:"); ruler(want)
    end
    got == want
end

# Cells an imported scene sets one by one because no primitive explained them.
function nfixups(scene)
    ls = split(scene, '\n')
    k = findfirst(==("# cells the primitives above don't reproduce"), ls)
    isnothing(k) ? 0 : count(l -> startswith(l, r"stroke!|mark!|erase!"), ls[k+1:end])
end
