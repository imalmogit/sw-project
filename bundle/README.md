# Optimization variants for nbody and pyflate

Five variants, each verified to produce the same result as its baseline
before any timing was taken.

| Folder | Targets (from the profile) | Verified |
| --- | --- | --- |
| `bm_nbody_opt1` | sequence element access, 12.8% | bit-exact energy |
| `bm_nbody_opt2` | + the generic `pow` path, 2.8% | 9.5e-15 relative |
| `bm_nbody_opt3_cython` | + boxing, operator dispatch, index conversion | 9.5e-15 relative |
| `bm_pyflate_opt1` | list/slice + allocator, 22.8% | benchmark MD5 passes |
| `bm_pyflate_opt2` | + dict lookup / Huffman scan | benchmark MD5 passes |

Each variant is cumulative: opt2 contains opt1, opt3 contains opt2.

## Locked flags

`-l 1 -w 1 -n N`, with **N = 100 for every nbody variant** and **N = 20 for
every pyflate variant**, including the baselines. Changing N changes how much
work the counters describe and invalidates the comparison.

## Setup

```bash
# pyflate variants need the data file the benchmark opens
BM=/root/sw-project/venv-dbg/lib/python3.10/site-packages/pyperformance/data-files/benchmarks
cp $BM/bm_pyflate/data/interpreter.tar.bz2 bm_pyflate_opt1/data/
cp $BM/bm_pyflate/data/interpreter.tar.bz2 bm_pyflate_opt2/data/

# the Cython variant must be compiled once, with the SAME interpreter
PY=/root/sw-project/baseline/scripts/venv/cpython3.10-58f517067257-compat-31b33d68c68a/bin/python
$PY -m pip install cython
cd bm_nbody_opt3_cython && $PY setup.py build_ext --inplace && cd ..
ls bm_nbody_opt3_cython/*.so    # must exist before measuring
```

## Check correctness before measuring

```bash
$PY verify_nbody.py      # compares final energy against the original
$PY verify_pyflate.py    # checks the MD5 the benchmark asserts on
```

Run these from a directory holding the flat `nbody_*.py` / `pyflate_*.py`
copies, or adjust the paths inside to point at the `bm_*` folders.

## Measure

```bash
./measure.sh ./bm_nbody_opt1 100      # one variant
./run_all.sh                          # baselines + every variant
```

Each run writes `results_<name>/` containing:

- `timing_<name>.txt` + `<name>.json` — pyperf mean over 20 processes
- `stat_<name>.txt` — perf stat, three counter groups, three repetitions
- `report_<name>.txt` — perf report, self overhead
- `<name>.perf.data` — raw profile

## Registering with pyperformance (optional)

`measure.sh` runs `run_benchmark.py` directly, which starts the same pyperf
manager that `pyperformance run` uses, so no registration is needed. If the
report should show them under `pyperformance run --bench <name>`, copy each
folder into `$BM/` and add one line per variant to `$BM/MANIFEST`:

```
nbody_opt1	<local>
```

## What to check in the results

For each variant, three things, in this order:

1. **Correctness** — the verify script passed.
2. **Timing** — the pyperf mean moved by more than the ~3% noise floor.
3. **Attribution** — the mechanism you targeted actually shrank in
   `report_<name>.txt`. A variant that got faster while its target group
   stayed the same got faster for some other reason, and the report should
   say which.
