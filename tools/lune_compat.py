#!/usr/bin/env python3
"""Run the Lune-only regression suites on the local plain Luau CLI (Lune is not installed here).

Provides just the Lune APIs those suites use: @lune/fs (a read-only snapshot of src/, tools/ and
assets/*.md taken now), @lune/luau (loadstring + setfenv with global fallback, as Lune's injected
globals), @lune/process, @lune/task (a virtual-clock scheduler) and @lune/roblox (the datatype and
Instance shim in tools/roblox_shim.luau). Each suite is generated beside itself in tools/ (so its ./ requires resolve) and removed afterwards.
This is emulation: a pass means the suite's own checks hold on the shim, not on Lune's engine; a
suite that needs engine behaviour the shim lacks is reported as SHIM GAP, never as passed.

    python3 tools/lune_compat.py tools/test_recovery_lifecycle.luau [...]
    python3 tools/lune_compat.py --all
"""
from pathlib import Path
import os
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
LUAU = ROOT / "work/bin/luau/luau"


def long_string(text):
    level = 0
    # A text ending in "]" + level "=" would merge with the closer and end the string early.
    while f"]{'=' * level}]" in text or text.endswith("]" + "=" * level):
        level += 1
    eq = "=" * level
    return f"[{eq}[\n{text}]{eq}]"


def snapshot():
    files, dirs = {}, {}
    roots = [ROOT / "src", ROOT / "tools"]
    for root in roots:
        for path in sorted(root.rglob("*")):
            rel = path.relative_to(ROOT).as_posix()
            if "__pycache__" in rel or path.name.startswith("_lune_"):
                continue
            parent = path.parent.relative_to(ROOT).as_posix()
            dirs.setdefault(parent, []).append(path.name)
            if path.is_dir():
                dirs.setdefault(rel, [])
            elif path.suffix in (".luau", ".lua", ".json", ".md", ".py", ".sh"):
                files[rel] = path.read_text()
    for path in sorted((ROOT / "assets").glob("*.md")):
        files[path.relative_to(ROOT).as_posix()] = path.read_text()
    for rel in ("default.project.json",):
        files[rel] = (ROOT / rel).read_text()
    lines = ["local __files = {"]
    for rel, text in files.items():
        lines.append(f"[{rel!r}] = {long_string(text)},")
    lines.append("}\nlocal __dirs = {")
    for rel, names in dirs.items():
        lines.append(f"[{rel!r}] = {{{', '.join(repr(n) for n in names)}}},")
    lines.append("}")
    return "\n".join(lines)


