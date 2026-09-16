# Environment Notes

**Revision 2 — 2026-09-16.** Supersedes revision 1. All conflicts that revision 1 left
open are now closed by direct evidence or by course staff.

**Governing rule:**

> The current specification and course staff govern the project requirements. The
> working VM is the source of truth only for the installed environment and available
> tools.

---

## 1. The environment, as measured

Every line below was read off the machine, not inferred. Source: `vm_audit`
(2026-09-12), `preflight` (2026-09-12), and the baseline runs (2026-09-12 → 09-16).

| Fact | Value |
|---|---|
| Host | `naranja4`, account `ece882-025`, working dir `/scratch/ece882-025` |
| Guest | QEMU/KVM — `systemd-detect-virt: kvm`, QEMU firmware, hypervisor flag present |
| Host QEMU build | Ubuntu 24.04 (from the machine-type string) — **inferred, not confirmed** |
| Guest OS | Ubuntu 22.04.5 LTS (Jammy) |
| Guest kernel | `5.15.0-1106-kvm` (was `-1103-` before a reboot on ~09-13) |
| CPU | Intel Xeon E5-2630 v3 @ 2.40 GHz, **1 vCPU** |
| Reported cache | L1d/L1i 32 KiB, L2 4 MiB, L3 16 MiB — **synthesized by QEMU, not physical** |
| RAM | 3.8 GiB, **no swap** |
| Disk | 22 GB total, ~19 GB free |
| Privilege | **root** (uid 0) |
| Python (release) | 3.10.12 |
| Python (debug) | 3.10.12, `Py_DEBUG=1`, `abiflags='d'`, `sys.gettotalrefcount` present |
| Harness | pyperformance 1.14.0 — **80 runnable benchmarks** on this interpreter |
| Profiler | perf 5.15.200, from `/usr/lib/linux-kvm-tools-5.15.0-1103` |
| `perf_event_paranoid` | 4 — blocks unprivileged `perf_event_open`; we run as root |
| `perf_event_max_sample_rate` | 100000 — no change needed |
| Project root | `/root/sw-project` (`export HWSW_ROOT=/root/sw-project`) |

### Two facts that constrain everything

**One vCPU.** No parallelism-based optimizations. `--affinity` is meaningless. Any other
process competes directly with the benchmark — this is not theoretical: two overlapping
script runs produced a clean 2.02× measurement artifact on 2026-09-12. **Never run
anything else on the VM while measuring.**

**Reported cache sizes are fabricated by the hypervisor.** The guest reports 4 MiB L2
and 16 MiB L3; a physical E5-2630 v3 has 256 KB L2 per core and 20 MB L3. Cite measured
miss *counts* and *ratios* in the report. Never build an argument on cache *capacity*.

---

## 2. Three measurement quirks — all verified by experiment

These are report material, not troubleshooting notes. Each has an experiment behind it.

### 2.1 PMU counting works; PMU sampling does not

| Mode | Tool | Result |
|---|---|---|
| Counting | `perf stat` | ✅ real values for cycles, instructions, cache, branches |
| Sampling | `perf record -e cycles` | ❌ 0.003 MB, *"data has no samples!"* |
| Sampling | `perf record -e cpu-clock` | ✅ 0.718 MB, **10,430 samples** |

Same workload, same machine, one flag different. The virtualised PMU does not deliver
the interrupt that sampling depends on; counting only reads counters at start and end.

**Consequence for the report:** profiles are sampled on `cpu-clock`, a timer-driven
software event. **The flame graph shows where TIME goes, not where CYCLES go.** State
this. Those differ when stalls are unevenly distributed.

### 2.2 Requesting many counters at once silently zeroes one

Asking for nine events in one pass multiplexes them on this vPMU. Whichever event loses
the rotation reports a flat `0` with **no scaling annotation to warn you**.

Proof that it is multiplexing and not an unsupported event: **the victim moves.** One
run reported `cycles = 0`; another, with the identical event list, reported
`branch-misses = 0`. `dmesg` confirms a working driver: *"Performance Events: Haswell
events, full-width counters, Intel PMU driver."*

**Fix in use:** three small passes instead of one large one —

```
group 1 : task-clock,context-switches,page-faults,cycles,instructions
group 2 : cache-references,cache-misses
group 3 : branches,branch-misses
```

Group 1 carries the software events plus the two fixed-counter events, so IPC always
comes from one clean pass. Costs 3× the wall clock; returns numbers that are true.

### 2.3 Frame-pointer unwinding produces fictional CPython stacks

