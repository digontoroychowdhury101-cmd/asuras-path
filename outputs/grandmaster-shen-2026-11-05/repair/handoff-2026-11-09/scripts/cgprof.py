"""Write cloth_bake's run script for one shot to a file (no run), so it can be profiled under the CLI with codegen."""
import sys, os, subprocess
from pathlib import Path
ROOT = Path("' + ROOT + '")
sys.path.insert(0, str(ROOT / "tools/animation/opening_cast"))
os.environ["SHEN_CLOTH_SIM"], os.environ["SHEN_CLOTH_DIR"] = sys.argv[1], sys.argv[2]
import cloth_bake as cb
def keep(cmd, **kw):
    Path(sys.argv[4]).write_text(Path(cmd[-1]).read_text())
    raise SystemExit(0)
cb.subprocess.run = keep
name = sys.argv[3]
frames, roots = cb.sequence(int(name[1]), [("Idle", 0.6, 0.0, 0.0), (name[3:], None, 0.0, 0.0)])
cb.run_sim(int(name[1]), frames, roots)
