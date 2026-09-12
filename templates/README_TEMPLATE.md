<!--
  README TEMPLATE  ->  rename to README.md at the repository root.

  Project.pdf requires a README.md that "explains the structure of the
  repository and provides instructions on how to run the scripts."

  Rules for filling this in:
    * Replace every <ANGLE_BRACKET> placeholder.
    * Delete these HTML comments before submitting.
    * Do not write a command here that you have not actually run successfully.
    * Do not write a result here that you have not actually measured.
    * If something is not yet known, leave the placeholder. An honest gap is
      better than a confident guess.
-->

# <PROJECT TITLE>

**Course:** <COURSE NAME AND NUMBER>
**Semester:** <SEMESTER>

| | |
|---|---|
| <STUDENT NAME 1> | <ID 1> |
| <STUDENT NAME 2> | <ID 2> |

---

## Overview

<!-- Two or three sentences: what this repository contains and what was done. -->

<OVERVIEW>

**Benchmarks selected:** <BENCHMARK 1>, <BENCHMARK 2>

---

## Results summary

<!-- Fill in only after measuring. Leave placeholders until then. -->

| Benchmark | Baseline | Optimized | Improvement | Hardware accelerator proposed |
|---|---|---|---|---|
| <BENCHMARK 1> | <VALUE> | <VALUE> | <VALUE> | <ACCELERATOR> |
| <BENCHMARK 2> | <VALUE> | <VALUE> | <VALUE> | <ACCELERATOR> |

Full analysis: [`report_<BENCHMARK 1>.txt`](report_<BENCHMARK_1>.txt) ·
[`report_<BENCHMARK 2>.txt`](report_<BENCHMARK_2>.txt)

---

## Repository structure

<!-- One line per top-level entry. Keep it accurate as the repo grows. -->

```
<REPO ROOT>/
├── README.md                      <THIS FILE>
├── prompt.txt                     <AI PROMPTS USED>
├── report_<BENCHMARK 1>.txt       <FULL ANALYSIS, BENCHMARK 1>
├── report_<BENCHMARK 2>.txt       <FULL ANALYSIS, BENCHMARK 2>
├── script_<BENCHMARK 1>.sh        <END-TO-END RUN, BENCHMARK 1>
├── script_<BENCHMARK 2>.sh        <END-TO-END RUN, BENCHMARK 2>
├── <DIRECTORY>/                   <PURPOSE>
├── <DIRECTORY>/                   <PURPOSE>
└── <DIRECTORY>/                   <PURPOSE>
```

---

## Requirements

<!-- Pin actual versions once the environment is confirmed. Do not guess. -->

| Component | Version / detail |
|---|---|
| Environment | <VM / IMAGE / HOW IT IS LAUNCHED> |
| Operating system | <VALUE> |
| Kernel | <VALUE> |
| Python (release build) | <VALUE> |
| Python (debug build) | <VALUE> |
| Benchmark harness | <NAME AND VERSION> |
| Profiler | <NAME AND VERSION> |
| Flame graph tooling | <WHAT AND WHERE> |
| HDL simulator | <WHAT AND VERSION, OR "not used"> |
| Other packages | <LIST> |

---

## How to run

<!--
  Every command below must be one you have actually run to completion in the
  target environment. Do not transcribe from a guide.
-->

### 1. Obtain the repository

```bash
<CLONE COMMAND>
```

### 2. Run the benchmarks

```bash
<COMMAND FOR BENCHMARK 1>     # approximate runtime: <VALUE>
<COMMAND FOR BENCHMARK 2>     # approximate runtime: <VALUE>
```

### 3. Where the output lands

<!-- Say exactly what appears and where, so a grader knows what to look at. -->

```
<OUTPUT PATH>/
├── <FILE>       <WHAT IT IS>
├── <FILE>       <WHAT IT IS>
└── <FILE>       <WHAT IT IS>
```

### 4. Viewing the flame graphs

<INSTRUCTIONS>

---

## What each script does

### `script_<BENCHMARK 1>.sh`

<!-- Project.pdf requires all four of the behaviours listed below. -->

1. **Environment setup and dependency installation** — <WHAT IT DOES>
2. **Benchmark execution** — <WHAT IT DOES>
3. **Flame graph and performance data generation** — <WHAT IT DOES>
4. **Post-optimization execution with performance comparison** — <WHAT IT DOES>

### `script_<BENCHMARK 2>.sh`

1. **Environment setup and dependency installation** — <WHAT IT DOES>
2. **Benchmark execution** — <WHAT IT DOES>
3. **Flame graph and performance data generation** — <WHAT IT DOES>
4. **Post-optimization execution with performance comparison** — <WHAT IT DOES>

---

## Verifying correctness

<!-- How a reader confirms the optimized version still behaves correctly. -->

| Benchmark | Check | Command | Expected result |
|---|---|---|---|
| <BENCHMARK 1> | <WHAT IS CHECKED> | <COMMAND> | <EXPECTED> |
| <BENCHMARK 2> | <WHAT IS CHECKED> | <COMMAND> | <EXPECTED> |

---

## Hardware accelerators

| Benchmark | Accelerator | HDL language | Source |
|---|---|---|---|
| <BENCHMARK 1> | <NAME> | <LANGUAGE> | <PATH> |
| <BENCHMARK 2> | <NAME> | <LANGUAGE> | <PATH> |

<!-- If you simulate, document how. Confirm with staff whether it is expected. -->

```bash
<SIMULATION COMMAND, IF ANY>
```

Design rationale, interfaces, operating frequency, and trade-offs are documented in the
corresponding report files.

---

## Measurement methodology

<!-- Short version here; the detail belongs in the reports. -->

| | |
|---|---|
| Repetitions per measurement | <VALUE> |
| Python build used for the reported improvement | <VALUE> |
| Cache handling between runs | <VALUE> |
| How improvement percentage was computed | <FORMULA> |

---

## Known limitations

<!-- Anything a grader would otherwise trip over. Being upfront costs nothing. -->

- <LIMITATION>
- <LIMITATION>

---

## AI tool usage

Prompts and instructions used with AI tools are recorded in
[`prompt.txt`](prompt.txt), as required by the project specification.
