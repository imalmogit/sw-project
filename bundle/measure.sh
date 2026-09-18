#!/bin/bash
# Measure one benchmark variant three ways: timing, counters, profile.
#
#   ./measure.sh <folder> <N>
#     folder : a bm_* directory containing run_benchmark.py
#     N      : the -n value  (100 for nbody variants, 20 for pyflate variants)
#
# N MUST match the baseline for that benchmark, or the instruction counts
# describe a different amount of work and the comparison is meaningless.
set -u

PY=${PY:-/root/sw-project/baseline/scripts/venv/cpython3.10-58f517067257-compat-31b33d68c68a/bin/python}

DIR=$1
N=$2
NAME=$(basename "$DIR")
OUT="results_${NAME}"
mkdir -p "$OUT"

BENCH="$DIR/run_benchmark.py"
[ -f "$BENCH" ] || { echo "no run_benchmark.py in $DIR"; exit 1; }

echo "=============================================="
echo "[*] $NAME   (-l 1 -w 1 -n $N)"
echo "=============================================="

# ---- 1. TIMING: full pyperf manager, 20 processes, own calibration ----
echo "[1/3] timing..."
$PY -u "$BENCH" -o "$OUT/${NAME}.json" 2>&1 | tee "$OUT/timing_${NAME}.txt"

# ---- 2. COUNTERS: fixed work, three groups (1 vCPU cannot multiplex more) ----
echo "[2/3] counters..."
: > "$OUT/stat_${NAME}.txt"
for G in "task-clock,context-switches,page-faults,cycles,instructions" \
         "cache-references,cache-misses" \
         "branches,branch-misses"; do
  echo "=== $G ===" | tee -a "$OUT/stat_${NAME}.txt"
  perf stat -r 3 -e "$G" -- \
      $PY -u "$BENCH" --worker -l 1 -w 1 -n "$N" \
      2>&1 | tee -a "$OUT/stat_${NAME}.txt"
done

# ---- 3. PROFILE: cpu-clock named explicitly, or zero samples are captured ----
echo "[3/3] profile..."
perf record -e cpu-clock -F 199 -g -o "$OUT/${NAME}.perf.data" -- \
    $PY -u "$BENCH" --worker -l 1 -w 1 -n "$N"
perf report -i "$OUT/${NAME}.perf.data" --stdio --no-children \
    > "$OUT/report_${NAME}.txt"

echo "[+] done -> $OUT/"
grep -E "Mean \+- std dev" "$OUT/timing_${NAME}.txt" | tail -1
grep -E "instructions" "$OUT/stat_${NAME}.txt" | head -1
