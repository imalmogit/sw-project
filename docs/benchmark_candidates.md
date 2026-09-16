# Benchmark Selection — DECIDED

**Revision 2 — 2026-09-16.** Revision 1 compared four candidates and deliberately left
the rubric unscored. The rubric is now scored against measured data and the pair is
chosen.

> # SELECTED: `pyflate` + `nbody`
>
> **`pyflate`** is the primary. It carries the hardware accelerator proposal.
> **`nbody`** is the second. It needs only to clear 7% and be analyzable.
>
> Course staff have ruled that **one** hardware accelerator is required for the
> project, not one per benchmark.

---

## 1. The measured basis for the decision

### Timing sweep — one harness run each, 2026-09-16

| Benchmark | Wall clock | Mean ± σ | Relative σ |
|---|---|---|---|
| deepcopy | 56 s | 18.2 µs ± 0.3 µs / 234 µs ± 2 µs | 1.6% / 0.9% |
| **nbody** | **71 s** | 479 ms ± 8 ms | 1.7% |
| raytrace | 193 s | 2.16 s ± 0.03 s | 1.4% |
| **pyflate** | **275 s** | 3.12 s ± 0.02 s | **0.64%** |

**All four are measurable.** Every relative σ sits far below the 7% threshold, so
measurability did not discriminate. What did discriminate was iteration cost, how
provable correctness is, and how tractable the hardware design is.

`-b deepcopy` runs the whole **deepcopy family** — two distinct means appear in one run.
This resolves the last open question from revision 1 about whether the 7% would apply to
one variant or several.

### Rubric, scored

| Criterion | W | nbody | raytrace | **pyflate** | deepcopy |
|---|---|---|---|---|---|
| 1 Measurability | ×1 | 4 | 5 | 5 | 4 |
| 2 Editable headroom | ×1 | 4 | 5 | 5 | 2 |
| 3 Confidence of ≥7% | ×2 | 4 | 5 | 5 | 2 |
| 4 Correctness provability | ×2 | 2 | 4 | **5** | 2 |
| 5 Hardware story | ×2 | 4 | 4 | **5** | 3 |
| 6 HDL tractability | ×1 | 3 | 2 | **5** | 3 |
| 7 Q&A defensibility | ×1 | 5 | 4 | 3 | 3 |
| 8 Profiling ergonomics | ×1 | 5 | 3 | 2 | 5 |
| 9 Independence from reference project | ×1 | 5 | 5 | 5 | 5 |
| **Weighted total** | **/60** | 46 | 50 | **55** | 36 |

---

## 2. `pyflate` — PRIMARY, carries the hardware proposal

**Status: not yet profiled.** Everything in this section below the first paragraph is
**[HYPOTHESIS]** until the baseline lands.

### What it computes

Decompresses a compressed archive using a **pure-Python implementation of the
compression format**, then verifies the result against a built-in checksum. Because the
decompressor is Python rather than a C library, essentially all runtime sits in code you
may edit.

### Algorithms and data structures

Bit-level stream reading, a few bits at a time. Huffman decoding — walking a code tree
bit by bit per symbol. Move-to-front and run-length decoding. An inverse Burrows–Wheeler
transform. Final checksum verification.

Bitfield reader classes tracking a bit position in both bit orders; Huffman table objects
built from code-length specifications; large intermediate lists during the inverse
transform.

### Hypothesized hotspots — untested

| ID | Hypothesis | Basis |
|---|---|---|
| P1 | Bit reading and per-symbol Huffman resolution dominate | Invoked once per bit or per symbol across the whole stream. Leading hypothesis by a wide margin |
| P2 | The inverse BWT stage is the memory-heavy phase | Builds large intermediate lists |
| P3 | Huffman table construction and traversal is significant | |
| P4 | Per-symbol integer object allocation accumulates | Consistent with what nbody's profile showed about boxing |

### Correctness strategy — the reason it was chosen

