# Specification Checklist

Derived from `Project.pdf` — *HWSW Project: Benchmark Optimization, Analysis, and
Hardware Acceleration Proposal*.

**`Project.pdf` is the authoritative source.** Where the reference project or any older
material disagrees, the current specification governs.

## Label key

| Label | Meaning |
|---|---|
| **REQUIRED** | Stated in `Project.pdf`. Mandatory. |
| **INFERRED** | Not stated; derived from the reference project or course tutorials. Plausible, unconfirmed. |
| **RECOMMENDED** | A suggestion from analysis. **Not a course requirement.** |
| **UNRESOLVED** | Ambiguous or contradictory in the source. Needs confirmation. |

---

## 1. Scope and gates

| ✓ | Item | Label | Detail |
|---|---|---|---|
| ☐ | Select exactly **2** benchmarks | REQUIRED | From the approved table only |
| ☐ | Achieve **≥ 7%** improvement | REQUIRED | "two or more benchmarks … at least 7% … will be considered sufficient" |
| ☐ | Both selected benchmarks clear 7% | INFERRED | The text says "two or more"; since exactly two are selected, both must clear it |
| ☐ | Upload everything to a **Git repository** | REQUIRED | |
| ☐ | Deliver a **20–25 minute presentation** | REQUIRED | Scheduled by course staff |
| ☐ | Handle **5–10 minutes of questions** | REQUIRED | |

### Approved benchmark table (as printed)

| Index | Name as printed |
|---|---|
| 1 | Raytrace |
| 2 | Deepcopy |
| 3 | Mdp |
| 4 | Pathlib |
| 5 | Pickle and pickle_dict |
| 6 | Pyflate |
| 7 | unpack_sequence |
| 8 | tornado_http |
| 9 | sqlite_synth |
| 10 | Nbody |
| 11 | Btree |
| 12 | deepblue |
| 13 | go |

The specification notes the ordering carries no meaning.

| ✓ | Item | Label | Detail |
|---|---|---|---|
| ☐ | Row 12 `deepblue` — confirm intended name | **UNRESOLVED** | No `deepblue` benchmark is documented upstream; `deltablue` is. Ask staff; confirm against the installed list via the audit |
| ☐ | Table says 13 rows, text says "10 benchmarks" | **UNRESOLVED** | Ask staff which governs |
| ☐ | `json_dumps` is absent from this list | REQUIRED | The reference project used it. It is **not** available for this project |

---

## 2. Instructions — the eight required activities

| ✓ | § | Activity | Label |
|---|---|---|---|
| ☐ | 1 | **Benchmark Analysis** — identify purpose and libraries; explore data structures and algorithms; dive into third-party dependencies where needed | REQUIRED |
| ☐ | 2 | **Understand pyperformance** — run the tests, capture results, interpret the data | REQUIRED |
| ☐ | 3 | **Generate a Flame Graph** — for *each* selected benchmark | REQUIRED |
| ☐ | 4 | **Detect Bottlenecks** — from flame graphs and profiling data | REQUIRED |
| ☐ | 5 | **Suggest Improvements** — backed by data showing reduced execution time or better memory efficiency | REQUIRED |
| ☐ | 6 | **Show Performance Improvements** — re-run after optimizing; compare concretely | REQUIRED |
| ☐ | 7 | **Propose Hardware Acceleration** — see §4 below | REQUIRED |
| ☐ | 8 | **Git Repository and Documentation** — see §5 below | REQUIRED |

---

## 3. Required files and names