PRELUDE = r'''
local function __norm(p)
	p = string.gsub(p, "\\", "/")
	p = string.gsub(p, "^%./", "")
	p = string.gsub(p, "/$", "")
	return p
end
local __fs = {}
function __fs.readFile(p) local f = __files[__norm(p)]; if f == nil then error("lune_compat: no file " .. p, 2) end; return f end
function __fs.readDir(p) local d = __dirs[__norm(p)]; if d == nil then error("lune_compat: no dir " .. p, 2) end; return table.clone(d) end
function __fs.isDir(p) return __dirs[__norm(p)] ~= nil end
function __fs.isFile(p) return __files[__norm(p)] ~= nil end
function __fs.writeFile() error("lune_compat: writeFile is not emulated", 2) end
local __G = getfenv(1)
local __luau = {}
function __luau.load(source, options)
	local name = options and options.debugName or "chunk"
	local fn, problem = loadstring(source, "=" .. name)
	if not fn then error(problem, 2) end
	local env = options and options.environment
	if env then
		if getmetatable(env) == nil then setmetatable(env, { __index = __G }) end
		setfenv(fn, env)
	end
	return fn
end
local __process = { args = {}, env = {}, os = "macos", cwd = "" }
function __process.exit(code) if code ~= 0 then error("process.exit(" .. tostring(code) .. ")", 2) end end
-- Virtual clock: task.wait on the main thread advances time and runs due threads.
local __now, __queue = 0, {}
local __managed = setmetatable({}, { __mode = "k" }) -- threads the scheduler owns (the main chunk is not one)
local function __run(untilTime)
	while true do
		table.sort(__queue, function(a, b) return a.At < b.At end)
		local item = __queue[1]
		if not item or item.At > untilTime then break end
		table.remove(__queue, 1)
		__now = math.max(__now, item.At)
		local ok, err = coroutine.resume(item.Co, table.unpack(item.Args or {}))
		if not ok then error(err, 0) end
	end
	__now = math.max(__now, untilTime)
end
local __task = {}
function __task.spawn(f, ...)
	local co = if type(f) == "thread" then f else coroutine.create(f)
	__managed[co] = true
	local ok, err = coroutine.resume(co, ...)
	if not ok then error(err, 0) end
	return co
end
function __task.defer(f, ...) local co = if type(f) == "thread" then f else coroutine.create(f); __managed[co] = true; table.insert(__queue, { Co = co, At = __now, Args = { ... } }); return co end
function __task.delay(t, f, ...) local co = coroutine.create(f); __managed[co] = true; table.insert(__queue, { Co = co, At = __now + (t or 0), Args = { ... } }); return co end
function __task.wait(t)
	t = t or 0
	if __managed[coroutine.running()] then
		table.insert(__queue, { Co = coroutine.running(), At = __now + t })
		coroutine.yield()
	else
		__run(__now + t)
	end
	return t
end
function __task.cancel(co) for i, item in __queue do if item.Co == co then table.remove(__queue, i); return end end end
local __roblox = require("./roblox_shim")
-- typeof sees the shim's datatypes as Lune's (metatable __type), like Roblox userdata.
local __rawtypeof = typeof
typeof = function(v)
	if type(v) == "table" then
		local mt = getmetatable(v)
		if type(mt) == "table" and rawget(mt, "__type") then return mt.__type end
	end
	return __rawtypeof(v)
end
local __lune = { fs = __fs, luau = __luau, process = __process, task = __task, roblox = __roblox }
'''


def rewrite(source, folder, seen):
    """Lune requires become the emulated modules; ./helpers that use Lune are inlined (rewritten too)."""
    source = re.sub(r'require\("@lune/(\w+)"\)', lambda m: f"__lune[{m.group(1)!r}]", source)
    source = re.sub(r"^--!strict", "--!nonstrict", source, flags=re.M)
    source = re.sub(r"^export type", "type", source, flags=re.M)

    def inline(m):
        helper = (folder / (m.group(1) + ".luau")).resolve()
        text = helper.read_text() if helper.exists() else ""
        if "@lune/" not in text:
            return m.group(0)
        if helper not in seen:
            seen[helper] = f"__helper_{len(seen)}"
            seen[helper] = (seen[helper], rewrite(text, helper.parent, seen))
        return f"{seen[helper][0]}()"
    return re.sub(r'require\("(\.{1,2}/[\w/]+)"\)', inline, source)


def generate(test):
    seen = {}
    body = rewrite(test.read_text(), test.parent, seen)
    helpers = []
    for name, text in seen.values():
        helpers.append(f"local {name}\ndo\n local cache\n {name} = function()\n  if cache == nil then cache = (function()\n{text}\nend)() end\n  return cache\n end\nend\n")
    return "--!nonstrict\n" + snapshot() + PRELUDE + "\n".join(helpers) + "\ndo\n" + body + "\nend\n"


def run(test):
    out = ROOT / "tools" / f"_lune_{test.stem}.generated.luau"  # beside the suite: its ./ requires resolve
    out.write_text(generate(test))
    try:
        result = subprocess.run([str(LUAU), str(out)], cwd=ROOT / "tools", capture_output=True, text=True, timeout=300)
    finally:
        if not os.environ.get("LUNE_COMPAT_KEEP"):
            out.unlink(missing_ok=True)
    return result


def main(argv):
    tests = sorted((ROOT / "tools").glob("test_*.luau")) if argv == ["--all"] else [Path(a).resolve() for a in argv]
    tests = [t for t in tests if "@lune/" in t.read_text()]
    failed = 0
    for test in tests:
        result = run(test)
        tail = (result.stdout.strip().splitlines() or [""])[-1]
        if os.environ.get("LUNE_COMPAT_VERBOSE"):
            print(result.stdout)
        if result.returncode == 0:
            print(f"PASS     {test.name}: {tail}")
        else:
            failed += 1
            print(f"FAIL     {test.name}:\n{result.stdout[-1500:]}{result.stderr[-1500:]}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
