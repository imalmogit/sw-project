# Baseline Preparation — run these in order

These are **bootstrap scripts, not project deliverables.** They are not the
`script_<benchmark>.sh` files the specification requires; those get written later,
once we know what we are optimizing.

| # | Script | Changes anything? | Purpose |
|---|---|---|---|
| 00 | `00_preflight.sh` | No (one output file + a self-cleaning temp dir) | Fills the gaps the minimal audit skipped: privilege, disk, RAM, network, apt availability, and whether the flame-graph pipeline can work at all |
| 01 | `01_setup.sh` | **Yes** — installs 3 apt packages, creates one project directory | Prepares a self-contained environment without disturbing the partner's setup |
| 02 | `02_baseline_nbody.sh` | Writes results only | The first original baseline run — a pipeline proof, plus a `--sweep` mode for benchmark selection |

## Order

```bash
bash 00_preflight.sh          # return the output BEFORE running 01
bash 01_setup.sh              # asks before installing; --yes to skip prompts
bash 02_baseline_nbody.sh     # full pipeline proof on one benchmark
bash 02_baseline_nbody.sh --sweep   # then: time all four candidates
```

## What 01_setup.sh installs

Three apt packages, all additive — nothing is removed, replaced or upgraded:

- `python3-dbg` — the debug interpreter the specification's profiling command requires.
  The audit found it missing.
- `python3.10-venv` — needed to build a venv from the debug interpreter.
- `git` — to clone the flame-graph tooling.

Everything else lives under one new directory (default `~/hwsw_project`): the venv, the
benchmark harness, the FlameGraph clone, and all results. Override with
`HWSW_ROOT=/some/path`.

## Ask the partner first

`01_setup.sh` runs `apt-get install` on a VM that is not exclusively ours. Confirm with
your partner before running it, and confirm whether the VM is shared — if you both work
on it at once, any measurement taken during the other's activity is invalid.
