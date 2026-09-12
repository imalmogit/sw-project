# Benchmark Candidate Comparison

Candidates under consideration: **`nbody`**, **`raytrace`**, **`pyflate`**, **`deepcopy`**.

> ## Read this first
>
> **No benchmark has been profiled.** Every hotspot statement in this document is a
> **[HYPOTHESIS]** — a prediction to be tested against a flame graph, and one that may
> turn out to be wrong.
>
> **No numeric constants are recorded as fact.** Default iteration counts, image
> dimensions, data filenames and checksums vary between `pyperformance` versions. Each
> benchmark section ends with a *Constants to confirm* list naming what must be read
> off the installed source before it can be cited. Structural descriptions below come
> from the upstream `python/pyperformance` sources and are themselves
> **[UNVERIFIED]** against the VM's installed version.
>
> **No pair has been selected.** The rubric in §8 is deliberately unscored.

---

## 1. Side-by-side summary

| | **nbody** | **raytrace** | **pyflate** | **deepcopy** |
|---|---|---|---|---|
| Domain | Physics integration | Computer graphics | Data decompression | Object copying |
| Numeric character | Floating point | Floating point | Integer / bit-level | None (pointer work) |
| Hot code is pure Python? | Yes | Yes | Yes | **No** — hot code is stdlib `copy` |
| May you legally edit the hot code? | Yes | Yes | Yes | **Largely no** |
| Working-set size | Very small | Small | Moderate–large | Moderate |
| Correctness provable? | Weak — FP tolerance | **Strong** — image comparison | **Strongest** — self-checksum | Hard — aliasing semantics |
| Spec names a matching HW example? | Partly (multiply-accumulate) | No | **Yes** (decompression) | **Yes** (dictionary operations) |
| HDL tractability | Medium | Medium–hard | **High** | Low |
| Comprehension cost | Low | Medium | **High** | Medium |
| Overlaps reference project? | No | No | No | No |
| Expected overall difficulty | Low–medium | Medium | Medium–high | High |

---

## 2. nbody

**Expected difficulty: low–medium.**

### Purpose

Simulates the gravitational motion of a small fixed set of solar-system bodies over
many discrete timesteps. Total system energy is reported before and after; because
energy should be nearly conserved, the reported values double as a built-in sanity
check. Originates from the Computer Language Benchmarks Game.

### Algorithms

Naive all-pairs gravitational integration — for every distinct pair of bodies, compute
the separation, derive an acceleration magnitude, and update both bodies' velocities;
then advance all positions. Cost grows with the square of the body count. Pair
enumeration is precomputed once rather than recomputed per step.

### Data structures

- A dictionary mapping body name to a grouping of position, velocity, and mass.
- A list of those groupings, forming the simulated system.
- A precomputed list of body pairs.
- **Positions and velocities are mutable lists, updated in place** — this matters for
  optimization, because in-place mutation constrains what can be safely hoisted.

### Likely hotspots — all [HYPOTHESIS]

| ID | Hypothesis | Reasoning |
|---|---|---|
| H1 | Interpreter object machinery dominates | Each arithmetic operation dispatches a bytecode, unboxes two float objects, performs one hardware operation, then **allocates a new float object** and adjusts reference counts. This is expected to exceed the cost of the arithmetic itself by a wide margin |
| H2 | The fractional-power term is the most expensive single operation in the loop | It is a general power call, not a multiply |
| H3 | List subscripting is significant | Bounds-checked, with reference-count traffic on every access |
| H4 | Per-iteration tuple unpacking of each pair adds measurable overhead | |

**If H1 holds, it reframes the whole hardware discussion** — see *Hardware targets*.

### Correctness strategy

Compare the reported energy values from the unmodified benchmark against each variant,
run with identical parameters.

**The floating-point trap.** "Identical behaviour" for FP means *bit-identical*. Any
reassociation of operations changes the low-order bits.

- *Expected to be bit-identical:* hoisting lookups into locals; unpacking pairs once
  outside the loop; lifting list elements into scalar locals and writing back at the
  end.
- *Not bit-identical:* algebraic rewriting of the power term; compiling to C where the
  library math function differs; anything vectorized.

