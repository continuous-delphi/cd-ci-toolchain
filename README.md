# cd-ci-toolchain

![Status](https://img.shields.io/badge/status-incubator-orange)
![Version](https://img.shields.io/badge/version-0.1.0-blue)
![PowerShell](https://img.shields.io/badge/powershell-7.4%2B-blue)
![Pester](https://img.shields.io/badge/pester-5.7%2B-blue)
![Platform](https://img.shields.io/badge/platform-windows-lightgrey)

Deterministic Delphi toolchain discovery and normalization for long-lived Delphi systems.

This repository provides two fully independent implementations that share a mission and a
contract:

- `source/delphi` -- Native Windows console executable
- `source/pwsh` -- PowerShell 7.4+ implementation

Neither implementation is primary. They serve overlapping but distinct audiences and are both
first-class deliverables.

## Philosophy

Continuous Delphi meets Delphi developers where they are.

Whether you are building manually on a desktop PC, running FinalBuilder scripts on a cloned
server, or ready to adopt GitHub Actions, the tools here work at your level today without
requiring you to change everything at once.

The goal is not to replace your workflow - the goal is to incrementally enhance it.

## Two Implementations, One Mission

### Delphi executable (`source/delphi`)

**Audience:**

- Security-conscious shops that will not use cloud CI
- Teams maintaining legacy infrastructure
- Air-gapped environments
- Single-developer systems with tribal build knowledge
- Organizations building their first repeatable build process

**Operational requirements:**

- Windows (Win32/Win64)
- No PowerShell required
- No Git required

The Delphi executable embeds the dataset as a compiled resource and requires no external
files for basic operation. It is a true single-file xcopy deployment.

Dataset resolution priority:

1. `-DataFile <path>` if specified on the command line
2. `delphi-compiler-versions.json` found alongside the executable
3. Embedded resource compiled into the executable

This means the executable works out of the box, but can be updated to a newer dataset
by placing the JSON file alongside it without recompiling. All output indicates which
source was used via the `datasetSource` field.

This implementation must stand alone and provide immediate value on first run. For many
shops it will be the only component of this toolkit ever used.

### PowerShell implementation (`source/pwsh`)

**Audience:**

- Teams using modern CI (GitHub Actions, GitLab CI, Jenkins, etc.)
- Shops comfortable with scripting
- Hybrid environments combining scripting and native builds

**Operational requirements:**

- PowerShell 7.4+
- Windows for registry-based detection commands

Dataset resolution priority (if `-DataFile` is not specified):

1. `-DataFile <path>` if specified on the command line
2. `delphi-compiler-versions.json` found alongside the script
3. Embedded here-string compiled into the script by the generator

The standalone generated script embeds the dataset as a PowerShell here-string, making
it a true single-file xcopy deployment with no external dependencies. The embedded data
is plaintext inside the script and fully auditable without additional tooling.

**Development and test requirements:**

- PowerShell 7.4+
- Pester 5.7+
- CI pins Pester to a specific patch version for reproducibility

The PowerShell implementation integrates cleanly into modern CI pipelines and supports
structured machine-readable output formats.

## Shared Contract

- Both implementations provide equivalent behavior and identical exit codes for shared commands
- Human-readable text output may differ between implementations
- Machine-readable JSON output must remain stable and match across both tracks

### Shared commands

| Command           | Description                                      |
|-------------------|--------------------------------------------------|
| `Version`         | Print tool version and dataset metadata          |
| `ListKnown`       | List all known Delphi versions from the dataset  |
| `DetectInstalled` | Detect installed Delphi versions via registry    |
| `Resolve`         | Resolve an alias or VER### to a canonical entry  |

Both implementations use single-dash PascalCase switches (`-Version`, `-ListKnown`).
This is the recognized PowerShell standard and is adopted for both implementations to
ensure identical parameter syntax across both tracks.

See [docs/commands.md](docs/commands.md) for full command reference including switches,
output formats, and any functionality differences between implementations.

### Exit codes

| Code | Meaning                                                   |
|------|-----------------------------------------------------------|
| `0`  | Success                                                   |
| `1`  | Unexpected error                                          |
| `2`  | Invalid arguments                                         |
| `3`  | Dataset missing or unreadable                             |
| `4`  | No Delphi installations detected (DetectInstalled only)   |

Exit codes must match across implementations for equivalent commands.

### Machine output contract

When JSON output is requested (`-Format json`), both implementations emit a stable JSON
envelope. Machine-readable JSON output is part of the public contract and must remain
stable across both implementations.

Success:

```json
{
  "ok": true,
  "command": "version",
  "tool": {
    "name": "cd-ci-toolchain",
    "impl": "pwsh|delphi",
    "version": "X.Y.Z"
  },
  "data": {
    "schemaVersion": "1.0.0",
    "dataVersion": "0.1.0",
    "generatedUtcDate": "YYYY-MM-DD",
    "datasetSource": "override|file|embedded"
  },
  "result": {}
}
```

Error:

```json
{
  "ok": false,
  "command": "detect-installed",
  "tool": {
    "name": "cd-ci-toolchain",
    "impl": "pwsh|delphi",
    "version": "X.Y.Z"
  },
  "error": {
    "code": 3,
    "message": "Dataset missing or unreadable."
  }
}
```

## Decision Guide

```
Cloud CI or scripting-first environment?
  -> Start with source/pwsh

Air-gapped, legacy, or security-constrained environment?
  -> Start with source/delphi

Modern shop doing both?
  -> Use both. Implementations communicate via stdout and exit codes only.
```

## Dataset

Both implementations consume the canonical dataset from
[cd-spec-delphi-compiler-versions](https://github.com/continuous-delphi/cd-spec-delphi-compiler-versions).
The JSON dataset is the single source of truth. Version tables must not be duplicated in code.

During development, the dataset is referenced as a Git submodule. Clone with:

```
git clone --recurse-submodules https://github.com/continuous-delphi/cd-ci-toolchain
```

The `gen/` folder produces a standalone `pwsh` script with the dataset embedded as a
PowerShell here-string. (The Delphi executable references the dataset directly as a project
resource.)

Both standalone artifacts support the same three-tier dataset resolution priority. Placing
a newer `delphi-compiler-versions.json` alongside either artifact will take precedence over
the embedded data without regenerating or recompiling.

## Development Notes

Operational dependencies and development dependencies are separate concerns.

Operational requirements are what end users need to run the tool. Development requirements
are what contributors need to build and test it. CI environments (GitHub runner, GitLab
runner, etc.) are execution environments -- they are not operational dependencies of the
tool itself.

## Maturity

This repository is currently `incubator`. Both implementations are under active development.
It will graduate to `stable` once:

- The shared command contract is considered frozen.
- Both implementations pass the shared contract test suite.
- CI is in place for the PowerShell implementation.
- At least one downstream consumer exists.

Until graduation, breaking changes may occur in both implementations.

## Part of Continuous Delphi

This repository follows the Continuous Delphi organization taxonomy. See
[cd-meta-org](https://github.com/continuous-delphi/cd-meta-org) for navigation and governance.

- `docs/org-taxonomy.md` -- naming and tagging conventions
- `docs/versioning-policy.md` -- release and versioning rules
- `docs/repo-lifecycle.md` -- lifecycle states and graduation criteria

---

*Each component is usable in isolation and delivers value without requiring ecosystem buy-in.*
