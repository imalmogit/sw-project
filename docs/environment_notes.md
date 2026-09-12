# Environment Notes

**Governing rule for this file:**

> The current specification and course staff govern the project requirements. The
> working VM is the source of truth only for the installed environment and available
> tools.

**This file contains no installation, upgrade, or setup instructions.** Those are
withheld until the environment audit establishes what already exists.

**No connection procedure is chosen here.** The four documents below conflict, and the
conflict is genuine. It is documented, not resolved.

---

## 1. The four documents

Summarized from the guides. The PDFs themselves could not be attached to the working
session; the summaries below were supplied and verified by the project author.

| # | Document | Date | Summary of contents |
|---|---|---|---|
| 1 | `How to Connect to Your CS Server VM.pdf` | **May 2025** | Connect through the Technion Harmony SASE VPN; verify access to `tangerine.cslcs.technion.ac.il`; SSH using a personal username. |
| 2 | `How to Connect to Your QEMU on the Server.pdf` | **June 2025** | Follow the SSH guide; copy the Ubuntu image from `tangerine:/scratch/yetsion/tmp/`; launch QEMU using the copied image. |
| 3 | `qemu-vm-guide.pdf` | **May 2026** | Each `ece882-xxx` account has its own image under `/scratch/ece882-xxx` on an assigned `naranja` server listed in a CSV. SSH to that server, `cd` into the assigned `/scratch` directory, launch QEMU **there**, and perform all building **inside the guest** rather than on the host. |
| 4 | `Project.pdf` (current specification) | **August 2026** | Copy the image from `naranja10:/scratch/ece882-001/` **to the local machine**, then launch QEMU "using a previous guide". |

Chronological order: 1 → 2 → 3 → 4. Document 4 is the most recent **and** is the
authoritative specification for assignment requirements.

---

## 2. What changes across the documents