Recommended handling: state a numeric tolerance explicitly in the report, and label
each optimization as bit-exact or not. **[RECOMMENDED]** — the specification does not
require bit-exactness, but claiming an optimization "preserves behaviour" without
saying what that means invites exactly the kind of question the Q&A is designed to ask.

### Possible software optimizations

| Optimization | Bit-identical? | Targets |
|---|---|---|
| Bind global/attribute lookups to locals | Expected yes | H1 partially |
| Unpack pair tuples once outside the loop | Expected yes | H4 |
| Lift list elements to scalar locals, write back once | Expected yes | H3 |
| Algebraically rewrite the power term | **No** | H2 |
| Compile the inner loop with typed C-level variables | **No** (library math may differ) | H1, H2 |

### Possible hardware targets — all [HYPOTHESIS]

| Candidate | Assessment |
|---|---|
| Generic FP multiply-accumulate unit | **Weak unless profiling contradicts H1.** If the interpreter dominates, a faster multiplier accelerates a small share of cycles and Amdahl's law caps the benefit near zero. Do not propose this without profile evidence |
| Reciprocal-square-root unit for the power term | Narrow, targets H2 directly, is a real hardware primitive, and is small and clean to express in HDL |
| Unboxed-state pairwise-update engine | Takes a pointer to a packed array of body state and runs the update sequence in hardware, bypassing the interpreter. The honest justification is elimination of interpreter overhead, not faster arithmetic. Strongest option **if H1 is confirmed** |

### Risks

- Very small working set — memory-hierarchy arguments will not survive scrutiny.
- The most attractive optimizations conflict with bit-exact reproducibility.
- Lowest comprehension cost of the four, which also means the least to say in a 20–25
  minute presentation.

### Constants to confirm before citing

Default iteration count; default reference body; the exact set and number of simulated
bodies; the printed precision of the energy output.

---

## 3. raytrace

**Expected difficulty: medium.**

### Purpose

Renders an image of a synthetic 3D scene by casting one ray per pixel, finding the
nearest object intersection, and shading it — including shadow rays toward the light
sources. Pure Python, no external numeric libraries.

### Algorithms

Classic recursive ray tracing with **no spatial acceleration structure**: every ray is
tested linearly against every object in the scene. Sphere intersection solves a
quadratic; plane intersection is a half-space test. Shading combines surface colour
with visibility tests against each light.

### Data structures

- Vector and Point classes with operator overloads (addition, subtraction) and geometric
  methods (dot, cross, normalize, magnitude, scale, reflect).
- Ray objects pairing an origin point with a direction vector.
- Scene objects (spheres, a half-space plane) each paired with a surface description.
- A canvas accumulating pixel values, writable to an image file.
- **[UNVERIFIED]** whether the geometry classes declare `__slots__`. If they do not,
  each instance carries a dictionary — which is the basis of H2 below.

### Likely hotspots — all [HYPOTHESIS]

| ID | Hypothesis | Reasoning |
|---|---|---|
| H1 | Vector/Point allocation churn is the primary cost | Every subtraction, scale and normalize constructs a new Python object. Across pixels × objects × shadow rays this compounds sharply |
| H2 | Attribute lookup is significant | Per-instance dictionary lookups on every coordinate access, if `__slots__` is absent |
| H3 | Intersection testing scales as pixels × objects | Linear scan, no acceleration structure |
| H4 | Square-root evaluation in magnitude/normalize | |
| H5 | Method dispatch through the operator overloads | |

### Correctness strategy — the strongest of the FP candidates

The benchmark writes a rendered image. Render with the original and with each variant,
then compare the output files byte-for-byte. **Identical image ⇒ identical behaviour**,
verifiable with a single command and demonstrable live during the presentation.

Caveat: pixel values are quantized to bytes, so sub-threshold floating-point
differences can hide. If the arithmetic is altered, supplement with a float-level
comparison before quantization.

### Possible software optimizations

| Optimization | Behaviour-preserving? | Targets |
|---|---|---|
| Declare `__slots__` on the geometry classes | Yes — removes the instance dict without changing semantics | H2 |
| Bind coordinates to locals at the top of hot methods | Yes | H2 |
| Bind the square-root function to a module-level local | Yes | H4 |
| Collapse short-lived intermediate objects into scalar arithmetic where they never escape | Yes, if operation order is preserved | H1 |
| Eliminate genuinely redundant repeated normalizations | Yes, if provably redundant | H4 |
| Compile the geometry class with typed C-level fields | Order-preserving but library-dependent | H1, H2 |