The benchmark **verifies its own output against a checksum**. Reproduce the checksum and
correctness is *demonstrated*, not argued. An independent cross-check against the
standard library's compiled decompressor for the same format gives a second, unrelated
oracle.

For a project graded partly on demonstrated understanding, this is a material advantage
over every other candidate.

### Planned optimizations — all behaviour-preserving

| Optimization | Targets | Why it preserves behaviour |
|---|---|---|
| Bulk bit reading — fetch a machine word and mask | P1 | Consumes exactly the same bits |
| Table-driven Huffman decode keyed on the next *N* bits | P1, P3 | Textbook equivalence to the tree walk |
| Byte/array buffers instead of lists of integers | P2, P4 | Same values, different container |
| Local-variable binding in hot loops | P1 | Name resolution only |
| Compile the bit reader to C-level types | P1 | Integer arithmetic is exact |

### Hardware target

The specification explicitly names *"speeding up decompression using custom hardware
modules"* among its approved examples.

**Huffman decoder / variable-length bit unpacker** — barrel shifter, bit accumulator,
canonical-code lookup table, control FSM. An integer datapath with a small state machine
is far more tractable in HDL than a floating-point pipeline, and yields a complete,
simulatable design at the right scope.

### Risks

- **Iteration cost.** 275 s per harness run; the full perf pipeline is ~50 min per
  variant. Mitigation: use the fast loop (harness + `compare`, ~5 min) for experiments and
  reserve the full pipeline for baseline and final.
- **DWARF profile size.** At `-F 199`, ~55,000 samples × ~8 KB ≈ 440 MB. Lower `-F` for
  this benchmark; keep it identical between baseline and variants.
- **Comprehension cost.** Optimizing a decompressor properly means understanding the
  container format. That cost is partly the point — Instruction §1 asks for exactly this
  depth — but budget for it.

### Constants to confirm from the installed source

Data filename and location; which compression format is actually exercised; the
verification checksum; the file size.

---

## 3. `nbody` — SECOND, profiled

**Status: profiled 2026-09-16.** 51,705 samples on `cpu-clock`. This section reports
measurement, not hypothesis.

### What it computes

Gravitational motion of a small fixed set of solar-system bodies over many discrete
timesteps, reporting total system energy before and after. Naive all-pairs integration;
positions and velocities are mutable lists updated in place.

### Measured profile

Shared object `python3.10d` — the debug build, as staff require.

| Symbol | Self % | What it is |
|---|---|---|
| `_PyEval_EvalFrameDefault` | **37.18%** | the bytecode interpreter loop |
| `binary_op1` + `binary_iop1` | 5.92% | generic operator dispatch |
| `PyFloat_FromDouble` + `float_dealloc` | 6.20% | **allocating and freeing float objects** |
| list indexing machinery¹ | ~6.9% | `list_ass_item`, `list_ass_subscript`, `list_subscript`, `PyNumber_AsSsize_t`, `PyObject_SetItem` |
| `float_mul` + `float_add` + `float_sub` | 6.06% | boxed float arithmetic |
| `__ieee754_pow_fma` | 1.37% | the fractional-power term |
| `_Py_CheckSlotResult` | 1.80% | **debug-build-only assertion** |

¹ sum of the listed symbols.

### Hypotheses, tested

| ID | Prediction | Verdict |
|---|---|---|
| H1 | Interpreter object machinery dominates | **CONFIRMED.** ~56% across the loop, dispatch, boxing and indexing. 6.2% is *just* float alloc/free |
| H2 | The fractional-power term is the most expensive single operation | **REFUTED.** 1.37%. The `pow` is nearly free; the expense was the interpreter around it |
| H3 | List subscripting is significant | **CONFIRMED, and larger than expected** at ~6.9% — enough to make lifting list elements into scalar locals a real optimization, not a micro-tweak |

### The Amdahl bound that shapes the hardware proposal

