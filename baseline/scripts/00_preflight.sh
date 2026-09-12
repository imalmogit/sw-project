#!/usr/bin/env bash
#
# 00_preflight.sh -- fills the gaps the minimal audit deliberately skipped
#
# The minimal audit answered "what is installed". This answers "can we
# install, and will the measurement pipeline actually work". Run this BEFORE
# 01_setup.sh. Nothing is installed or changed by this script.
#
# WHAT IT DOES
#   1. Confirms effective user (explains why perf worked at paranoid=4)
#   2. Disk space and RAM  -- setup and profiling both need headroom
#   3. Network reachability -- pip and git both need it
#   4. apt availability, simulated only (apt-get -s, no changes)
#   5. Locates the real perf binary and its scripts directory
#   6. Tests whether `perf script` raw dump works -- the FlameGraph pipeline
#      depends on this, and it is NOT the same code path as the missing
#      `perf script report <engine>` support
#
# WHAT IT CHANGES
#   Creates one output file in the current directory, and one temporary
#   directory under /tmp which it removes before exiting. Nothing else.
#
# USAGE
#   bash 00_preflight.sh
#
# Failures are findings. Do not fix them; return the output.
#

OUT="preflight_$(date +%F_%H%M).txt"
TMPD="$(mktemp -d /tmp/preflight.XXXXXX)"
trap 'rm -rf "$TMPD"' EXIT

{
echo "==============================================================="
echo " PREFLIGHT -- can we prepare for a baseline run?"
echo " generated: $(date)"
echo "==============================================================="

echo
echo "=== A. IDENTITY AND PRIVILEGE ==="
echo "--- perf_event_paranoid is 4; on Ubuntu-family kernels any value >=3"
echo "--- blocks perf_event_open for unprivileged users entirely. The audit's"
echo "--- counter smoke test SUCCEEDED, so it must have run privileged."
echo "--- This confirms which."
echo "user        : $(id -un 2>/dev/null) (uid $(id -u 2>/dev/null))"
echo "groups      : $(id -Gn 2>/dev/null)"
if [ "$(id -u)" -eq 0 ]; then
    echo "verdict     : running as root -> perf works, apt will work"
else
    echo "verdict     : NOT root -> check whether perf still works for you,"
    echo "              and whether you can apt install. Report this."
fi

echo
echo "=== B. DISK SPACE ==="
echo "--- setup needs room for a venv, the harness, its internal venvs, and"
echo "--- recorded profiles. perf.data from one run can reach tens of MB. ---"
df -h / /home /root /tmp 2>/dev/null
echo
echo "inode usage on / :"
df -i / 2>/dev/null

echo
echo "=== C. MEMORY ==="
echo "--- the audit showed 1 vCPU; memory was not captured ---"
free -h 2>/dev/null || echo "free: unavailable"
echo "swap:"
swapon --show 2>/dev/null || echo "  (none configured, or unreadable)"

echo
echo "=== D. NETWORK REACHABILITY ==="
echo "--- pip and git clone both require outbound HTTPS ---"
echo "DNS resolution:"
getent hosts pypi.org        2>/dev/null || echo "  pypi.org        : NOT RESOLVED"
getent hosts github.com      2>/dev/null || echo "  github.com      : NOT RESOLVED"
getent hosts archive.ubuntu.com 2>/dev/null || echo "  archive.ubuntu.com : NOT RESOLVED"
echo
echo "HTTPS reachability (15s timeout each):"
python3 - <<'PYEOF' 2>&1
import urllib.request, ssl
for url in ("https://pypi.org/simple/",
            # the actual endpoint `git clone` handshakes against, so this
            # tests what we need rather than just "is github up"
            "https://github.com/brendangregg/FlameGraph.git/info/refs?service=git-upload-pack",
            "http://archive.ubuntu.com/ubuntu/"):
    try:
        with urllib.request.urlopen(url, timeout=15) as r:
            print(f"  {url:40s} -> HTTP {r.status}")
    except Exception as e:
        print(f"  {url:40s} -> FAILED: {type(e).__name__}: {e}")
PYEOF

echo
echo "=== E. APT AVAILABILITY (SIMULATED -- NOTHING IS INSTALLED) ==="
echo "--- 'apt-get -s' simulates only; it makes no changes ---"
for PKG in python3-dbg python3.10-venv git; do
    echo "--- $PKG ---"
    apt-cache policy "$PKG" 2>&1 | head -3
done
echo
echo "--- simulated install (dry run) ---"
apt-get -s install python3-dbg python3.10-venv git 2>&1 | tail -15

echo
echo "=== F. PERF BINARY LOCATION ==="
echo "--- the audit reported the scripts dir missing; find the real binary ---"
echo "perf on PATH : $(command -v perf 2>/dev/null || echo 'not found')"
if [ -n "$(command -v perf 2>/dev/null)" ]; then
    P="$(command -v perf)"
    echo "file type    : $(file -b "$P" 2>/dev/null || echo unknown)"
    # On Ubuntu /usr/bin/perf is often a wrapper that execs a versioned binary.
    if head -c 2 "$P" 2>/dev/null | grep -q '#!'; then
        echo "(wrapper script -- contents follow)"
        sed -n '1,40p' "$P" 2>/dev/null | sed 's/^/    /'
    fi
fi
echo
echo "versioned tool directories:"
ls -d /usr/lib/linux-tools* /usr/lib/linux-*-tools* 2>/dev/null || echo "  (none found)"
echo "candidate scripts directories:"
for D in /usr/libexec/perf-core /usr/share/perf-core /usr/lib/perf-core; do
    [ -d "$D" ] && echo "  EXISTS : $D" || echo "  absent : $D"
done

echo
echo "=== G. DOES THE FLAMEGRAPH PIPELINE WORK? ==="
echo "--- the missing scripts dir breaks 'perf script report <engine>'."
echo "--- It should NOT break plain 'perf script', which is a builtin and is"
echo "--- what the FlameGraph tool chain consumes. This settles it. ---"
if command -v perf >/dev/null 2>&1; then
    echo "[1/3] perf record on /bin/true (into a temp dir):"
    perf record -q -F 99 -g -o "$TMPD/perf.data" -- /bin/true 2>&1 | tail -5
    if [ -s "$TMPD/perf.data" ]; then
        echo "      perf.data created, $(du -h "$TMPD/perf.data" | cut -f1)"
    else
        echo "      !! no perf.data produced"
    fi

    echo "[2/3] perf script raw dump (first 10 lines):"
    perf script -i "$TMPD/perf.data" 2>&1 | head -10 | sed 's/^/      /'

    echo "[3/3] verdict:"
    if perf script -i "$TMPD/perf.data" >/dev/null 2>&1; then
        echo "      PASS -- plain 'perf script' works."
        echo "      The FlameGraph script pipeline is viable."
        echo "      The missing perf-core scripts dir is NOT blocking."
    else
        echo "      FAIL -- 'perf script' does not work either."
        echo "      Report this; the flame graph route needs rethinking."
    fi
else
    echo "perf not found -- skipped"
fi

echo
echo "=== H. SAMPLE-RATE TUNABLE (READ ONLY) ==="
echo "--- already 100000 per the audit; confirming no change is needed ---"
echo "perf_event_max_sample_rate : $(cat /proc/sys/kernel/perf_event_max_sample_rate 2>/dev/null)"

echo
echo "==============================================================="
echo " PREFLIGHT COMPLETE -- nothing was installed or changed"
echo "==============================================================="
} 2>&1 | tee "$OUT"

echo
echo "Output written to: $(pwd)/$OUT"
echo "Return that file before running 01_setup.sh."
