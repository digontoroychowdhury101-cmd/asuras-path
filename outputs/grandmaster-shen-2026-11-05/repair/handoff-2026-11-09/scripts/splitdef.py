import sys, os
src, outdir = sys.argv[1], sys.argv[2]
os.makedirs(outdir, exist_ok=True)
lines = open(src).read().split("\n")
k = next(i for i, l in enumerate(lines) if l.startswith("local def = "))
open(os.path.join(outdir, "def.luau"), "w").write("return " + lines[k][len("local def = "):] + "\n")
lines[k] = 'local def = require("./def")'
open(os.path.join(outdir, "run.luau"), "w").write("\n".join(lines))
