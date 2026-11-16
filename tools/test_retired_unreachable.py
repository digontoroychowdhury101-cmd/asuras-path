#!/usr/bin/env python3
"""C3 ruling 4: retired builder source may stay only if none of it is mapped or reachable at runtime.

Supersedes: nothing (searched outputs/claude-open-world-2026-11-14 and tools/test_retired*; the one-off greps in
workers/19a-registry-fit.md and workers/10g-boss-fixes.md are replaced by this repeatable check).
Linked from LEDGER.md: not yet; named in CONTINUATION.md:291 and workers/22d-reachability.md, lead adds the LEDGER row.
Why new: no existing test builds a require graph from the mapped runtime roots.
Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

Method (stdlib only): default.project.json gives every mapped module (instance path -> src file). Comments are stripped,
require(...) calls are parsed as instance chains / relative strings, and the leaf name is resolved against mapped modules.
A file with a non-literal require gets edges to every module whose name appears as a string literal in it (conservative).
Over-approximation can only hide an unreachable candidate, never hide a retired module that is reachable.
"""
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Retired builders: neither mapped nor reachable. MonasteryKit is live (lobby/RegionDecor) and must NOT be listed.
RETIRED = ["MonasteryService", "CampaignWorld", "CampaignTerrain", "CampaignBounds", "BambooDressing",
           "PagodaDressing", "CitadelDressing", "MonasteryGrounds", "MonasteryTerrain", "MonasteryAtmosphere",
           "MonasteryBounds", "BambooEcology",
           # second batch (RG 22d): reachable only through the retired builders above
           "BambooFoundry", "ColosseumDressing", "CryptDressing", "MonasteryDressing", "MonasteryHalls",
           "MonasteryLandmarks", "MonasteryPockets", "MonasteryRuins", "MonasterySecrets", "MonasterySurvey",
           "MonasteryRidgeProfile"]
# Orphans outside this task's retirement scope; stay mapped and are listed for the creator.
KNOWN_ORPHANS = ["SolarForms", "PresentationAudit"]
LIVE_MUST_STAY = ["MonasteryKit"]


def strip_comments(s):
    """Remove Luau comments, keep string literals."""
    s = re.sub(r"\(\s*require\s*::\s*\w+\s*\)", "require", s)  # (require :: any)(...) is still a require
    out, i, n = [], 0, len(s)
    while i < n:
        c = s[i]
        if s.startswith("--", i):
            m = re.match(r"--\[(=*)\[", s[i:])
            if m:
                end = s.find("]" + m.group(1) + "]", i)
                end = n if end < 0 else end + len(m.group(1)) + 2
                out.append("\n" * s.count("\n", i, end))
                i = end
            else:
                j = s.find("\n", i)
                i = n if j < 0 else j
        elif c in "\"'`":
            j = i + 1
            while j < n and s[j] != c and s[j] != "\n":
                j += 2 if s[j] == "\\" else 1
            out.append(s[i:j + 1])
            i = j + 1
        else:
            out.append(c)
            i += 1
    return "".join(out)


def require_args(code):
    """Yield (offset, raw argument text) for each require( ... ) call."""
    for m in re.finditer(r"(?<![.:\w])require\s*\(", code):
        i, depth, q = m.end(), 1, None
        while i < len(code) and depth:
            ch = code[i]
            if q:
                if ch == "\\":
                    i += 1
                elif ch == q:
                    q = None
            elif ch in "\"'`":
                q = ch
            elif ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
            i += 1
        yield m.start(), code[m.end():i - 1]


def parse_chain(arg):
    """-> list of segment names (strings) or None when dynamic."""
    a = re.sub(r"\(\s*(\w+)\s*::\s*\w+\s*\)", r"\1", arg.strip())
    a = re.sub(r"\s*::\s*[\w.?]+", "", a).strip()
    m = re.match(r"[A-Za-z_]\w*", a)
    if not m or m.group(0) in ("if", "function"):
        return None
    segs, pos = [m.group(0)], m.end()
    seg = re.compile(r"\s*(?:\.([A-Za-z_]\w*)|:([A-Za-z_]\w*)\(([^()]*)\)|\[[^\]]*\])")
    while pos < len(a):
        s = seg.match(a, pos)
        if not s:
            return None
        pos = s.end()
        if s.group(1):
            segs.append(s.group(1))
        elif s.group(2):
            first = s.group(3).split(",")[0].strip()
            lit = re.fullmatch(r"[\"']([\w]+)[\"']", first)
            if s.group(2) in ("WaitForChild", "FindFirstChild") and lit:
                segs.append(lit.group(1))
            elif s.group(2) == "GetService":
                segs.append("#service")
            else:
                return None
        else:
            return None
    return segs


def load_project():
    tree = json.loads((ROOT / "default.project.json").read_text(encoding="utf-8"))["tree"]
    mapped = {}  # instance path tuple -> src rel path

    def walk(node, path):
        for k, v in node.items():
            if k.startswith("$") or not isinstance(v, dict):
                continue
            p = path + (k,)
            f = v.get("$path")
            if isinstance(f, str):
                mapped[p] = f
            walk(v, p)
    walk(tree, ())
    return {p: f for p, f in mapped.items() if f.endswith(".luau")}, tree


