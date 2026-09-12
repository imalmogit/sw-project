#!/usr/bin/env bash
#
# vm_audit_minimal.sh -- minimal NON-DESTRUCTIVE environment audit
#
# NOT "strictly read-only". Two things are worth stating plainly up front:
#   * it creates one output file in the current directory;
#   * it executes one measurement command, `perf stat` on /bin/true.
# Nothing existing is read from, written to, installed, upgraded, or removed
# beyond that. "Non-destructive" is the accurate description; "read-only"
# would be an overstatement.
#
# PURPOSE
#   Record the current state of an existing, already-working environment so
#   that project planning can proceed on facts instead of assumptions.
#
# WHAT THIS SCRIPT DOES
#   1. Detects whether we are inside a virtualized guest
#   2. Reports OS and architecture
#   3. Reports Python and python3-dbg versions
#   4. Reports the benchmark harness version and available benchmark names
#   5. Locates the source of the four candidate benchmarks
#   6. Reports the profiler version and runs ONE counter smoke test
#   7. Checks whether flame-graph tooling is present
#   8. Checks whether an HDL simulator is present
#
# WHAT THIS SCRIPT DELIBERATELY DOES NOT DO
#   * No installing, upgrading, downgrading, or removing anything
#   * No modification of any existing file, source tree, or configuration
#   * No creation of a virtual environment
#   * No launching of QEMU
#   * No filesystem-wide scan (never searches "/")
#   * No listing of the home directory contents
#   * No inspection of Git repositories and no printing of Git remotes
#   * No reading of environment variables, shell history, SSH keys, tokens,
#     or any other credential material
#   * No benchmark execution
#
# THE ONLY THING IT WRITES
#   One text file in the CURRENT directory, named:
#       vm_audit_<YYYY-MM-DD_HHMM>.txt
#   Nothing else is created, anywhere.
#
# THE ONLY THING IT EXECUTES
#   Version queries, plus one `perf stat` invocation on /bin/true.
#   /bin/true does nothing and returns success; it is the only way to
#   determine whether hardware counters are usable. If you would rather not
#   run even that, delete the marked line in section 6 and say so when
#   returning the output.
#
# USAGE
#   bash vm_audit_minimal.sh
#
# Errors and "not found" results are expected and are themselves findings.
# Do not fix them; just return the output as produced.
#

OUT="vm_audit_$(date +%F_%H%M).txt"

