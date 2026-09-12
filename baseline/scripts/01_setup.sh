#!/usr/bin/env bash
#
# 01_setup.sh -- prepare a SELF-CONTAINED environment for the first baseline run
#
# THIS SCRIPT INSTALLS THINGS. Read it before running it.
#
# DESIGN PRINCIPLE: do not disturb the partner's existing setup.
#   * All project state lives under one new directory (default ~/hwsw_project).
#   * The Python environment is a venv inside that directory. System Python is
#     never pip-installed into.
#   * The only system-wide changes are apt packages, which are additive:
#       python3-dbg      -- the debug interpreter the specification's profiling
#                           command requires; absent per the audit
#       python3.10-venv  -- needed to create a venv from the debug interpreter
#       git              -- to clone the flame graph tooling
#     Nothing is removed, replaced, upgraded, or reconfigured.
#
# RUN 00_preflight.sh FIRST. This script refuses to continue if the basics
# (privilege, disk, network) are not in place.
#
# USAGE
#   bash 01_setup.sh              # interactive, asks before installing
#   bash 01_setup.sh --yes        # non-interactive
#   HWSW_ROOT=/path bash 01_setup.sh   # different project directory
#
# IDEMPOTENT: safe to re-run. Existing pieces are detected and skipped.
#
set -uo pipefail

HWSW_ROOT="${HWSW_ROOT:-$HOME/hwsw_project}"
ASSUME_YES=0
[ "${1:-}" = "--yes" ] && ASSUME_YES=1

say()  { printf '\n[setup] %s\n' "$*"; }
warn() { printf '\n[setup] WARNING: %s\n' "$*" >&2; }
die()  { printf '\n[setup] ABORT: %s\n' "$*" >&2; exit 1; }

confirm() {
    [ "$ASSUME_YES" -eq 1 ] && return 0
    printf '%s [y/N] ' "$1"
    read -r reply </dev/tty
    case "$reply" in [yY]*) return 0 ;; *) return 1 ;; esac
}

# ---------------------------------------------------------------------------
say "Preconditions"

[ "$(id -u)" -eq 0 ] || warn "not running as root -- apt install will likely fail,
         and perf may be unusable (perf_event_paranoid is 4 on this VM)"

AVAIL_KB=$(df -Pk "$HOME" 2>/dev/null | awk 'NR==2{print $4}')
if [ -n "${AVAIL_KB:-}" ]; then
    echo "  free space on \$HOME : $((AVAIL_KB/1024)) MB"
    [ "$AVAIL_KB" -lt 2097152 ] && warn "under 2 GB free. The harness creates its own
         virtual environments per run, and recorded profiles add up. Consider
         freeing space first."
fi

python3 - <<'PYEOF' || die "no outbound HTTPS -- pip and git clone cannot work.
       Re-run 00_preflight.sh section D and report the result."
import urllib.request, sys
try:
    urllib.request.urlopen("https://pypi.org/simple/", timeout=20)
except Exception as e:
    print(f"  network check failed: {type(e).__name__}: {e}")
    sys.exit(1)
print("  outbound HTTPS to pypi.org: OK")
PYEOF

# ---------------------------------------------------------------------------
say "Step 1/5 -- system packages"

NEED=()
command -v git >/dev/null 2>&1 || NEED+=(git)
command -v python3-dbg >/dev/null 2>&1 || NEED+=(python3-dbg)
python3 -c 'import venv' >/dev/null 2>&1 || NEED+=(python3.10-venv)
# python3-dbg needs the venv module too; the package provides it for both.
if command -v python3-dbg >/dev/null 2>&1; then
    python3-dbg -c 'import venv' >/dev/null 2>&1 || NEED+=(python3.10-venv)
fi

if [ "${#NEED[@]}" -eq 0 ]; then
    echo "  all required system packages already present -- nothing to install"
else
    printf '  to install: %s\n' "${NEED[*]}"
    echo "  this runs: apt-get update && apt-get install -y ${NEED[*]}"
    echo "  (apt-get update refreshes package lists under /var/lib/apt/lists)"
    if confirm "  proceed with the apt install?"; then
        apt-get update || warn "apt-get update reported errors; continuing"
        apt-get install -y "${NEED[@]}" || die "apt install failed -- report the output"
    else
        die "declined. Nothing was installed."
    fi
fi

command -v python3-dbg >/dev/null 2>&1 \
    || die "python3-dbg still not available after install -- report this"
echo "  python3-dbg : $(python3-dbg -VV 2>&1 | tr '\n' ' ')"

