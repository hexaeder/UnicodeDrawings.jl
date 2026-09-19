import os, re, sys, hashlib

ROOTS = sys.argv[2:]
OUT = sys.argv[1]
SKIP = {"build", "build_draft", "generated", ".git"}
# box drawing, block elements, arrows, geometric arrow heads
DIAG = re.compile(r"[─-╿▀-▟←-⇿▲-◄⟶⟵]")

RULE = re.compile(r"^\s*#*\s*─+ .* ─+\s*$")
def isdiag(l):
    return bool(DIAG.search(l)) and not RULE.match(l) and "print" not in l

def blocks(lines):
    # fenced blocks first: take the whole fence if two of its lines are diagram lines
    fenced, i = set(), 0
    while i < len(lines):
        if lines[i].lstrip().startswith("```"):
            j = i + 1
            while j < len(lines) and not lines[j].lstrip().startswith("```"):
                j += 1
            if sum(isdiag(l) for l in lines[i+1:j]) >= 2:
                fenced.update(range(i, j + 1))
                yield i, min(j, len(lines) - 1)
            i = j + 1
        else:
            i += 1
    hits = [i for i, l in enumerate(lines) if isdiag(l) and i not in fenced]
    groups = []
    for i in hits:
        if groups and i - groups[-1][1] <= 2:
            groups[-1][1] = i
        else:
            groups.append([i, i])
    for a, b in groups:
        # ignore single-line hits (arrows in prose) unless they are dense
        if sum(isdiag(l) for l in lines[a:b+1]) < 3:
            continue
        a2, b2 = a, b
        while a2 > 0 and lines[a2 - 1].strip() and a - a2 < 2:
            a2 -= 1
        while b2 + 1 < len(lines) and lines[b2 + 1].strip() and b2 - b < 2:
            b2 += 1
        yield a2, b2

os.makedirs(OUT, exist_ok=True)
seen = set()
n = 0
for root in ROOTS:
    for dp, dns, fns in os.walk(root):
        dns[:] = [d for d in dns if d not in SKIP]
        for fn in sorted(fns):
            if not fn.endswith((".jl", ".md")):
                continue
            p = os.path.join(dp, fn)
            lines = open(p, encoding="utf-8", errors="replace").read().split("\n")
            for a, b in blocks(lines):
                body = "\n".join(lines[a:b + 1])
                key = hashlib.md5(re.sub(r"\s+", "", body).encode()).hexdigest()
                if key in seen:
                    continue
                seen.add(key)
                n += 1
                rel = os.path.relpath(p, os.path.expanduser("~/.julia/dev"))
                name = f"{n:03d}_" + re.sub(r"[^A-Za-z0-9]+", "_", rel.rsplit(".", 1)[0]).strip("_") + f"_L{a+1}.txt"
                with open(os.path.join(OUT, name), "w") as f:
                    f.write(f"# source: {rel}:{a+1}-{b+1}\n")
                    f.write(body.rstrip() + "\n")
print(n)