### Possible hardware targets — all [HYPOTHESIS]

| Candidate | Assessment |
|---|---|
| Ray–sphere intersection unit | Dot products → discriminant → square root → nearest-root select. Mirrors ray-tracing units in shipping commercial GPUs, so prior art can be cited — a real asset in Q&A |
| Three-wide dot-product / normalize unit with a reciprocal-square-root stage | Smaller and simpler; less distinctive |

Same caveat as nbody: the achievable win depends on how much runtime is genuine
arithmetic versus interpreter overhead. **Let the flame graph decide.**

### Risks

- Likely the slowest of the four to run, so each profiling cycle is long.
- Deep call graph produces a tall flame graph. Legible, but distinguishing *self* from
  *children* overhead requires care (see course tutorial 01 on call chains).
- The specification does not name graphics acceleration among its examples — this is
  not disqualifying, but the connection must be argued rather than pointed at.

### Constants to confirm before citing

Default image width and height; the number and arrangement of scene objects; number of
lights; whether an output-filename option exists (the byte-comparison correctness
strategy depends on it).

---

## 4. pyflate

**Expected difficulty: medium–high.**

### Purpose

Decompresses a compressed archive using a **pure-Python implementation of the
compression format**, then verifies the decompressed result against a built-in
checksum. Because the decompressor is written in Python rather than calling a C
library, essentially all of the runtime is in code you may edit.

### Algorithms

- Bit-level stream reading, consuming the input a few bits at a time.
- Huffman decoding — walking a code tree bit by bit to resolve each symbol.
- Move-to-front decoding and run-length decoding.
- An inverse Burrows–Wheeler transform.
- A final checksum verification of the reconstructed output.

### Data structures

- Bitfield reader classes maintaining a bit position over the input buffer, in both
  bit orders.
- Huffman table objects built from code-length specifications, plus per-code length
  records.
- Large intermediate lists during the inverse transform stage.

### Likely hotspots — all [HYPOTHESIS]

| ID | Hypothesis | Reasoning |
|---|---|---|
| H1 | Bit reading and per-symbol Huffman resolution dominate | Invoked once per bit or per symbol across the entire stream. Leading hypothesis by a wide margin |
| H2 | The inverse Burrows–Wheeler stage is the memory-heavy phase | Builds large intermediate lists |
| H3 | Huffman table construction and traversal is significant | |
| H4 | Per-symbol integer object allocation adds up | |

### Correctness strategy — the strongest of all four candidates

The benchmark **verifies its own output against a checksum**. If an optimized variant
reproduces the same checksum, correctness is *demonstrated*, not argued. An independent
cross-check against the standard library's compiled decompressor for the same format
provides a second, unrelated oracle.

For a project where you will be questioned on whether an optimization is legitimate,
this is a material advantage over the other three candidates.

### Possible software optimizations

| Optimization | Behaviour-preserving? | Targets |
|---|---|---|
| Bulk bit reading — fetch a machine word and mask, rather than bit-by-bit | Yes — consumes exactly the same bits | H1 |
| Table-driven Huffman decode — precompute a lookup keyed on the next *N* bits, replacing the tree walk | Yes — a textbook equivalence | H1, H3 |
| Use byte/array buffers instead of lists of integers where semantics allow | Yes | H2, H4 |
| Bind lookups to locals in the hot loops | Yes | H1 |
| Compile the bit reader to C-level types | Yes for integer arithmetic | H1 |

Both leading optimizations are standard, well-documented techniques with clear
mechanisms — which makes them straightforward to explain and defend.

### Possible hardware target — the cleanest match to the specification

The specification explicitly names *"Speeding up decompression using custom hardware
modules"* among its approved examples.

| Candidate | Assessment |
|---|---|
| Huffman decoder / variable-length bit unpacker | Barrel shifter + bit accumulator + canonical-code lookup + control FSM. An integer datapath with a small state machine is **substantially more tractable in HDL** than a floating-point pipeline, and yields a complete, simulatable design at the right scope for a course project |
| Inverse Burrows–Wheeler transform unit | Plausible secondary option; more memory-bound |

### Risks