| ✓ | File | Label | Notes |
|---|---|---|---|
| ☐ | `report_<name_of_benchmark>.txt` ×2 | REQUIRED | Exact naming pattern given in the spec |
| ☐ | `script_<name_of_benchmark>.sh` ×2 | REQUIRED | Exact naming pattern given in the spec |
| ☐ | `README.md` | REQUIRED | "explains the structure of the repository and provides instructions on how to run the scripts" |
| ☐ | `prompt.txt` **or** `prompt.docx` | REQUIRED | Prompts/instructions used with AI tools |
| ☐ | Additional files — Python scripts, performance logs, config files | REQUIRED to include *if created*; the category itself is "optional but encouraged" | Spec heading reads "HW Files and Additional Files (Optional but encouraged)" |
| ☐ | Place the four named files at the repository root | RECOMMENDED | Not stated; makes them trivially findable |
| ☐ | HDL source files | REQUIRED | §7 mandates an HDL implementation; the spec does not prescribe a filename or folder |

> **Note on the "HW Files" heading.** In the submission list, "HW" reads as *homework* —
> the description lists Python scripts, logs and config files, not hardware. This does
> **not** make the HDL optional: Instruction §7 mandates it independently.

---

## 4. Report contents — six required sections

Every `report_<name>.txt` must contain all six.

| ✓ | Section | Required contents | Label |
|---|---|---|---|
| ☐ | **Overview** | Description of the benchmark, libraries used, data structures employed | REQUIRED |
| ☐ | **Initial Analysis** | Performance analysis, flame graphs, profiling data | REQUIRED |
| ☐ | **Optimizations** | Description of improvements made, including any external libraries or algorithms used | REQUIRED |
| ☐ | **Performance Comparison** | Show how performance improved after optimizations | REQUIRED |
| ☐ | **Hardware Acceleration Proposal** | Proposed hardware solution with inputs, outputs, trade-offs, and a block diagram | REQUIRED |
| ☐ | **Conclusion** | Summarize the impact of the optimizations and hardware acceleration | REQUIRED |

Additions in `templates/report_TEMPLATE.txt` that are **RECOMMENDED, not required**:

- A *behaviour preservation* subsection per optimization (is the change bit-identical?).
- A *threats to validity* subsection (measurement noise, loop-count calibration,
  debug-build vs release-build).
- Recording optimizations that **failed**. The spec does not ask for this; it
  strengthens the analysis and is directly useful in Q&A.

---

## 5. Script contents — four required behaviours

Every `script_<name>.sh` must do all four.

| ✓ | Behaviour | Label |
|---|---|---|
| ☐ | Environment setup and dependency installation | REQUIRED |
| ☐ | Benchmark execution using pyperformance or other profiling tools | REQUIRED |
| ☐ | Flame graph and performance data generation | REQUIRED |
| ☐ | Post-optimization benchmark execution with performance comparison | REQUIRED |

| ✓ | Item | Label |
|---|---|---|
| ☐ | Script runs end-to-end from a clean clone | RECOMMENDED |
| ☐ | Fail fast on error rather than continuing silently | RECOMMENDED |
| ☐ | Do not require manual editing of paths before running | RECOMMENDED |

---

## 6. Hardware acceleration — seven required elements

| ✓ | Element | Required contents | Label |
|---|---|---|---|
| ☐ | **Hardware description** | Implement the accelerator in **Verilog, SystemVerilog, or PyXHDL**. Other HDLs or frameworks **only with prior instructor approval**. Must be a complete and logically consistent design | REQUIRED |
| ☐ | **Inputs and outputs** | Clearly defined inputs and outputs, including **data widths, interfaces, and expected operating frequency** | REQUIRED |
| ☐ | **Hardware architecture** | Internal logic and operation; must include the **main datapath and control logic** | REQUIRED |
| ☐ | **Hardware/software interface** | How the module interacts with existing software: software modifications, APIs, drivers, memory-mapped interfaces, DMA transfers, or communication protocols | REQUIRED |
| ☐ | **Acceleration justification** | Why this component is a good candidate; estimated performance improvement; assumptions discussed | REQUIRED |
| ☐ | **Block diagram** | The accelerator, its interfaces, and its integration into the overall system | REQUIRED |
| ☐ | **Performance/area/power trade-offs** | Expected trade-offs between performance, hardware complexity (area), operating frequency, and power | REQUIRED |

