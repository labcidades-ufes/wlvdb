# AGENTS.md

Guide for AI agents working in the World Labour Values Database (wlvdb) repository.

## What this project is

R codebase that computes Marxian labour values, exploitation rates, profit rates
and unequal exchange indicators from world input-output tables (WIOD 2013/2016,
EXIOBASE 3.x, EORA26). There is **no package, no `R/` package structure, no test
suite, no CI, no Makefile**. Everything is a script pipeline driven by `source()`.

## Essential commands

```r
# Normal entry point (run from the project root, or open the .Rproj in RStudio):
source("R/main.R")          # defines get_wlv() and recalc_wlv()
get_wlv("wiodr13")          # run one method end-to-end
get_wlv(c("wiodr13", "wiodr16"))
get_wlv("exiobase382", repeat_pp = TRUE)  # TRUE = re-download + re-prepare raw source data (very slow)

recalc_wlv("wiodr13", at_stage = 1, sea_vars = NULL)  # recompute only sea_variables/sea_countries stages
```

- Method names = folder names under `methods/` (e.g. `alternative_1`, `zeroneg16`, `exiobase382`).
- Long-running/background run pattern: see `R/utils/get_wlv_background.R` (`Rscript`-able; it `setwd()`s to the repo root itself).
- Raw data preparation scripts: `R/utils/prepare_<source>_data.R` (e.g. `prepare_exiobase_data.R`, `prepare_wiodr16_data.R`). They download from Zenodo/WorldBank/etc. into `source_data/` and build `sea.fst` plus per-year `m_io_*.fst` files.
- "Testing" here means running a method and inspecting `results/<method>/` outputs; there are no automated tests.

## Architecture and data flow

`get_wlv()` → `R/lib/computations.R` orchestrates, in order:

1. `R/lib/parameters.R` — loads CSV parameter tables for the method (see layering below).
2. `R/lib/raw_sea_data.R` — loads `source_data/<source>/sea.fst` (socio-economic accounts array: years × variables × sectors × countries).
3. `R/lib/control_variables.R`, `R/lib/results_variables.R`, `R/lib/filters_io.R` — build `rows`, `nums`, `lists`, reserve result arrays.
4. **Stage 1** `R/modules/variables/sea_sectors.R` — computes preliminary sectoral variables by sourcing one script per variable.
5. **Assumptions** — sources every script listed in `*_assumptions.csv` (RoW/China missing-data treatments, currency conversion). Mostly mutate `sea_sectors` in place.
6. **Stage 2** — recompute variables affected by assumptions.
7. Per `m_io_*.fst` file: `R/lib/prepare_computation.R` (loads IO matrix, ×1e6 scale), then `R/modules/matrices/*` — notably `transformation.R`, which builds `(I-A-D)` and **inverts it with base `solve()`** to get labour values (lambda). Then `R/modules/reduced_matrices/*` collapse world matrices to country-level (removing internal trade).
8. **Stage 4** — variables computed from the matrices; results written incrementally to `results/<method>/` after each file (blackout-safe: `m_countries.fst`, `sea_sectors.fst` are rewritten each iteration).
9. **Stage 5** + `R/modules/variables/sea_countries.R` — national aggregates; final write + `R/lib/write_labels.R` metadata.

Key global state (communicated by assignment into `globalenv()`): `method_version`, `methods`, `stage`, `sea_source`, `sea_sectors`, `sea_countries`, `m_io_source`, `m_io`, `rows`, `nums`, `lists`, `parameters`, `my.cluster`. Scripts are side-effect based; never assume isolation.

Parallelism: `R/lib/parallelization_start.R` creates a PSOCK cluster with `detectCores()-1`; `myApply()` wraps `apply`/`parApply` depending on whether the current chunk has 1 or several years. Expect multi-GB RAM use; `gc()` calls are deliberate.

## The parameter/config layering (crucial)

Config is CSV (`;`-separated, read with `read.csv2`), layered and merged by
`load_parameters()` in `R/lib/parameters.R`, most specific wins on duplicated
`names`:

1. `methods/<method>/` — `_parameters.csv` (source + code + description), `_sectors.csv` (which sectors are productive), optional `_method_assumptions.csv`, `_method_matrices.csv`, `_method_solutions.csv` overrides.
2. `parameters/<source>/` — `_source_assumptions.csv`, `_source_matrices.csv`, `_source_solutions.csv` (default solutions per source).
3. `parameters/common_ground/` — fallbacks shared by all sources.