- **Highest comprehension cost of the four.** Optimizing a decompressor properly means
  understanding the container format. That cost is partly the point — Instruction §1
  asks for exactly this depth, and it is what the Q&A probes — but it must be budgeted.
- Likely a slow benchmark, lengthening each iteration cycle.
- Depends on a data file shipping with the installed package. **Confirm it exists.**

### Constants to confirm before citing

The data filename and its location; the compression format(s) actually exercised; the
verification checksum value; the file size.

---

## 5. deepcopy

**Expected difficulty: high** — for reasons of constraint, not of concept.

### Purpose

Measures the cost of recursively copying Python object graphs using the standard
library's deep-copy facility. **[UNVERIFIED]** whether this registers as one benchmark
name or several — upstream appears to expose separate variants exercising the plain
path, the reduce-protocol path, and the shared-reference memo path.

### Algorithms

Recursive type dispatch: a table maps each type to a copier function, with fallbacks to
a per-class copy hook and then to the pickle reduce protocol. A memo mapping keyed on
object identity preserves shared references and breaks reference cycles, with an
auxiliary list holding temporaries alive during the copy.

### Data structures

- Nested dictionaries containing lists, tuples, strings and sub-dictionaries.
- A dataclass instance with mixed field types.
- A class implementing the reduce protocol.
- A structure with many references to the same underlying object, specifically to
  stress the memo mapping.

### Likely hotspots — all [HYPOTHESIS]

| ID | Hypothesis | Reasoning |
|---|---|---|
| H1 | Per-node dispatch lookup plus a Python-level recursive call | |
| H2 | Memo mapping insert/lookup keyed on object identity, plus growth of the keep-alive list | Expected to dominate the shared-reference variant |
| H3 | The reduce-protocol path routes through pickle machinery | Expected to dominate the reduce variant |

### The structural problem with this candidate

**The hot code is in the standard library, which you should not modify.** Any
optimization must therefore live in the benchmark — and that creates a methodological
trap: replacing the deep-copy call with a specialized copier arguably means you are no
longer measuring the same benchmark.

| Approach | Assessment |
|---|---|
| Implement the per-class copy hook on the benchmark's own classes | **Legitimate** — a documented extension point that the standard copier itself honours; general semantics preserved |
| Bind the copy function to a local name | **Legitimate**, but small |
| Substitute a third-party fast deep-copy library | **Grey area** — defensible only if it is a true drop-in with identical aliasing semantics, and you will be asked to justify exactly that |
| Replace deep copy with a hand-written shallow-ish copier | **Not defensible** — changes what is being measured |

### Correctness strategy — the hardest of the four

Equality plus non-identity is necessary but far from sufficient. You must additionally
verify:

- **Shared references remain shared** — if two fields aliased the same object before the
  copy, they must alias the same (new) object after it.
- **Reference cycles are handled** without infinite recursion.
- The reduce-protocol path reconstructs state correctly.

These aliasing semantics are precisely what a naive "faster copy" breaks silently.

### Possible hardware targets — all [HYPOTHESIS]

| Candidate | Assessment |
|---|---|
| Hash-and-probe unit for the memo mapping | The specification explicitly names *"Accelerating dictionary operations with specialized hardware"* — a direct match to an approved example |
| Pointer-chasing / graph-traversal engine | Targets H1 |

**Honest risk:** this workload is control-flow and pointer-chasing heavy — the least
accelerator-friendly shape of the four. Arguing a credible speedup is harder here than
for any other candidate.

### Risks

- Optimization surface constrained by the don't-modify-stdlib rule.
- **[UNRESOLVED]** whether the 7% applies to one variant or to all registered variants.
- Weakest hardware story of the four.
- Highest chance of an optimization being challenged as "not really the same benchmark."

### Constants to confirm before citing

The exact registered benchmark name(s); the loop counts within each; the composition of
the copied structures.

---

## 6. Cross-cutting observations

1. **The interpreter, not the arithmetic, is the prime suspect everywhere.** For the two
   floating-point candidates, the naive hardware answer (a faster arithmetic unit) is
   probably targeting a small slice of the runtime. Profile before proposing.

2. **Correctness provability varies enormously** — from self-checking (pyflate) to
   subtle and easy to get wrong (deepcopy). Since the project is graded partly on
   demonstrated understanding, a benchmark that lets you *prove* your optimization is
   sound has real value beyond the 7%.

