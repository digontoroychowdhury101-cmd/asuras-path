# hoist cyclone's chest_frame to build level (corrupt flag), for the transform's roar as well
p = "' + ROOT + '/tools/animation/opening_cast/shen_clips.py"
s = open(p).read()
old_start = s.index("        def chest_frame(k):\n")
old_end = s.index("            return ut[:3, :3], (ut @ np.append(rg.JOINT[\"UpperTorso\"], 1))[:3]\n", old_start) + len("            return ut[:3, :3], (ut @ np.append(rg.JOINT[\"UpperTorso\"], 1))[:3]\n")
s = s[:old_start] + s[old_end:]
anchor = "    def melee(name, keys, notes, feet_free=(), **kw):\n"
helper = '''    def chest_frame(k, corrupt=True):
        """(2026-11-08) His chest's frame under a key: how the UpperTorso is turned and where its joint is, phase 2's corruption layer (Clip.controls)
        included unless the clip goes without it (corrupt=False: the transform)."""
        pel, pelR, chest = (np.array(k[n], float) for n in ("pel", "pelR", "chest"))
        if phase == 2 and corrupt:
            pel = pel + np.array([0, -0.1, -0.03])
            pelR = pelR * np.array([1, 1 + L.CORRUPT_TWIST[0], 1]) + np.array([6.0, 0, 0])
            chest = chest * np.array([1, 1 + L.CORRUPT_TWIST[1], 1]) + np.array([8.0, 0, 0])
        lt = rg.pivoted(np.eye(4), "LowerTorso", L.homog(L.euler(pelR), pel))
        ut = rg.pivoted(lt, "UpperTorso", L.homog(L.euler(chest)))
        return ut[:3, :3], (ut @ np.append(rg.JOINT["UpperTorso"], 1))[:3]

'''
assert s.count(anchor) == 1
s = s.replace(anchor, helper + anchor)
open(p, "w").write(s)
print("hoisted")