With the default `-g`, stacks came back with addresses like `0x300380014147c` appearing
as the **parent** of `float_mul` — perf misreading Python's value stack as return
addresses. The rendered flame graph was a single meaningless 600-pixel needle.

`--call-graph dwarf` uses the debug info in `python3.10d` and produces correct stacks:
`_PyEval_EvalFrameDefault` recursing into itself, which is what a Python call chain
actually looks like.

**Self% was correct all along; only the tree was fiction** — the frame-pointer run and
the DWARF run agree on `_PyEval_EvalFrameDefault` self time to within one point
(37.18% vs 36.77%).

**Cost:** DWARF copies ~8 KB of stack per sample (measured: 19.6 MB for 2,434 samples).
Sampling frequency is lowered to compensate. **Keep `-F` identical between a benchmark's
baseline and its optimized variants**; it may differ between benchmarks.

---

## 3. VM access — RESOLVED

Revision 1 documented three open conflicts between four guides. All are now closed.

**Direct evidence:** the shell prompt `ece882-025@naranja4:/scratch/ece882-025`.

**Course staff:** confirmed the current setup is correct.

| Conflict (rev. 1) | Resolution |
|---|---|
| A — where QEMU runs | **On the assigned server**, from `/scratch/<account>`. Not copied to a local machine. |
| B — `tangerine` vs `naranja` | **`naranja`**, assigned per account. `tangerine` is the 2025 infrastructure. |
| C — image source path | **`/scratch/ece882-025`** — the account's own directory, per the per-account scheme. |
| D — build on host or guest | **In the guest.** |

The operative document is **`qemu-vm-guide.pdf` (May 2026)**.

**The setup page in `Project.pdf` (August 2026) is stale.** It instructs copying the
image to a local machine, which is not the current procedure, and its worked example
profiles a benchmark that is not on this project's approved list. Worth mentioning to
staff; it will mislead the next cohort.

---

## 4. Course staff rulings

| Question | Ruling | Effect |
|---|---|---|
| One hardware proposal or two? | **One component, total** | One accelerator for the project, not one per benchmark |
| `python3-dbg` or release for the 7%? | **`python3-dbg`** | Confirms current practice; all figures come from the debug build |
| VM procedure | Current setup is correct | §3 above |
| `btree` / `deepblue` | Not needed, since only 2 are chosen | Moot — see note below |
| **Is HDL simulation expected?** | **STILL UNANSWERED** | Determines whether a testbench is required work or optional polish |

**On the approved table**, for the record: `btree` (row 11) does not exist in
pyperformance 1.14.0 — not in the 97-benchmark manifest, not in any tag group. `deepblue`
(row 12) is `deltablue`. Neither affects us.

---

## 5. Operational rules

1. **`export HWSW_ROOT=/root/sw-project`** — set in `~/.bashrc`. Everything lives there.
2. **Always launch scripts from `/root/sw-project/baseline/scripts`.** pyperformance
   builds its internal venv relative to the working directory; launching elsewhere
   rebuilds it from scratch.
3. **Use `tmux`.** Long runs survive a dropped connection, and it prevents the
   duplicate-launch mistake that caused the 2.02× artifact.
4. **Nothing else runs on the VM during a measurement.** One vCPU.
5. **A reboot invalidates `ENVIRONMENT.txt`.** The kernel changed `-1103-` → `-1106-`
   on ~09-13, and `kptr_restrict` resets. Regenerate with
   `HWSW_ROOT=/root/sw-project bash .../01_setup.sh --yes` before quoting it in a report.
6. **Never move a virtualenv.** Absolute paths are baked into `pyvenv.cfg` and every
   shebang. Rebuild instead.

---

## 6. Known limitations to record in the report

- Profiles are time-based (`cpu-clock`), not cycle-based. §2.1.
- Kernel symbols do not resolve (`kptr_restrict`); kernel frames appear as hex. Cosmetic
  for user-space Python profiling, and it resets on every reboot.
- All figures are from a **debug build** of CPython, per staff ruling. `_Py_CheckSlotResult`
  appears at ~1.8% of runtime and exists only in debug builds — the performance
  distribution differs from release Python.
- `perf stat` measures the **entire harness process**, including its venv setup and
  calibration, not the benchmark alone. Use it for context; take the improvement figure
  from pyperf's own mean ± stddev.
- Guest cache topology is synthesized. §1.

---

## 7. Still open

1. **Is HDL simulation expected?** One line to staff.
2. Host QEMU being Ubuntu 24.04 is inferred from a machine-type string, not confirmed.
   Harmless either way.