3. **HDL tractability inverts the intuitive ranking.** The "interesting" floating-point
   candidates are the harder hardware projects; the integer/bit-oriented candidate is
   the easier one to complete, simulate, and defend.

4. **Two of the four map onto examples the specification itself lists**, which shortens
   the justification argument considerably.

---

## 7. Consolidated unknowns for this document

| # | Unknown | Resolved by |
|---|---|---|
| 1 | Whether the installed benchmark sources match upstream | `scripts/vm_audit_minimal.sh` |
| 2 | Every constant listed under *Constants to confirm* above | Reading the installed sources |
| 3 | Whether `deepcopy` registers one name or several | Audit — benchmark listing |
| 4 | Whether hotspot hypotheses H1–H5 hold for any candidate | Baseline profiling |
| 5 | Whether the geometry classes in raytrace declare `__slots__` | Reading the installed source |
| 6 | Whether the pyflate data file is present | Audit — source listing |
| 7 | Whether the 7% applies per registered name or per benchmark family | Course staff |

---

## 8. Selection rubric — **NOT YET SCORED**

Score each candidate 1–5. Criteria 3, 4 and 5 carry **double weight** because they map
directly onto graded requirements. Maximum 60.

| # | Criterion | 1 = poor | 5 = excellent | Weight |
|---|---|---|---|---|
| 1 | **Measurability** | run-to-run noise comparable to 7% | noise far below 7%, stable across repeats | ×1 |
| 2 | **Editable headroom** | hotspots sit in code you may not modify | hotspots sit in benchmark code you own | ×1 |
| 3 | **Confidence of reaching ≥7%** | no principled optimization identified | a known technique targets the measured top hotspot | **×2** |
| 4 | **Correctness provability** | only "looks right" | self-verifying via checksum or byte-exact artifact | **×2** |
| 5 | **Hardware story** | no bounded block maps to a real hotspot | a specification-named example maps onto a measured hotspot | **×2** |
| 6 | **HDL tractability** | floating-point pipeline, weeks of work | integer/bit datapath plus FSM, days | ×1 |
| 7 | **Q&A defensibility** | hard to explain in ten minutes | teachable to a peer | ×1 |
| 8 | **Profiling ergonomics** | minutes per run, unreadable graph | fast runs, legible graph | ×1 |
| 9 | **Independence from reference project** | overlaps the prior submission | no overlap | ×1 |

### Disqualifying rules — these override the total score

- A score of **1 on criterion 3** disqualifies. Without a credible route to 7%, nothing
  else matters.
- A score of **1 on criterion 4** disqualifies. An unverifiable optimization is a
  correctness bug you cannot detect.
- A score of **1 on criterion 5** disqualifies. The hardware proposal is a large,
  mandatory portion of the grade.

### Explicitly NOT selection criteria

Absolute runtime alone. Standard deviation alone. Name familiarity. What the reference
project chose. How large a speedup number could be made to look in isolation.

### Tie-breaker, applied last

Prefer a pair whose hotspots differ **in kind** — for example one bit/integer-oriented
and one object/floating-point-oriented. Two distinct bottleneck classes produce two
genuinely different analyses and a richer presentation.

Prefer a *shared* bottleneck — letting one accelerator serve both benchmarks — **only if
the profiles actually demonstrate that sharing.** Assuming a shared bottleneck from the
mathematics of the benchmarks, rather than from measurement, is an error this project
has already made once and corrected.

### Scoring table — fill in after baseline profiling

| Criterion | W | nbody | raytrace | pyflate | deepcopy |
|---|---|---|---|---|---|
| 1 Measurability | ×1 | | | | |
| 2 Editable headroom | ×1 | | | | |
| 3 Confidence of ≥7% | ×2 | | | | |
| 4 Correctness provability | ×2 | | | | |
| 5 Hardware story | ×2 | | | | |
| 6 HDL tractability | ×1 | | | | |
| 7 Q&A defensibility | ×1 | | | | |
| 8 Profiling ergonomics | ×1 | | | | |
| 9 Independence | ×1 | | | | |
| **Weighted total** | **/60** | | | | |
| Disqualified? | | | | | |