Everything a floating-point accelerator could touch — `float_mul` + `float_add` +
`float_sub` + `pow` — totals **7.43%**.

Make all of it instantaneous, with zero invocation overhead, and the ceiling is
**1.080×**. A pure FP accelerator could not reliably clear the project's own 7% bar even
in the impossible best case.

This is the quantified justification §7 asks for under *"estimate the expected
performance improvement and discuss any assumptions used"* — and it is the measured
refutation of the intuitive "add a multiply-accumulate unit" answer. It points any
accelerator at **object handling**, not arithmetic.

### Planned optimizations

| Optimization | Targets | Bit-identical? |
|---|---|---|
| Lift list elements to scalar locals, write back once | H3 (~6.9%) | Expected yes |
| Bind global/attribute lookups to locals | H1 | Expected yes |
| Unpack pair tuples once outside the loop | H1 | Expected yes |
| Algebraically rewrite the power term | H2 (1.37% — low value) | **No** |
| Compile the inner loop with typed C-level variables | H1 | **No** — library math may differ |

### Correctness strategy

Compare reported energy against the unmodified benchmark with identical parameters,
within a **stated numeric tolerance**. Label each optimization bit-exact or not. The
specification does not require bit-exactness, but claiming "behaviour is preserved"
without defining it invites exactly the question the Q&A is designed to ask.

### Why it was chosen as the second benchmark

1. **Already profiled** — 51K samples, three hypotheses tested, Amdahl analysis done.
2. **Cheapest to iterate on** — 71 s per run versus pyflate's 275 s. Pairing two slow
   benchmarks would have left nothing quick to experiment with.
3. **A different bottleneck in kind** — floating-point object churn versus bit-level
   integer streaming. Two genuinely distinct analyses, and a richer presentation.

---

## 4. Why the other two were rejected

### `raytrace` — scored 50/60, a legitimate second choice

Strong on optimization surface (`__slots__`, local binding, object reuse) and on
correctness: it writes an image, so byte-exact comparison proves behaviour trivially.

Rejected because pyflate already supplies a bulletproof correctness story, its 193 s
runtime is a real cost on one vCPU, and the "one accelerator" ruling removed its main
advantage — the ray–sphere intersection unit was its strongest card, and the project no
longer needs a second accelerator.

### `deepcopy` — scored 36/60, clearly last

The hot code is **stdlib `copy`**, which should not be modified, so the optimization
surface is narrow and any change risks no longer measuring the same benchmark. Its
aliasing semantics — shared references must stay shared, cycles must not recurse — are
the hardest of the four to verify convincingly. And pointer-chasing with recursive
dispatch is the least accelerator-friendly workload shape.

Fastest to run (56 s), and that is its only clear advantage.

---

## 5. Remaining unknowns

| # | Unknown | Resolved by |
|---|---|---|
| 1 | Every pyflate hotspot hypothesis P1–P4 | The pyflate baseline profile |
| 2 | pyflate's constants — data file, format, checksum | Reading the installed source |
| 3 | Whether HDL simulation is expected | Course staff — **still unanswered** |
| 4 | Whether bulk bit reading alone clears 7% | Implementation |

---

## 6. What happens next

1. Baseline **nbody** with the corrected script — grouped counters, DWARF stacks. ~14 min.
   Running it first validates the script changes cheaply.
2. Baseline **pyflate** at a lower sampling frequency. ~50 min.
3. Custom benchmark plumbing — an identical copy under a new name, registered via
   `--manifest`, before any optimization.
4. Optimize each to ≥7%, using the fast loop.
5. Design, write and check the Huffman-decoder accelerator in HDL.

**Workflow rule:** the full perf pipeline runs only on a benchmark's **baseline** and its
**final chosen variant**. Every experiment in between uses
`pyperformance run -o x.json` plus `pyperformance compare`. The perf data explains *why*;
the harness figure proves *whether*.