{
echo "==============================================================="
echo " MINIMAL NON-DESTRUCTIVE ENVIRONMENT AUDIT"
echo " generated: $(date)"
echo "==============================================================="

# ---------------------------------------------------------------------------
echo
echo "=== 1. GUEST DETECTION ==="
echo "--- checks whether this shell is inside a virtualized guest ---"
if command -v systemd-detect-virt >/dev/null 2>&1; then
    echo "systemd-detect-virt : $(systemd-detect-virt 2>&1)"
else
    echo "systemd-detect-virt : not available"
fi
# The 'hypervisor' CPU flag is exposed only inside a virtual machine.
if grep -qm1 hypervisor /proc/cpuinfo 2>/dev/null; then
    echo "hypervisor CPU flag : present  (=> running inside a VM)"
else
    echo "hypervisor CPU flag : absent   (=> likely bare metal)"
fi
# Virtualized platforms report synthetic firmware identity strings.
echo "firmware vendor     : $(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || echo unavailable)"
echo "firmware product    : $(cat /sys/class/dmi/id/product_name 2>/dev/null || echo unavailable)"
echo "hostname            : $(hostname 2>/dev/null || echo unavailable)"

# ---------------------------------------------------------------------------
echo
echo "=== 2. OS AND ARCHITECTURE ==="
echo "--- confirms distribution, kernel and CPU; none of this is assumed ---"
if [ -r /etc/os-release ]; then
    grep -E '^(NAME|VERSION|VERSION_ID|PRETTY_NAME)=' /etc/os-release 2>/dev/null
else
    echo "/etc/os-release : not readable"
fi
echo "kernel / arch : $(uname -srm 2>/dev/null || echo unavailable)"
if command -v lscpu >/dev/null 2>&1; then
    lscpu 2>/dev/null | grep -E 'Architecture|Model name|^CPU\(s\)|Thread|Core|Socket|cache'
else
    echo "lscpu : not available"
fi

# ---------------------------------------------------------------------------
echo
echo "=== 3. PYTHON INTERPRETERS ==="
echo "--- the documented profiling command depends on a debug build ---"
for PY in python3 python3-dbg; do
    if command -v "$PY" >/dev/null 2>&1; then
        echo "$PY : $("$PY" -VV 2>&1 | tr '\n' ' ')"
        echo "    path : $(command -v "$PY")"
    else
        echo "$PY : NOT FOUND"
    fi
done
# Confirms a genuine debug build rather than a same-named release build.
if command -v python3-dbg >/dev/null 2>&1; then
    echo "python3-dbg Py_DEBUG : $(python3-dbg -c \
        'import sysconfig;print(sysconfig.get_config_var("Py_DEBUG"))' 2>&1 | tail -1)"
fi

# ---------------------------------------------------------------------------
echo
echo "=== 4. BENCHMARK HARNESS ==="
echo "--- version determines which command-line options exist ---"
for PY in python3 python3-dbg; do
    if command -v "$PY" >/dev/null 2>&1; then
        echo "$PY -m pyperformance --version : $(timeout 60 "$PY" -m pyperformance --version 2>&1 | head -1)"
    fi
done

echo
echo "--- available benchmark names (authoritative for THIS install) ---"
echo "--- if this appears to hang or wants to build anything, press Ctrl-C"
echo "    and report that it did so; nothing is expected to be created ---"
timeout 120 python3 -m pyperformance list 2>&1 | head -100

# ---------------------------------------------------------------------------
echo
echo "=== 5. CANDIDATE BENCHMARK SOURCE LOCATIONS ==="
echo "--- every constant used in planning must be read from these files ---"
BMDIR="$(python3 -c 'import os,pyperformance;print(os.path.join(os.path.dirname(os.path.abspath(pyperformance.__file__)),"data-files","benchmarks"))' 2>/dev/null)"
if [ -n "${BMDIR:-}" ] && [ -d "$BMDIR" ]; then
    echo "benchmarks directory : $BMDIR"
    for B in nbody raytrace pyflate deepcopy; do
        echo
        if [ -d "$BMDIR/bm_$B" ]; then
            echo "bm_$B : PRESENT at $BMDIR/bm_$B"
            ls -1 "$BMDIR/bm_$B" 2>/dev/null | sed 's/^/    /'
            # Data-file presence matters for at least one candidate.
            if [ -d "$BMDIR/bm_$B/data" ]; then
                echo "    data/:"
                ls -1sh "$BMDIR/bm_$B/data" 2>/dev/null | sed 's/^/        /'
            fi
        else
            echo "bm_$B : NOT FOUND under $BMDIR"
        fi
    done
else
    echo "Could not locate the benchmark data directory."
    echo "python3 -c 'import pyperformance' result:"
    python3 -c 'import pyperformance;print(pyperformance.__file__)' 2>&1 | head -3
fi

# ---------------------------------------------------------------------------
echo
echo "=== 6. PROFILER ==="
echo "--- version, permission level, and whether counters actually work ---"
if command -v perf >/dev/null 2>&1; then
    echo "perf version : $(perf --version 2>&1 | head -1)"
else
    echo "perf : NOT FOUND"
fi
# Read-only kernel tunables. paranoid level gates what a non-root user may
# measure: 3 = nothing, 2 = user-space only, 1 = +kernel, 0 = +raw, -1 = all.
echo "perf_event_paranoid    : $(cat /proc/sys/kernel/perf_event_paranoid 2>/dev/null || echo unavailable)"
echo "perf_event_max_sample_rate : $(cat /proc/sys/kernel/perf_event_max_sample_rate 2>/dev/null || echo unavailable)"

echo
echo "--- counter smoke test: runs /bin/true only, changes nothing ---"
echo "--- '<not supported>' here is the single most important finding ---"
if command -v perf >/dev/null 2>&1; then
    # ↓↓↓ THE ONLY LINE THAT EXECUTES A MEASUREMENT. Delete to skip. ↓↓↓
    perf stat -e task-clock,cycles,instructions,cache-references,cache-misses \
        /bin/true 2>&1 | tail -15
    # ↑↑↑ ------------------------------------------------------------- ↑↑↑
else
    echo "skipped: perf not present"
fi

# ---------------------------------------------------------------------------
echo
echo "=== 7. FLAME GRAPH TOOLING ==="
echo "--- targeted checks only; no filesystem scan is performed ---"
FOUND_FG=0
for T in flamegraph.pl stackcollapse-perf.pl; do
    if command -v "$T" >/dev/null 2>&1; then
        echo "$T : on PATH at $(command -v "$T")"
        FOUND_FG=1
    else
        echo "$T : not on PATH"
    fi
done
# A short, explicit list of conventional locations. This is not a search.
for P in "$HOME/FlameGraph/flamegraph.pl" \
         "$HOME/flamegraph/flamegraph.pl" \
         "/opt/FlameGraph/flamegraph.pl" \
         "/usr/local/FlameGraph/flamegraph.pl" \
         "./FlameGraph/flamegraph.pl"; do
    if [ -f "$P" ]; then
        echo "found : $P"
        FOUND_FG=1
    fi
done
[ "$FOUND_FG" -eq 0 ] && echo "=> no flame-graph scripts found in the checked locations"
# perf can also generate flame graphs natively via a bundled script engine.
if command -v perf >/dev/null 2>&1; then
    echo "--- perf built-in script engines ---"
    perf script -l 2>&1 | head -15
fi

# ---------------------------------------------------------------------------
echo
echo "=== 8. HDL SIMULATOR ==="
echo "--- determines whether simulating the accelerator is already possible ---"
FOUND_HDL=0
for T in iverilog vvp verilator gtkwave yosys ghdl vsim xvlog; do
    if command -v "$T" >/dev/null 2>&1; then
        echo "$T : $(command -v "$T")"
        FOUND_HDL=1
    else
        echo "$T : not installed"
    fi
done
[ "$FOUND_HDL" -eq 0 ] && echo "=> no HDL simulator found on PATH"

# ---------------------------------------------------------------------------
echo
echo "==============================================================="
echo " AUDIT COMPLETE"
echo " Nothing was installed, upgraded, modified, or deleted."
echo "==============================================================="
} 2>&1 | tee "$OUT"

echo
echo "Output written to: $(pwd)/$OUT"
echo "Return that file. Do not edit it; error lines are findings too."
