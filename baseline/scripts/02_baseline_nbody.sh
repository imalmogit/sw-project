#!/usr/bin/env bash
#
# 02_baseline_nbody.sh -- the FIRST ORIGINAL BASELINE RUN
#
# THIS IS NOT THE SUBMITTED script_<benchmark>.sh. It is a pipeline proof.
# Its job is to answer one question: does the full measurement chain work
# end-to-end in this VM? Harness -> perf stat -> perf record -> perf script
# -> folded stacks -> rendered flame graph.
#
# It runs ONE benchmark, UNMODIFIED. No optimization exists yet. The numbers
# it produces are a baseline, not a result.
#
# MODES
#   bash 02_baseline_nbody.sh              # full pipeline proof on nbody
#   bash 02_baseline_nbody.sh --sweep      # time all four candidates once,
#                                          #   no profiling -- for selection
#   REPS=10 bash 02_baseline_nbody.sh      # more perf stat repetitions
#
# WHY nbody FIRST
#   This VM has ONE vCPU at 2.40 GHz and will run a debug build of Python.
#   nbody is the cheapest of the four candidates to iterate on, so it is the
#   right choice to prove the pipeline before committing time to a slower one.
#   Choosing it here does NOT select it for the project.
#
# EXPECT THE FIRST RUN TO BE SLOW: the harness builds its own internal virtual
# environment on first use, which needs network and several minutes.
#
set -uo pipefail

HWSW_ROOT="${HWSW_ROOT:-$HOME/hwsw_project}"
VENV="$HWSW_ROOT/venv-dbg"
FG="$HWSW_ROOT/tools/FlameGraph"
BENCH="${BENCH:-nbody}"
REPS="${REPS:-3}"
STAMP="$(date +%F_%H%M)"

# ---------------------------------------------------------------------------
# WHY perf record SAMPLES ON A SOFTWARE EVENT HERE
#
# This VM is a KVM guest with a virtualised PMU that supports COUNTING but not
# SAMPLING. Verified empirically on this machine:
#
#   perf record -e cycles    -> 0.003 MB, "data has no samples!"
#   perf record -e cpu-clock -> 0.718 MB, 10430 samples
#
# perf stat (counting mode) reads counters at start and end and works fine, so
# the hardware event list below is unchanged. perf record (sampling mode) needs
# the PMU to raise an interrupt every N events, and that interrupt is not
# delivered in this guest -- hence zero samples and an empty flame graph.
#
# cpu-clock is driven by the kernel's high-resolution timer instead, so it
# needs no PMU interrupt.
#
# CONSEQUENCE FOR THE REPORT: the flame graph is TIME-based, not CYCLE-based.
# Say so. It is a fair profile of where time goes; it is not a profile of where
# cycles go, and those can differ when stalls are unevenly distributed.
# ---------------------------------------------------------------------------
RECORD_EVENT="${RECORD_EVENT:-cpu-clock}"

# Hardware events for COUNTING -- these work; leave them alone.
STAT_EVENTS="task-clock,context-switches,page-faults,cycles,instructions,cache-references,cache-misses,branches,branch-misses"

say()  { printf '\n[baseline] %s\n' "$*"; }
die()  { printf '\n[baseline] ABORT: %s\n' "$*" >&2; exit 1; }

[ -x "$VENV/bin/activate" ] || [ -f "$VENV/bin/activate" ] \
    || die "no venv at $VENV -- run 01_setup.sh first"
# shellcheck disable=SC1091
source "$VENV/bin/activate" || die "cannot activate $VENV"

command -v perf >/dev/null 2>&1 || die "perf not found"
python -c 'import pyperformance' >/dev/null 2>&1 \
    || die "pyperformance not importable in the venv -- re-run 01_setup.sh"

# ---------------------------------------------------------------------------
# SWEEP MODE -- wall-clock only, for benchmark selection
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--sweep" ]; then
    SWEEP_DIR="$HWSW_ROOT/results/sweep_$STAMP"
    mkdir -p "$SWEEP_DIR"
    say "TIMING SWEEP -- one run each, no profiling"
    echo "  Purpose: measure how expensive each candidate is to iterate on"
    echo "  in THIS VM (1 vCPU, debug Python). This feeds criterion 8 of the"
    echo "  selection rubric. It is not a performance result."
    echo

    # First: what does this install actually offer? The audit could not answer
    # this, because the harness was not installed yet.
    say "Benchmark names available in THIS install"
    python -m pyperformance list 2>&1 | tee "$SWEEP_DIR/available_benchmarks.txt"

    for B in nbody raytrace pyflate deepcopy; do
        echo
        echo "=============================================="
        echo " timing: $B"
        echo "=============================================="
        START=$(date +%s)
        if timeout 3600 python -m pyperformance run -b "$B" \
                -o "$SWEEP_DIR/${B}.json" > "$SWEEP_DIR/${B}_run.log" 2>&1; then
            END=$(date +%s)
            echo "  wall clock : $((END-START)) s"
            python -m pyperformance show "$SWEEP_DIR/${B}.json" 2>&1 | tail -5
        else
            END=$(date +%s)
            echo "  FAILED or timed out after $((END-START)) s"
            echo "  last 15 lines of log:"
            tail -15 "$SWEEP_DIR/${B}_run.log" | sed 's/^/    /'
        fi
    done

    say "SWEEP COMPLETE -- results in $SWEEP_DIR"
    echo "  Return available_benchmarks.txt and the wall-clock figures."
    exit 0
fi

# ---------------------------------------------------------------------------
# FULL PIPELINE PROOF
# ---------------------------------------------------------------------------
RES="$HWSW_ROOT/results/baseline_${BENCH}_${STAMP}"
mkdir -p "$RES"
say "BASELINE: $BENCH (unmodified)  ->  $RES"

