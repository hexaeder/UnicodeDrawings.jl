# The diagram inside an example file: the fenced block after the `# source:` header.
function load_example(path)
    lines = readlines(path)
    i = findfirst(startswith("```"), lines)
    isnothing(i) && return join(lines[2:end], '\n')
    j = findnext(startswith("```"), lines, i + 1)
    join(lines[i+1:j-1], '\n')
end
example(num) = load_example(only(filter(startswith(num), readdir(EXDIR; join=false))) |> f -> joinpath(EXDIR, f))
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
SCENEDIR = joinpath(@__DIR__, "..", "scenes")
function checkscene(num; show=true)
    got = render(runscene(joinpath(SCENEDIR, "$num.jl")))
    want = normtext(example(num))
    if show && got != want
        println("got:"); ruler(got); println("want:"); ruler(want)
    end
    got == want
end
