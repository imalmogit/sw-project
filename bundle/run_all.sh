#!/bin/bash
# Baselines first, then every variant. Same flags per benchmark throughout.
set -u
BM=${BM:-/root/sw-project/venv-dbg/lib/python3.10/site-packages/pyperformance/data-files/benchmarks}

./measure.sh "$BM/bm_nbody"        100
./measure.sh ./bm_nbody_opt1       100
./measure.sh ./bm_nbody_opt2       100
./measure.sh ./bm_nbody_opt3_cython 100

./measure.sh "$BM/bm_pyflate"       20
./measure.sh ./bm_pyflate_opt1      20
./measure.sh ./bm_pyflate_opt2      20
