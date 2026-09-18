#!/usr/bin/env python
"""Check every nbody variant reproduces the original's physics.

Usage:  python verify_nbody.py [path/to/bm_nbody]
The baseline defaults to $BM/bm_nbody.
"""
import importlib.util, os, sys

BM = os.environ.get(
    "BM", "/root/sw-project/venv-dbg/lib/python3.10/site-packages/"
          "pyperformance/data-files/benchmarks")
HERE = os.path.dirname(os.path.abspath(__file__))
BASE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(BM, "bm_nbody")

TARGETS = [("original", os.path.join(BASE, "run_benchmark.py"))] + [
    (n, os.path.join(HERE, "bm_" + n, "run_benchmark.py"))
    for n in ("nbody_opt1", "nbody_opt2", "nbody_opt3_cython")]

def run(path, iterations=20000):
    d = os.path.dirname(path)
    if d not in sys.path:
        sys.path.insert(0, d)          # so opt3 finds its compiled nbody_core
    spec = importlib.util.spec_from_file_location("v_%d" % len(sys.modules), path)
    m = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = m
    spec.loader.exec_module(m)
    m.offset_momentum(m.BODIES['sun'])
    m.advance(0.01, iterations)
    return m.report_energy()

base = None
ok = True
print(f"{'variant':<20} {'final energy':>24}   difference")
for name, path in TARGETS:
    if not os.path.exists(path):
        print(f"{name:<20} {'MISSING: ' + path}")
        ok = False
        continue
    e = run(path)
    if base is None:
        base = e
        print(f"{name:<20} {e:>24.17g}   (reference)")
        continue
    rel = abs(e - base) / abs(base)
    ok &= rel < 1e-12
    print(f"{name:<20} {e:>24.17g}   "
          f"{'bit-exact' if e == base else f'{rel:.3e} relative'}")
print()
print("PASS - every variant matches the original physics" if ok
      else "FAIL - a variant diverged or is missing")
sys.exit(0 if ok else 1)
