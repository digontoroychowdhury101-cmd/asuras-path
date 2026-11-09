import numpy as np, math, shen_lib as L
def channel(self, name, t):
    keyed = [(kt, c[name], e) for kt, c, e in self.keys if name in c]
    if not keyed:
        return np.asarray(self.rig.REST[name], float)
    if self.loop and keyed[-1][0] < self.length - 1e-6:
        keyed = keyed + [(self.length, keyed[0][1], keyed[0][2])]
    if t <= keyed[0][0]:
        return L.unit(np.asarray(keyed[0][1], float)) if name in L.DIRECTION else np.asarray(keyed[0][1], float)
    if t >= keyed[-1][0]:
        return L.unit(np.asarray(keyed[-1][1], float)) if name in L.DIRECTION else np.asarray(keyed[-1][1], float)
    vals = [L.unit(np.asarray(k[1], float)) if name in L.DIRECTION else np.asarray(k[1], float) for k in keyed]
    ts = [k[0] for k in keyed]
    for i in range(len(keyed) - 1):
        t0, t1 = ts[i], ts[i + 1]
        if t <= t1:
            u = L.EASE[keyed[i + 1][2]]((t - t0) / (t1 - t0) if t1 > t0 else 1.0)
            p1, p2 = vals[i], vals[i + 1]
            if np.allclose(p1, p2, atol=1e-6):
                out = p1
            else:
                if i > 0: p0, tp = vals[i - 1], ts[i - 1]
                elif self.loop: p0, tp = vals[-2], ts[-2] - self.length
                else: p0, tp = p1, t0
                if i + 2 < len(vals): p3, tn = vals[i + 2], ts[i + 2]
                elif self.loop: p3, tn = vals[1], ts[1] + self.length
                else: p3, tn = p2, t1
                h = t1 - t0
                m1 = np.zeros_like(p1) if np.allclose(p0, p1, atol=1e-6) else (p2 - p0) * (h / max(t1 - tp, 1e-6))
                m2 = np.zeros_like(p2) if np.allclose(p2, p3, atol=1e-6) else (p3 - p1) * (h / max(tn - t0, 1e-6))
                u2, u3 = u * u, u * u * u
                out = (2 * u3 - 3 * u2 + 1) * p1 + (u3 - 2 * u2 + u) * m1 + (-2 * u3 + 3 * u2) * p2 + (u3 - u2) * m2
                if name in L.FEET:
                    dist = float(np.linalg.norm(p2[:2] - p1[:2]))
                    out = out.copy()
                    out[2] = max(out[2], min(0.45, dist * 0.32) * math.sin(math.pi * u) if dist > 0.08 else 0)
            return L.unit(out) if name in L.DIRECTION else out
    return vals[-1]
L.Clip.channel = channel
