# Project Handoff — HW/SW Co-design Final Project

**Course:** נ.נ. בתכנון משולב חומרה/תוכנה (00460882) · Final Project = **75%** of the course grade
**Package version:** v2 · 2026-09-08

---

## ⚠ STATUS — READ FIRST

> **This is a planning and analysis package. It is not code.**
>
> - **No implementation has been written.** No optimized benchmarks, no execution
>   scripts, no HDL.
> - **No benchmark has been executed.** There are no measurements anywhere in this
>   package, by design.
> - **No benchmark pair has been selected.**
> - **The project is not runnable from this package alone.** Nothing here produces a
>   result. It tells you what to build, what to check, and what is still unknown.
>
> **Next technical milestone:** run the environment audit, then perform **one original
> baseline run** of a single candidate benchmark. Everything after that depends on
> what those two steps return.

---

## 1. What the project requires

Select **exactly 2 benchmarks** from the approved list in `Project.pdf`. For each:

1. **Analyze** it — purpose, libraries, data structures, algorithms.
2. **Profile** it with `perf` in the course VM, and produce a **flame graph**.
3. **Optimize** it to **≥ 7% improvement**, backed by data.
4. **Propose and implement in HDL** an accelerator for one bottleneck — Verilog,
   SystemVerilog, or PyXHDL. Synthesis and physical test are *not* required; a
   complete, logically consistent design *is*.

Package it in Git with per-benchmark reports and scripts, a README, and an AI prompt
log. Present for 20–25 min, then 5–10 min of questions.

→ Itemized checklist: **`docs/spec_checklist.md`**

---

## 2. What's in this package

| File | What it gives you |
|---|---|
| `HANDOFF.md` | This page |
| `docs/spec_checklist.md` | Every requirement, tagged REQUIRED / INFERRED / RECOMMENDED / UNRESOLVED |
| `docs/benchmark_candidates.md` | Four candidates compared; hotspots labelled as hypotheses; selection rubric, **unscored** |
| `docs/environment_notes.md` | The four VM documents compared; conflicts documented, **not resolved** |
| `templates/report_TEMPLATE.txt` | All six required report sections, with placeholders |
| `templates/README_TEMPLATE.md` | README skeleton, placeholders only |
| `scripts/vm_audit_minimal.sh` | Minimal **non-destructive** environment audit — written, not yet run |
| `prompt.txt` | AI prompt log — **in progress and incomplete** |
| `.gitignore` | Ignores regenerable output; keeps deliverables and source |

---

## 3. Settled by the specification

- Exactly **2** benchmarks, from the approved table.
- **≥ 7%** improvement threshold.
- Required filenames: `report_<name>.txt`, `script_<name>.sh`, `README.md`,
  `prompt.txt`.
- Six mandatory report sections; four mandatory script behaviours; seven mandatory
  hardware-proposal elements.
- HDL: **Verilog, SystemVerilog, or PyXHDL**. Anything else needs prior instructor
  approval.
- Synthesis, fabrication and physical testing are **not** expected.
- Presentation 20–25 min + 5–10 min Q&A. Do **not** put all code in the slides.
- AI use is permitted and encouraged; prompts must be submitted.
- Clean commit history: **+5 bonus**.
- `json_dumps` — used by the reference project — is **not** on this year's list.

---

## 4. Still unverified

Nothing below may enter a report until confirmed.

**Environment** — which VM procedure is current (the four documents conflict; see
`docs/environment_notes.md`); whether hardware performance counters work in the guest
(**highest-impact unknown**); OS and Python versions; whether `python3-dbg` is a real
debug build; harness version; whether flame-graph or HDL tooling already exists; what
the partner has already built.

**Benchmark facts** — the authoritative benchmark-name list for the installed version;
whether `deepcopy` exposes one name or three; every numeric constant. **None are
recorded as fact in this package.**

**Course staff** — is `deepblue` a typo for `deltablue`? One hardware proposal or two?
Is the 7% measured under `python3-dbg` or release `python3`? Is HDL simulation
expected? Table says 13 benchmarks, text says 10 — which governs?

---

## 5. Next five steps

1. **Run `scripts/vm_audit_minimal.sh`** in the working VM. Non-destructive: it writes
   one file, `vm_audit_<date>.txt`, and runs `perf stat` on `/bin/true`. Return that
   file unedited — error lines are findings.

2. **Debrief the partner** on the real commands they use, and what already exists in
   the VM. Questions in `docs/environment_notes.md` §6. This is what settles the
   guide conflict.

3. **Send the five questions to course staff.** All five change scope; all are cheap
   now and expensive later.

4. **Perform one original baseline run** of a single candidate — unmodified, no
   optimization — to establish that the measurement pipeline works end to end and to
   see real noise levels.

5. **Score the rubric** in `docs/benchmark_candidates.md` §8 from real profiles, then
   select the pair. Not before.

---

## 6. Done vs. still to do

**Done — reviewable now, no VM needed:** specification decomposed and labelled; four
candidates compared; selection rubric defined (unscored); report and README templates;
audit script; prompt log started.

**To do — blocked in this order:**

| Phase | Blocked on |
|---|---|
| Confirm environment baseline | Audit output |
| Correct anything the VM contradicts | Audit output |
| One original baseline run | Working environment |
| Baseline-profile candidates | Pipeline proven |
| Score rubric, select pair | Baseline profiles |
| Build custom benchmark variants | Pair selected |
| Optimize to ≥ 7% | Variants in place |
| Design, write and check HDL | Measured hotspot |
| Write reports | Measurements complete |
| Build presentation | Reports complete |

---

## 7. How to read this package

| Label | Meaning |
|---|---|
| **[REQUIRED]** | Stated in `Project.pdf`. Not optional. |
| **[INFERRED]** | From the reference project or course materials. Plausible, unconfirmed. |
| **[RECOMMENDED]** | A suggestion. **Not** a course requirement. |
| **[UNRESOLVED]** | Genuinely unknown. Confirm before use. |
| **[HYPOTHESIS]** | A profiling prediction. Must be tested; may prove wrong. |

**Governing rule:** the current specification and course staff govern the project
requirements. The working VM is the source of truth only for the installed environment
and available tools.