# ---------------------------------------------------------------------------
say "Step 2/5 -- project directory"

if [ -e "$HWSW_ROOT" ] && [ -n "$(ls -A "$HWSW_ROOT" 2>/dev/null)" ]; then
    echo "  $HWSW_ROOT already exists and is not empty -- reusing it"
else
    mkdir -p "$HWSW_ROOT" || die "cannot create $HWSW_ROOT"
    echo "  created $HWSW_ROOT"
fi
mkdir -p "$HWSW_ROOT/results" "$HWSW_ROOT/tools"
cd "$HWSW_ROOT" || die "cannot enter $HWSW_ROOT"

# ---------------------------------------------------------------------------
say "Step 3/5 -- debug-build virtual environment"

VENV="$HWSW_ROOT/venv-dbg"
if [ -x "$VENV/bin/python" ]; then
    echo "  venv already present at $VENV -- reusing"
else
    echo "  creating venv from python3-dbg ..."
    python3-dbg -m venv "$VENV" || die "venv creation failed.
       Known fallbacks, in order:
         1. apt-get install -y python3.10-venv   (if not already done)
         2. python3-dbg -m venv --without-pip \"$VENV\" then bootstrap pip
       Report the exact error before trying either."
    echo "  created $VENV"
fi

# shellcheck disable=SC1091
source "$VENV/bin/activate" || die "cannot activate $VENV"
echo "  active interpreter : $(python -VV 2>&1 | tr '\n' ' ')"
python -c 'import sysconfig;assert sysconfig.get_config_var("Py_DEBUG"),"not a debug build"' \
    && echo "  confirmed: this venv uses a DEBUG build (Py_DEBUG set)" \
    || warn "this venv does NOT appear to be a debug build -- report this"

# ---------------------------------------------------------------------------
say "Step 4/5 -- benchmark harness"

if python -c 'import pyperformance' >/dev/null 2>&1; then
    echo "  pyperformance already installed in the venv"
else
    python -m pip install --upgrade pip     || warn "pip upgrade failed; continuing"
    python -m pip install pyperformance     || die  "pyperformance install failed"
fi
echo "  pyperformance : $(python -m pyperformance --version 2>&1 | head -1)"

# ---------------------------------------------------------------------------
say "Step 5/5 -- flame graph tooling"

FG="$HWSW_ROOT/tools/FlameGraph"
if [ -x "$FG/flamegraph.pl" ]; then
    echo "  FlameGraph already present at $FG"
else
    git clone --depth 1 https://github.com/brendangregg/FlameGraph.git "$FG" \
        || die "git clone failed -- check network and report"
    echo "  cloned to $FG"
fi
[ -x "$FG/stackcollapse-perf.pl" ] || chmod +x "$FG"/*.pl 2>/dev/null
command -v perl >/dev/null 2>&1 || warn "perl not found -- the FlameGraph scripts need it"

# ---------------------------------------------------------------------------
say "Recording the environment"

MANIFEST="$HWSW_ROOT/ENVIRONMENT.txt"
{
    echo "Environment captured: $(date)"
    echo "host/guest    : $(systemd-detect-virt 2>/dev/null)"
    echo "os            : $(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME")"
    echo "kernel        : $(uname -srm)"
    echo "cpu           : $(lscpu 2>/dev/null | awk -F: '/Model name/{gsub(/^ +/,"",$2);print $2}')"
    echo "vcpus         : $(nproc 2>/dev/null)"
    echo "python3       : $(python3 -VV 2>&1 | tr '\n' ' ')"
    echo "python3-dbg   : $(python3-dbg -VV 2>&1 | tr '\n' ' ')"
    echo "venv python   : $(python -VV 2>&1 | tr '\n' ' ')"
    echo "pyperformance : $(python -m pyperformance --version 2>&1 | head -1)"
    echo "perf          : $(perf --version 2>&1 | head -1)"
    echo "paranoid      : $(cat /proc/sys/kernel/perf_event_paranoid 2>/dev/null)"
    echo "max_sample_rate : $(cat /proc/sys/kernel/perf_event_max_sample_rate 2>/dev/null)"
    echo "flamegraph    : $FG"
    echo "project root  : $HWSW_ROOT"
} > "$MANIFEST"
cat "$MANIFEST"

say "SETUP COMPLETE"
cat <<EOF

  Project root : $HWSW_ROOT
  Activate with: source $VENV/bin/activate

  Recorded to  : $MANIFEST
                 (paste this into the report's methodology section verbatim --
                  do not retype environment facts from memory)

  Next: bash 02_baseline_nbody.sh

EOF
