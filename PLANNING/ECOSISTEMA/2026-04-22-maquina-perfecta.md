# Maquina Perfecta Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the urbanizacion ecosystem from copy-driven repo drift into an enforceable multi-repo machine with explicit authorities, locked project contracts, and automatic structural validation.

**Architecture:** The ecosystem will be split cleanly into three layers: `urbanizacion-toolkit` as authority for reusable rules and tooling, `urbanizacion-plantilla-base` as bootstrap product, and each `obra-*` repo as a project-local source of truth for identity, deliverables, and project-specific automation. The conversion starts by installing a machine-readable repo contract in each project repo, then removes duplicated authorities and replaces synced copies with wrappers or direct references.

**Tech Stack:** PowerShell, GitHub Actions, JSON contracts, Markdown operating docs

---

### Task 1: Install the project repo contract in `obra-535-2-1`

**Files:**
- Create: `PLANNING/ECOSISTEMA/2026-04-22-maquina-perfecta.md`
- Create: `CONFIG/project_identity.json`
- Create: `CONFIG/toolkit.lock.json`
- Create: `CONFIG/repo_contract.json`
- Create: `tools/check_repo_contract.ps1`
- Create: `.github/workflows/validate-structure.yml`

- [ ] **Step 1: Add explicit identity and authority metadata**

Create `CONFIG/project_identity.json`, `CONFIG/toolkit.lock.json`, and `CONFIG/repo_contract.json` so the repo declares what it is, who owns global rules, and which paths are forbidden.

- [ ] **Step 2: Add the structural checker**

Create `tools/check_repo_contract.ps1` with these checks:

```powershell
- required files exist
- required directories exist
- forbidden paths do not exist
- nested repositories are rejected
- root markdown count above threshold becomes a warning
- duplicated governance filenames become warnings
- exit code 1 on structural errors
```

- [ ] **Step 3: Add CI enforcement**

Create `.github/workflows/validate-structure.yml` to run:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\tools\check_repo_contract.ps1 -ContractPath .\CONFIG\repo_contract.json -RootPath .
```

- [ ] **Step 4: Run the checker locally**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_repo_contract.ps1 -ContractPath .\CONFIG\repo_contract.json -RootPath .
```

Expected:
- no structural errors
- warnings are allowed until the repo root is reduced

### Task 2: Make `obra-535-2-1` converge toward the project contract

**Files:**
- Modify: `AGENTS.md`
- Modify: `README.md`
- Modify: `MAPA_PROYECTO.md`
- Modify: `FUENTES_MAESTRAS.md`
- Modify: `DECISIONES_PROYECTO.md`
- Modify: `ESTADO_PROYECTO.md`
- Move or delete: `CLAUDE.md`, `ESTANDARES.md`, `COMANDOS_RAPIDOS_MAQUETACION.md`, `PLANTILLA_ORDEN_TRABAJO.md`, guide markdowns, pack markdowns

- [ ] **Step 1: Reduce root governance**

Move generic operational content to:

```text
PLANNING/ECOSISTEMA/
PLANNING/OPERATIVA/
```

Delete or archive duplicated root docs once their canonical replacement exists.

- [ ] **Step 2: Thin the project `AGENTS.md`**

Keep only project-specific rules and local exceptions. Replace duplicated global rules with a short section that points to toolkit authority.

- [ ] **Step 3: Normalize project config**

Migrate consumers from:

```text
CONFIG/proyecto.template.json
```

to:

```text
CONFIG/project_identity.json
CONFIG/toolkit.lock.json
```

### Task 3: Rebuild `urbanizacion-plantilla-base` as a real template product

**Files:**
- Create: `template/`
- Move: `.github/`, `CHECKLISTS/`, `CONFIG/`, `DOCS/`, `PLANNING/`, `PLANOS/`, `PRESUPUESTO/` into `template/`
- Delete: `SYSTEM_RULES.md`, `TASK_TYPES.md`, `TRIAGE.md`, `IGNORE_DEFAULTS.md`, `ESTANDARES.md` from template root
- Modify: `README.md`
- Modify: `scripts/iniciar_proyecto_estandar.ps1`

- [ ] **Step 1: Stop making the template look like a live project**

Everything copied into new repos must live under `template/`.

- [ ] **Step 2: Keep only bootstrap concerns**

Template root should contain only:

```text
README.md
AGENTS.md
scripts/
docs/bootstrap/
template/
```

- [ ] **Step 3: Point all global rule lookups to toolkit**

The template must not become a second authority for system rules.

### Task 4: Promote `urbanizacion-toolkit` to real authority

**Files:**
- Modify: `AGENTS.md`
- Delete: `AGENTS_CORE.md`
- Add or move: `docs/architecture/`
- Add or move: `docs/recipes/`
- Add or move: `catalog/policies/`
- Move from project repos: generic `tools/*`, generic `scripts/*`, repo workflow docs

- [ ] **Step 1: Merge `AGENTS_CORE.md` into `AGENTS.md`**

One entrypoint only.

- [ ] **Step 2: Move reusable docs out of project repos**

Architecture, workflow, and recipe docs belong in toolkit, not in Guadalmar or Plaza Mayor.

- [ ] **Step 3: Replace synced copies with wrappers**

Project repos may keep wrappers, but not full logic clones.

### Task 5: Decontaminate `obra-535-2-2-guadalmar`

**Files:**
- Delete: `urbanizacion-toolkit/`
- Delete: `urbanizacion-plantilla-base/`
- Delete: `00_PLANTILLA_BASE/`
- Move: ecosystem docs out of `DOCS/`
- Delete: build artifacts under `tools/civil3d/PipeNetworkRenamer/bin` and `obj`
- Add: `CONFIG/toolkit.lock.json`
- Add: `CONFIG/repo_contract.json`

- [ ] **Step 1: Remove nested repos**

This is mandatory before any further cleanup.

- [ ] **Step 2: Separate project docs from ecosystem docs**

If it does not describe the Guadalmar expediente, it does not belong under `DOCS/`.

- [ ] **Step 3: Apply the same structural checker**

Guadalmar should fail fast on nested repos, copied authorities, and build residue.

### Task 6: Enforce ecosystem-wide invariants in CI

**Files:**
- Create in each repo: `.github/workflows/validate-structure.yml`
- Create in toolkit: reusable validation workflows if desired

- [ ] **Step 1: Add a required structure check to every repo**

No merge should bypass the contract checker.

- [ ] **Step 2: Add anti-drift checks**

Toolkit should detect when a project wrapper points to a non-existent authority target.

- [ ] **Step 3: Add bootstrap acceptance**

The template should be able to generate a new project that passes the contract checker on first run.