| Dimension | May 2025 (#1) | June 2025 (#2) | May 2026 (#3) | Aug 2026 (#4) |
|---|---|---|---|---|
| Server | `tangerine` | `tangerine` | assigned `naranja` host from a CSV | `naranja10` |
| Account | personal username | personal username | `ece882-xxx` | `<your_username>` placeholder |
| Image source path | — | `/scratch/yetsion/tmp/` | `/scratch/ece882-xxx` (own account) | `/scratch/ece882-001/` |
| Where QEMU runs | — | from the copied image | **on the server**, in the assigned `/scratch` dir | **on the local machine** |
| Where you build | — | — | **inside the guest**, not the host | not stated |
| Access method | Harmony SASE VPN + SSH | SSH | SSH | `scp` |

The `tangerine` → `naranja` change and the personal-username → `ece882-xxx` change are
consistent with a **course infrastructure migration between the 2025 and 2026
offerings**. That reading is plausible but is **not** confirmed by any document in hand,
and it does not resolve the conflicts below.

---

## 3. The unresolved conflicts

### Conflict A — where QEMU actually runs

**This is the central conflict, and it is between the two most recent documents.**

| Position | Source | Date |
|---|---|---|
| Launch QEMU **on the server**, inside the assigned `/scratch` directory | `qemu-vm-guide.pdf` (#3) | May 2026 |
| Copy the image **to the local machine** and launch it there | `Project.pdf` (#4) | August 2026 |

**Why this is not settled by recency.** Document 4 is newer, but its own instruction is
internally inconsistent: it says to copy the image to the local machine, and then says
to launch QEMU "using a previous guide" — and the previous guide it would point to
(#3, the only 2026 guide) says to launch **on the server**. Following document 4's
Step 0 and then its Step 1 leads to two different machines.

**Additional evidence that #4's setup page may be carried over from an earlier
edition:** the worked example on that page profiles a benchmark that is **not on this
project's approved benchmark list**. The page has demonstrably not been fully revised
for this assignment.

**Why it matters, concretely:**

- Where results, flame graphs and recorded profiles land, and whose disk quota they
  consume.
- Whether profiling runs under **nested virtualization** — which bears directly on
  whether hardware performance counters are available at all. That is the highest-impact
  unknown in the whole audit.
- Whether flame graph files must be copied back before they can be viewed.
- Document 3's instruction to build inside the guest rather than on the host only has
  its stated meaning under the server-side reading.

### Conflict B — `tangerine` versus `naranja`

| Position | Source | Date |
|---|---|---|
| `tangerine.cslcs.technion.ac.il` | #1, #2 | May–June 2025 |
| An assigned `naranja` host, identified per-student via a CSV | #3 | May 2026 |
| `naranja10` specifically | #4 | August 2026 |

Migration is the natural reading. But #3 and #4 **do not agree with each other**: #3
says the host is assigned per account and must be looked up in a CSV, while #4 names
`naranja10` outright. Either `naranja10` is this account's assigned host, or it is an
example carried over from one particular assignment. **Nothing available distinguishes
these.**

### Conflict C — the image source path

Three documents give three different paths:

- `/scratch/yetsion/tmp/` (#2, 2025)
- `/scratch/ece882-xxx` — each account's own directory (#3, 2026)
- `/scratch/ece882-001/` (#4, 2026)

Under #3's per-account scheme, `ece882-001` would be **one specific account's**
directory. Whether #4 intends it as a literal shared course path, or as a placeholder
standing in for the reader's own `ece882-xxx`, cannot be determined — particularly since
#4 pairs that concrete path with a generic `<your_username>` placeholder in the same
command.

### Conflict D — build on host or in guest

Document 3 states explicitly that all building happens **inside the guest**, not on the
host. No other document addresses this. Under the local-copy reading of #4, "host" and
"guest" refer to different machines than under #3's server-side reading, so the
instruction cannot be carried across without first settling Conflict A.

---

## 4. Deliberately not chosen

No host, path, account form, or launch method is recommended in this package.

Recency does not settle it, because the newest document is internally inconsistent and
contains at least one demonstrably stale element. Authority does not settle it either:
`Project.pdf` is authoritative for **what the project must deliver**, which is a
different question from **which machine the VM runs on**.

Two sources can settle it, and both are obtainable quickly:

| Question type | Settled by |
|---|---|
| Operational procedure — which host, which path, where QEMU runs | The partner's known working commands |
| Assignment requirements — deliverables, thresholds, formats | `Project.pdf` and course staff |

Guessing in the meantime risks connecting to the wrong host or disturbing a working
environment that took effort to build.

---

## 5. What must be confirmed from the existing working environment

To be answered by `scripts/vm_audit_minimal.sh`:

| # | Question | Why it matters |
|---|---|---|
| 1 | Are we inside a virtualized guest, or on a host? | Bears directly on Conflict A |
| 2 | Distro release and kernel version | The Ubuntu version is inferred from an image filename and has never been verified |
| 3 | CPU model and core count | Needed for the report's methodology section |
| 4 | Is `python3-dbg` present, and is it a genuine debug build? | The specification's documented profiling command depends on it |
| 5 | Release Python version | Relevant to the open question of which build the 7% is measured under |
| 6 | Installed benchmark-harness version | Determines which command-line options exist |
| 7 | The authoritative benchmark-name list for this install | Settles the `deepblue`/`deltablue` question and how `deepcopy` is exposed |
| 8 | Where the benchmark sources live, and which candidate directories exist | Every constant in `benchmark_candidates.md` must be read from here |
| 9 | Profiler version, and whether it matches the kernel | A mismatch produces confusing failures |
| 10 | **Do hardware performance counters work?** | **Highest-impact unknown.** If only software events are available, the counter-based analysis the course teaches cannot be reproduced, and the measurement strategy must change. Interacts with Conflict A via nested virtualization |
| 11 | Is flame-graph tooling already present, and in which form? | The third-party script pipeline and the profiler's native path are different routes to the same deliverable |
| 12 | Is any HDL simulator already installed? | Determines whether simulating the accelerator is already possible |

To be answered by the partner, not by a script:

| # | Question | Resolves |
|---|---|---|
| 13 | The exact working connection procedure — the real commands typed, not a guide's version | Conflicts A, B, C |
| 14 | Which host, and which account? | Conflicts B, C |
| 15 | Does QEMU run on the server or on a local machine? | **Conflict A** |
| 16 | Is the image copied, or already present in the assigned directory? | Conflict C |
| 17 | Is there an existing working environment with the benchmark harness, and where? | Avoids duplicating work |
| 18 | Is profiling or flame-graph tooling already set up, and where? | Avoids duplicating work |
| 19 | Is the VM shared between both partners? | Measurement validity |
| 20 | Is there a per-user disk quota? | Profiling output accumulates quickly |
| 21 | Any environment quirks learned the hard way — permissions, sudo, session limits? | Avoids rediscovering them |

---

## 6. Questions for the partner

1. Walk through exactly how you connect and start the VM — the real commands you type.
2. Which server, and which account?
3. Does QEMU run on the server, or on your own machine?
4. Was the image copied, or was it already in your assigned directory?
5. What is already installed and working from previous coursework, and where does it
   live?
6. **Is the VM shared?** If both partners work on it simultaneously, measurements taken
   during the other's activity are invalid. A convention is needed before any numbers
   are collected.
7. Is there a per-user disk quota?
8. Anything that broke before and how you fixed it?

## 7. Questions for course staff

Listed in full in `docs/spec_checklist.md` §10. The two bearing on this file:

- **Which guide is current for this semester** — `qemu-vm-guide.pdf` (May 2026) or the
  setup page in `Project.pdf` (August 2026)? They give different instructions for where
  QEMU runs.
- Is the setup page in `Project.pdf` current, given that its worked example profiles a
  benchmark absent from this project's approved list?

---

## 8. Standing rule

**The current specification and course staff govern the project requirements. The
working VM is the source of truth only for the installed environment and available
tools.**

Practically:

- **Requirements** — deliverables, file names, the 7% threshold, report sections, HDL
  language choice: `Project.pdf` and course staff decide. The VM has no say.
- **Environment facts** — installed versions, available benchmark names, counter
  support, present tooling: the audit output decides, and overrides any assumption
  recorded in this package.
- **Operational procedure** — host, path, where QEMU runs: unresolved. The partner's
  working commands describe what currently works; course staff confirm what is
  officially current. These may differ, and if they do, that difference is worth
  raising rather than silently resolving.

Nothing in this file may be cited in a report until it carries a confirmation source.