### Explicitly out of scope

| Item | Label |
|---|---|
| Synthesis | NOT required — "You are **not** expected to synthesize, fabricate, or physically test the hardware" |
| Fabrication | NOT required |
| Physical testing | NOT required |
| Production readiness / tape-out suitability | NOT required |

### Scope target

The design must be "sufficiently complete to define its functionality, interfaces,
operating frequency, and internal logic, accompanied by an explanation in the report."

| ✓ | Item | Label |
|---|---|---|
| ☐ | Write a testbench and simulate the design | **UNRESOLVED / RECOMMENDED** | Not mentioned in the spec. Simulation makes "logically consistent" demonstrable and is strong material for Q&A. Worth asking staff whether it is expected |

### Suggested acceleration directions (examples given in the spec, not requirements)

- Accelerating dictionary operations with specialized hardware.
- Speeding up decompression using custom hardware modules.
- ISA extensions that accelerate workloads without being too workload-specific
  (e.g. multiply-accumulate).
- Any other accelerator targeting a significant performance bottleneck.

---

## 7. Version control

| ✓ | Item | Label |
|---|---|---|
| ☐ | All project files uploaded to a Git repository | REQUIRED |
| ☐ | Clear commit messages demonstrating the development process | REQUIRED for the bonus |
| ☐ | Properly structured commits and a well-organized repository | **+5 bonus points** |
| ☐ | Commit incrementally from the start rather than in one final push | RECOMMENDED |

---

## 8. Presentation

| ✓ | Item | Label |
|---|---|---|
| ☐ | 20–25 minutes | REQUIRED |
| ☐ | Presented at a time scheduled by course staff | REQUIRED |
| ☐ | Structure follows the project flow: analysis → optimization → hardware proposal | REQUIRED ("The best structure … is to simply follow the flow of your project work") |
| ☐ | Prepared for 5–10 minutes of questions | REQUIRED |
| ☐ | Working code available to demonstrate and support explanations | REQUIRED |
| ☐ | **Do not** add all code to the presentation | REQUIRED |
| ☐ | Pitched at a fellow ECE student who did not do the project | REQUIRED |
| ☐ | Focus on teaching, guiding, and showing understanding | REQUIRED |
| ☐ | Rehearse against a timer | RECOMMENDED |

---

## 9. AI tool usage

| ✓ | Item | Label |
|---|---|---|
| ☐ | AI tools may be used | REQUIRED (permitted) |
| ☐ | Prompts or instructions used must be provided | REQUIRED |
| ☐ | AI used as an aid, not a substitute for your own analysis and work | REQUIRED |
| ☐ | Append to `prompt.txt` continuously rather than reconstructing at the end | RECOMMENDED |

---

## 10. Consolidated unresolved items

Every item here must be closed before the corresponding work is trusted.

| # | Question | Ask | Impact if wrong |
|---|---|---|---|
| 1 | Is `deepblue` (row 12) a typo for `deltablue`? | Staff + audit | Could select a benchmark that does not exist |
| 2 | Table lists 13 benchmarks, text says 10 — which governs? | Staff | Minor; affects nothing if the table is authoritative |
| 3 | One hardware proposal in total, or one per benchmark? | Staff | Doubles or halves the largest workload in the project |
| 4 | Is the 7% measured under `python3-dbg` or release `python3`? | Staff | The debug build has a different performance profile; an optimization can pass under one and fail under the other |
| 5 | Is HDL simulation expected, or is un-simulated HDL sufficient? | Staff | Determines whether a testbench is required work or optional polish |
| 6 | Does `deepcopy` expose one benchmark name or three? | Audit | Determines what "the benchmark" means for the 7% |
| 7 | Does the installed `pyperformance` support `--manifest`? | Audit | Determines how custom benchmark variants are registered |
| 8 | Do hardware PMU counters work inside the guest? | Audit | If unavailable, the counter analysis taught in the course cannot be reproduced |