# --- 0. what this install offers -------------------------------------------
say "[0/5] benchmark names available in this install"
python -m pyperformance list > "$RES/available_benchmarks.txt" 2>&1
head -40 "$RES/available_benchmarks.txt"
grep -qw "$BENCH" "$RES/available_benchmarks.txt" 2>/dev/null \
    && echo "  confirmed: '$BENCH' is available in this install" \
    || echo "  (note: '$BENCH' not matched in the list -- check the file)"

# --- 1. harness timing -- the primary evidence for any later 7% claim ------
say "[1/5] harness run -> JSON (this is the number that matters)"
if python -m pyperformance run -b "$BENCH" -o "$RES/${BENCH}_baseline.json" \
        2>&1 | tee "$RES/harness_run.log"; then
    python -m pyperformance show "$RES/${BENCH}_baseline.json" \
        2>&1 | tee "$RES/harness_summary.txt"
else
    die "harness run failed -- see $RES/harness_run.log"
fi

# --- 2. counters -----------------------------------------------------------
say "[2/5] perf stat, $REPS repetitions (hardware counters -- counting mode)"
echo "  NOTE: this measures the WHOLE harness process, not just the benchmark."
echo "  Useful for hotspot context; NOT the source of the improvement figure."
perf stat -r "$REPS" -e "$STAT_EVENTS" \
    python -m pyperformance run -b "$BENCH" \
    > "$RES/perf_stat_stdout.txt" 2> "$RES/perf_stat.txt"
tail -25 "$RES/perf_stat.txt"

# --- 3. sampling profile ---------------------------------------------------
say "[3/5] perf record, sampling on '$RECORD_EVENT'"
echo "  Hardware-event sampling yields zero samples in this guest; see the"
echo "  note at the top of this script. Record this in the report."
perf record -e "$RECORD_EVENT" -F 999 -g -o "$RES/perf.data" -- \
    python -m pyperformance run -b "$BENCH" \
    > "$RES/perf_record.log" 2>&1 \
    || echo "  (perf record returned non-zero -- check $RES/perf_record.log)"
[ -s "$RES/perf.data" ] || die "no perf.data produced"
echo "  perf.data : $(du -h "$RES/perf.data" | cut -f1)"

# Verify samples actually landed. A perf.data of pure headers is ~100 KB and
# looks fine to `ls`, but yields an empty profile -- this is precisely the
# failure that produced two useless baseline runs before the cause was found.
SAMPLES="$(perf report --stdio -i "$RES/perf.data" --header-only 2>/dev/null \
           | grep -oE 'Samples: *[0-9KMG]+' | head -1)"
if perf report --stdio -i "$RES/perf.data" 2>&1 | grep -q 'has no samples'; then
    die "perf.data contains NO SAMPLES.
       Sampling failed even on '$RECORD_EVENT'. Do not trust any profile from
       this run. Try:  RECORD_EVENT=task-clock bash \$0
       and report the result before going further."
fi
echo "  ${SAMPLES:-samples present} -- sampling confirmed"

say "[4/5] perf report --stdio"
perf report --stdio -i "$RES/perf.data" > "$RES/perf_report.txt" 2>&1
head -30 "$RES/perf_report.txt"

# --- 4. flame graph --------------------------------------------------------
say "[5/5] flame graph"
if [ -x "$FG/stackcollapse-perf.pl" ] && [ -x "$FG/flamegraph.pl" ]; then
    perf script -i "$RES/perf.data" > "$RES/perf_script.txt" 2>"$RES/perf_script.err"
    if [ -s "$RES/perf_script.txt" ]; then
        "$FG/stackcollapse-perf.pl" "$RES/perf_script.txt" > "$RES/out.folded"
        "$FG/flamegraph.pl" --title "$BENCH baseline" "$RES/out.folded" \
            > "$RES/flamegraph_${BENCH}_baseline.svg"
        echo "  wrote $RES/flamegraph_${BENCH}_baseline.svg"
        echo "  size  : $(du -h "$RES/flamegraph_${BENCH}_baseline.svg" | cut -f1)"
        echo "  frames: $(wc -l < "$RES/out.folded") collapsed stacks"
    else
        echo "  !! perf script produced no output"
        echo "  stderr:"; sed 's/^/    /' "$RES/perf_script.err"
    fi
else
    echo "  !! FlameGraph scripts not found at $FG -- re-run 01_setup.sh"
fi

# ---------------------------------------------------------------------------
say "BASELINE COMPLETE"
cat <<EOF

  Results : $RES

  Return these five:
    harness_summary.txt          the mean +/- std dev  <- the number that matters
    perf_stat.txt                counter values, and whether any read
                                 '<not supported>'
    perf_report.txt              (first ~50 lines) where the time went
    flamegraph_*.svg             open it in a browser and confirm it renders
    available_benchmarks.txt     settles the deepblue/deltablue question

  Reminders:
    * These are BASELINE numbers for an UNMODIFIED benchmark. Nothing here
      is an optimization result.
    * Expect the flame graph to show C-level CPython frames, not your Python
      function names. That is normal for perf on Python 3.10 and is worth
      stating in the report rather than treating as a defect.
    * The profile was sampled on '$RECORD_EVENT', a SOFTWARE event, because
      hardware-event sampling yields no samples in this KVM guest. The flame
      graph therefore shows where TIME goes, not where CYCLES go. State this
      in the report's methodology section -- it is a real limitation, and
      explaining it correctly is worth more than hiding it.
    * perf stat still uses hardware counters (counting works fine), so cycles,
      instructions and cache figures in perf_stat.txt are genuine PMU data.
    * Append the prompts used to reach this point to prompt.txt.

EOF