To create a new experiment/method: copy an existing `methods/<x>/` folder, point `_parameters.csv`'s `source` column at an existing `parameters/<source>/` (or a new one), and override assumptions/solutions as needed. That is how `zeroneg`, `norow_w16`, `exiobaset383`, etc. were made.

Solution CSV columns: `names` (variable code), `sector_solution`/`country_solution` (either a script path relative to `R/modules/variables/` or a builtin like `sum`/`mean`), `stage`, `order`.

## Conventions

- Variable codes are dotted, hierarchical: `<name>.<subject>.<scope>.<unit>`, e.g. `hours_worked.emp.s.hr`, `compensation.empe.s.us`, `capital_stock.s.us`, `gdp.s.du`. Common parts: `emp` = employees, `empe` = persons engaged, `s` = sectoral, `m` = monetary value, `mv`, `us` = US dollars, `un` = units/persons, `hr` = hours, `r` = ratio/rate, `pc` = proportion. Variable scripts live in `R/modules/variables/<folder>/<code>.R` and register metadata in `meta_indicators`.
- Assumption scripts live under `R/modules/assumptions/<topic>/` and are referenced from the CSVs by relative path.
- Comments, commit messages and descriptions are mixed English/Portuguese; user-facing descriptions end up concatenated into `parameters$description`.
- Monetary source data is in millions; `R/lib/prepare_computation.R` multiplies by 1e6 to work in dollars.

## Storage format gotcha

Arrays are persisted as a single-column fst data.frame plus a sibling `.meta`
RDS holding dims/dimnames; always read/write them with `read_fst_array()` /
`write_fst_array()` from `R/lib/functions.R` (also defines `newDim()`, `clean()`
which zeroes NaN/NA/Inf). A bare `fst::read_fst()` loses the array shape.

## Repo/data layout

- `source_data/` — **gitignored**, not in git. Must be obtained separately (cloud link in README.md) or rebuilt with the `prepare_*_data.R` scripts. One subfolder per source version (`wiodr13`, `exiobase382`, ...), containing `sea.fst`, `m_io_<year>.fst`, plus `countries.csv`, `sectors.csv`, `demand.csv`.
- `complementar/` — small auxiliary CSVs kept in git (World Bank employment for RoW/China, EUKLEMS aggregation tables, depreciation rates).
- `results/` — gitignored outputs per method.
- `temp/` — scratch for downloads/extraction.

## Known numerical issue: singularity of the Leontief inverse

`R/modules/matrices/transformation.R` inverts `(I-A-D)` with plain `solve()`
(over all years at once). There is **no** `tryCatch`, pseudo-inverse or
conditioning guard anywhere. Ill-conditioned/singular systems show up as
crashes there or as negative labour values / negative exploitation rates
downstream. The project's strategy so far is to treat the *data* side: the RoW
(Rest of World) assumptions in `R/modules/assumptions/row/` (`row.R`,
`row-reduction_problem.R`, `row_mitigated.R`, `no_row.R`) estimate missing RoW
labour/capital data differently so the world system stays well behaved;
experimental methods like `zeroneg`/`zeroneg16` (row_mitigated) and `norow_w16`
(no RoW data) exist to test these treatments.

## Other gotchas

- `.Rprofile` runs on R startup in the project root: auto-installs missing packages **and runs `git pull`** (via `system2`). This can surprise you mid-session; a `started` file temporarily disables it. Avoid editing it casually.
- Everything runs on relative paths — the working directory **must** be the repo root.
- `get_wlv(..., repeat_pp = TRUE)` triggers full re-download of source data (long, network-heavy; scripts raise `options(timeout=...)` for a reason).
- Write/commit messages in this repo are frequently Portuguese; match the surrounding style.
- Branching: `master` is mainline; feature/experiment branches (e.g. `singularity_c`) hold work-in-progress methods. Check whether your branch is behind `master` before basing work on it.
- WIOD16/EORA sources also need EUKLEMS auxiliary data (`prepare_euklems_data*.R`) and `complementar/euklems/` tables; EXIOBASE 3.7 lacks `Z.txt` (see commented paths in `prepare_exiobase_data.R`).
