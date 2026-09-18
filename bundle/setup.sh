#!/bin/bash
# One-time setup, run from the directory holding the bm_* folders.
set -eu

PY=${PY:-/root/sw-project/baseline/scripts/venv/cpython3.10-58f517067257-compat-31b33d68c68a/bin/python}
BM=${BM:-/root/sw-project/venv-dbg/lib/python3.10/site-packages/pyperformance/data-files/benchmarks}

echo "[*] interpreter: $PY"
echo "[*] benchmarks : $BM"
[ -x "$PY" ] || { echo "ERROR: \$PY is not executable. Set PY=... and retry."; exit 1; }
[ -d "$BM/bm_pyflate" ] || { echo "ERROR: \$BM/bm_pyflate not found. Set BM=... and retry."; exit 1; }

echo "[1/3] copying the pyflate data file..."
for d in bm_pyflate_opt1 bm_pyflate_opt2; do
    mkdir -p "$d/data"
    cp "$BM/bm_pyflate/data/interpreter.tar.bz2" "$d/data/"
done

echo "[2/3] building the Cython extension..."
$PY -m pip install --quiet cython
( cd bm_nbody_opt3_cython && $PY setup.py build_ext --inplace )
ls bm_nbody_opt3_cython/*.so >/dev/null || { echo "ERROR: extension did not build"; exit 1; }

echo "[3/3] verifying correctness..."
$PY verify_nbody.py
$PY verify_pyflate.py

echo
echo "[+] setup complete. Next:  ./run_all.sh"