def main():
    mapped, _ = load_project()
    by_file = {f: p for p, f in mapped.items()}
    by_name = defaultdict(list)
    for p, f in mapped.items():
        by_name[p[-1]].append(f)
    src_files = sorted(str(p.relative_to(ROOT)).replace("\\", "/") for p in (ROOT / "src").rglob("*.luau"))
    stem = lambda f: Path(f).name.split(".")[0]
    by_stem = defaultdict(list)
    for f in src_files:
        by_stem[stem(f)].append(f)
    roots = [f for f in mapped.values() if re.search(r"\.(server|client)\.luau$", f)]

    edges, in_edges = defaultdict(set), defaultdict(set)
    dynamic, broken, strings = {}, [], {}
    for f in src_files:
        code = strip_comments((ROOT / f).read_text(encoding="utf-8"))
        strings[f] = set(re.findall(r"[\"'](\w+)[\"']", code))
        mp = by_file.get(f)
        for off, arg in require_args(code):
            line = code.count("\n", 0, off) + 1
            lit = re.fullmatch(r"\s*[\"']([^\"']+)[\"']\s*", arg)
            if lit:
                if lit.group(1).startswith("@"):
                    continue
                tgt = (ROOT / f).parent / (lit.group(1) + ".luau")
                tgt = str(Path(*tgt.resolve().relative_to(ROOT).parts)).replace("\\", "/") if tgt.resolve().is_relative_to(ROOT) else None
                if tgt:
                    edges[f].add(tgt); in_edges[tgt].add(f)
                continue
            segs = parse_chain(arg)
            if segs is None or segs[-1] == "#service" or segs[-1][0].islower() and len(segs) == 1 and segs[-1] not in by_name:
                dynamic.setdefault(f, []).append((line, arg.strip()))
                continue
            leaf = segs[-1]
            cands = by_name.get(leaf) or by_stem.get(leaf) or []
            if len(cands) > 1:
                prev = segs[-2].lower() if len(segs) > 1 else ""
                if prev == "parent":
                    same = [c for c in cands if Path(c).parent == Path(f).parent or (mp and by_file.get(c) and by_file[c][:-1] == mp[:-1])]
                    cands = same or cands
                else:
                    hit = [c for c in cands if by_file.get(c) and by_file[c][-2].lower() == prev]
                    cands = hit or cands
            if not cands:
                dynamic.setdefault(f, []).append((line, arg.strip() + "   [unresolved name: no src module '%s']" % leaf))
                continue
            for c in cands:
                edges[f].add(c); in_edges[c].add(f)
    # dynamic files: edges to every module named by a string literal in the file
    dyn_targets = {}
    for f in dynamic:
        t = sorted({c for n in strings[f] for c in by_name.get(n, [])} - {f})
        dyn_targets[f] = t
        for c in t:
            edges[f].add(c); in_edges[c].add(f)

    mapped_files = set(mapped.values())
    reach, stack = set(), list(roots)
    while stack:
        f = stack.pop()
        if f in reach:
            continue
        reach.add(f)
        for c in edges[f]:
            if c in mapped_files:  # an unmapped file does not exist at runtime, so nothing flows through it
                stack.append(c)
    unreachable = sorted(mapped_files - reach)
    broken = sorted((f, c) for f in reach for c in edges[f] if c not in mapped_files)

    print("roots:", ", ".join(roots))
    print("mapped modules: %d, reachable: %d, mapped-but-unreachable: %d" % (len(mapped_files), len(reach), len(unreachable)))
    print("\nMAPPED BUT UNREACHABLE (candidates to unmap):")
    for f in unreachable:
        users = sorted(in_edges[f])
        print("  %-28s %s | required by: %s" % (mapped_inst(by_file, f), f, ", ".join(users) if users else "nobody (orphan)"))
    print("\nDYNAMIC REQUIRES (manual review; edges added for literal names in the file):")
    for f, items in dynamic.items():
        for line, arg in items:
            print("  %s:%d require(%s)" % (f, line, arg))
        print("    -> conservative targets: %s" % (", ".join(Path(t).stem for t in dyn_targets[f]) or "none"))
    print("\nREACHABLE BUT UNMAPPED (would fail at runtime unless guarded):")
    for f, c in broken:
        print("  %s -> %s" % (f, c))

    fails = []
    mapped_names = {p[-1] for p in mapped} | {stem(f) for f in mapped_files}
    for r in RETIRED:
        if r in mapped_names:
            fails.append("%s is still mapped" % r)
        refs = sorted(f for f in reach if r in strings[f])
        if refs:
            fails.append("%s named as a string literal in runtime-reachable %s" % (r, refs))
        for f in reach:
            for c in edges[f]:
                if stem(c) == r:
                    fails.append("%s required from reachable %s" % (r, f))
    for k in LIVE_MUST_STAY:
        if not any(stem(f) == k and f in reach for f in mapped_files):
            fails.append("%s must stay mapped and reachable" % k)

    print("\nRETIRED on disk (creator-facing, not mapped):")
    for r in RETIRED:
        found = [p for p in (ROOT / "src/server/Services" / (r + ".luau"), ROOT / "src/shared" / (r + ".luau")) if p.exists()]
        print("  %s %s" % (found[0].relative_to(ROOT).as_posix() if found else r, "(present)" if found else "(absent)"))
    print("\nTESTS/TOOLS that mention retired modules (they load src directly; informational):")
    for p in sorted((ROOT / "tools").glob("*")):
        if p.suffix not in (".luau", ".py") or p.name == Path(__file__).name:
            continue
        txt = p.read_text(encoding="utf-8", errors="ignore")
        txt = strip_comments(txt) if p.suffix == ".luau" else txt
        hits = [r for r in RETIRED if re.search(r"\b%s\b" % r, txt)]
        if hits:
            print("  tools/%s: %s" % (p.name, ", ".join(hits)))

    for m in fails:
        print("FAIL:", m)
    print("\nretired unreachable: %s" % ("FAILED" if fails else "passed (%d retired names, none mapped or reachable)" % len(RETIRED)))
    return 1 if fails else 0


def mapped_inst(by_file, f):
    p = by_file.get(f)
    return p[-1] if p else "?"


if __name__ == "__main__":
    sys.exit(main())
