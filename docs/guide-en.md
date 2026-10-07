# WLVDB guide for economists

<!-- documentation-revision: wiod-reader-workflows-v2 -->

[Português](guide-pt.md) | English | [Home](../README.md) | [Dictionary](results-dictionary-en.md)

## Understand the project

The World Labour Values Database transforms monetary production and trade
accounts into estimates of the labour required to reproduce commodities.
It supports research on the international distribution of labour, remuneration
and labour-force reproduction, and transfers associated with trade. WLVPanel
presents the database's published results.

For a first reading, follow this section and [methodology](#methodology).
To work with existing data, go to [use the results](#use-the-results) and the
dictionary. To produce results, follow [run the project](#run-the-project).
The [code map](#understand-the-code) follows the same data journey.

This guide connects three kinds of work. The [theory](theory-en.md) explains
what the concepts mean and why input-output accounts can estimate them;
the [mathematical methodology](methodology-en.md) develops the equations;
the [assumptions and remaining work](assumptions-en.md) identify the conditions
under which the estimates should be interpreted. Consult the
[ABNT references](references-en.md) for the methodological literature.

| Your immediate goal | What you need | Where to start |
| --- | --- | --- |
| Analyse an existing indicator | An authenticated result publication, R and the dictionary. | [Use the results](#use-the-results). |
| Reproduce the database | The identified code, pinned source files, package environment, time and storage. | [Choose the level of reproduction](#choose-the-level-of-reproduction). |
| Improve a formula or add coverage | A stated economic question, a code change and evidence appropriate to that change. | [Contribute an improvement](#contribute-an-improvement). |

### Coverage and limitations

| Executable method | Years | Source countries/regions | Industries | Published indicators |
| --- | --- | --- | --- | --- |
| `wiodr13` | 1995–2009 | 40 countries and rest of the world | 35 | 58 |
| `wiodr16` | 2000–2014 | 43 countries and rest of the world | 56 | 50 |

WIOD means *World Input-Output Database*. The numbers 13 and 16 identify source
releases, not the final calculation year. The upstream WIOD 2013 release
extends to 2011, but this method's contract ends in 2009. WIOD13 capital-data
coverage declines in 2008–2009. Historical preparation converts a pinned set
of source absences to zero; files can therefore contain finite capital values
and rates without complete economic coverage in those years. WLVPanel excludes
2008–2009 from all WIOD13 series for this reason: its practical coverage ends
in 2007. This is a panel filter, not a general `NA` mask in the database.
Do not interpret compatibility zeros as observed zero capital. Industry classifications differ between releases, so joining
series by position or similar industry names is invalid. Inspect run labels
and construct an explicit economic correspondence before comparing sources.

Both methods give equal weight to an hour of labour. Classifying labour as
productive or unproductive is a methodological choice, recorded in
`methods/<method>/_sectors.csv`, rather than a natural property of the data.
Estimates also depend on rest-of-world imputations, supplementary Chinese
labour data in WIOD16, capital composition and anomaly treatment. Results alone
do not establish a causal explanation for differences between countries.
EXIOBASE and EORA are future expansion only; alternative methods and paper
generation are not executable here.

### Glossary before the formulas

| Term | Meaning and identifier |
| --- | --- |
| Input-output | Accounts of deliveries from each industry to others and to final demand. Abbreviated IO. |
| Gross output / value added | Gross output includes intermediate inputs (`gross_output`); value added subtracts them (`gdp`). GDP means gross domestic product. |
| Socioeconomic accounts | Employment, hours, compensation and capital associated with industries. SEA abbreviates *Socio-Economic Accounts*. |
| Persons engaged / employees | `emp` includes employees and non-employees; `empe` covers employees. They are not interchangeable. |
| Abstract labour | Hours weighted by the methodological multiplier (`abstract_labour`), equal to 1 in current methods. |
| Embodied value | Direct labour plus labour required by inputs and depreciation (`values`, `value.m.mv`). |
| Variable capital / labour force | Estimated value of the basket financed by wages (`labour_force_value`), not wages in dollars. |
| Surplus value / exploitation rate | Abstract labour divided by labour-force value, minus 1 (`surplus_value`). The productive variant restricts industries. |
| Constant capital / depreciation | Inputs and assets used in production, and their annual wear; `k_composition` and `k_depreciation` allocate assets by origin and use. |
| Gross fixed capital formation | GFCF: investment used to help distribute capital stock among supplying industries. |
| EU KLEMS | European source for capital (K), labour (L), energy (E), materials (M) and services (S), used here for capital composition and depreciation. |
| Consumption basket | Household consumption purchase shares, used to estimate labour-force reproduction. |
| Direct price | A price proportional to embodied labour, converted by a world factor to USD (`.du`). Not an observed price. |
| Rest of the world / world | `ROW` is the residual source region; `WWW` is the calculated world total. Summing both again duplicates the total. |
| USD / local currency | United States dollar / each country's currency. Exchange rate is local currency per USD. |
| Index / ratio / weighted mean | An index compares with a base year; a ratio divides two quantities; a weighted mean gives more influence to economically larger components. |
| Matrix / array / axis | A matrix is a table of rows and columns; an array adds axes such as year and indicator. An axis identifies one dimension. |
| Vector / linear system | An ordered list of numbers / a set of addition and multiplication relationships among quantities to determine. |
| Module / dependency | A function calculating part of a result / an input required by that function. |
| Run / release / channel | An immutable published execution / a coherent collection of those executions / the name selecting its current version. |
| Manifest / checksum / provenance | A file inventory / a fingerprint calculated from bytes / a record of data, code and environment origins. |
| Contract / sidecar | A verifiable rule for units, structure or science / an auxiliary file accompanying values. |

Identifiers follow historical conventions: `.s` usually denotes a total,
`.m` an average measure, `.r` a ratio, `.us` USD, `.mv` magnitude of value,
`.hr` hours, and `.un` a count or factor. `.p` and `.u` distinguish productive
and unproductive components. `hs`, `ms`, `ls` mean high, medium and low skill.
Do not infer units solely from suffixes: compensation `.cu` is constant USD,
and `.pc` can mean a share or an index. The dictionary resolves every case.

## Methodology

Each annual monetary matrix cell records a delivery from the industry-country
in the **row** to the purchaser in the **column**. The first columns are
producing industries; the remaining columns represent consumption, investment
and other final-demand categories. A row sum measures the supplier's sales.
A column sum collects inputs used by the purchaser. In the capital matrix,
a column sum recovers the stock of the industry using those assets. Preserve
this orientation: transposing the table changes its economic meaning.

Calculation follows these operations:

1. **Normalize:** convert million USD to USD, thousand persons to persons,
   and million hours to hours. Base-100 price indices become base 1 in the
   normalized generation. Conversions are recorded and are not repeated when
   reading results.
2. **Construct labour and capital:** convert compensation using national
   value-added totals in local currency divided by USD totals. Multiply hours
   by the complex-labour factor. Allocate capital using EU KLEMS composition
   and WIOD investment, applying the following year's depreciation rate.
3. **Calculate embodied labour:** divide intermediate inputs plus depreciation
   by gross output in each productive column. The resulting matrix, called
   `C`, describes monetary input requirements per USD of output. Vector `l`
   gives direct hours per USD. Vector `lambda` satisfies
   `lambda = l + t(C) × lambda`: each commodity embodies its direct labour
   and the labour of its inputs. `t(C)` exchanges rows and columns to sum the
   purchaser's requirements. The program solves `t(I - C) × lambda = l`,
   where `I` keeps each component in its own position. It does not need to
   construct the full inverse. Only industries classified as productive enter
   the system; the output respects structural zeros.
4. **Estimate baskets and trade:** multiply monetary flows by the supplier's
   `lambda` to obtain embodied hours. The national consumption basket converts
   compensation into reproduction costs in hours. A fixed basket, from 1995
   for WIOD13 and 2000 for WIOD16, underlies the indices; published indices
   are subsequently rebased to 2000. Basket year and presentation base year
   are different concepts.
5. **Aggregate and validate:** sum extensive quantities (hours, persons and
   amounts), use weights or ratios of totals for intensities and rates, check
   economic identities and numerical errors, and publish only validated results.

In a one-industry example, each USD of output requires USD 0.20 of inputs
and 0.40 direct hours, so each unit embodies `0.40 / (1 - 0.20) = 0.50`
hours. USD 100 of output represents 50 hours, of which 40 are direct and 10
are embodied in inputs. This teaching example contains no WIOD data.

```r
coefficient <- 0.20
direct_hours <- 0.40
embodied_hours <- direct_hours / (1 - coefficient)
stopifnot(abs(embodied_hours - 0.50) < 1e-12)
```

If employees perform 1,000 abstract hours and their basket requires 400 hours,
the surplus-value rate is `1000 / 400 - 1 = 1.5`, displayed as 150%. This
does not permit substituting dollar wages for basket hours. The appropriated
profit rate uses `(capital compensation - depreciation) / capital stock`:
it is an accounting approximation, distinct from the Marxian rate of surplus
value over constant plus variable capital.

For transfers, the annual factor relates labour embodied in trade to the
prices of world productive trade. Each flow compares value represented by
its price with embodied labour. A positive national balance indicates net
receipt. In the bilateral `m_countries` matrix, the sum of
`transfers_productive_values` flows cancels within tolerance; `transfers_values`,
including unproductive industries, has no such requirement. This sum of flows
differs from summing national exports-minus-imports balances, which cancel
worldwide by construction. Direct prices
use another factor: world gross output in USD divided by world gross output
in hours.

### Assumptions affecting interpretation

The rest of the world has no complete observed accounts: modules combine
supplemental employment with hours and capital-intensity relationships from
reference countries, as well as price indices. ROW compensation and employee
accounts remain absent in the public method. For WIOD16, China receives hours per
worker derived from WIOD13 and all persons engaged are treated as employees.
The last available coefficient is held through 2014. This industry mapping
has an authenticated historical file but no original reconstruction script.
WIOD13 also approximates Chinese employees by all persons engaged, for both
person counts and hours; its skill shares are specific to that release and
have no published equivalent in WIOD16.

Known negatives are not indiscriminately erased. Capital allocation truncates
24 WIOD13 and 649 WIOD16 GFCF cells to zero only after exact positions and
magnitudes have been verified. Raw data remain intact. There are 93 WIOD13
and 120 WIOD16 columns with fallback allocation using national GFCF. WIOD13
preserves the signed capital exception at `2006/GBR.23`. WIOD16 has its own
capital, EU KLEMS weight, Malta and Romania exceptions. The
[WIOD13](wiodr13.md) and [WIOD16](wiodr16.md) source contracts enumerate these
cases; published reports help assess their relevance to an analysis.

A simple mean generally does not represent an aggregate rate. Two industries
with indices 1 and 3 and outputs 10 and 30 have a weighted index of 2.5.
Two industries with embodied values of 20 and 120 hours and outputs of 10
and 30 USD have aggregate intensity `140 / 40 = 3.5` hours/USD. National
exchange rates and indices receive no world mean, because currencies and
economic bases are not comparable.

## Use the results

Data are available through [World Labour Values](https://panel.worldlabourvalues.org/)
and [LabCidades/UFES](http://labcidades.ufes.br/worldlabourvalues/).
The [use workflow](use-results-en.md) starts in the browser and follows
selection, coverage, interpretation and citation without requiring R.
The [indicator-family cards](indicator-families-en.md) help choose a measure.

Cloning this repository supplies code, configuration, documentation and
versioned supplements; `source_data/` and `results/` are not included in Git.
A selection exported through the website can be analysed according to its
fields and metadata. Do not treat it as a complete native publication: the
FST reading examples below require the channel, release and referenced runs,
including manifests and sidecars. Inspect the obtained material before choosing
a reader; a CSV or spreadsheet is not input to `read_fst_array()`. The full
calculation described in this guide also produces a native publication.
Test fixtures are illustrative data.

### Files and units

A published execution, or *run*, lives in `results/runs/<method>/<run_id>/`.
A *release* in `results/releases/<release_id>/` fixes which runs belong
together in a published version. Channel `stable`, in
`results/channels/stable/`, selects the current release through numbered
markers. `stable` is a selection name, not an external certification. An
execution's identifier differs from `result_id`, which identifies stable
result content.

| File | Contents and axis order |
| --- | --- |
| `sea_sectors.fst` | Year, indicator, industry, country. Industry accounts. |
| `sea_countries.fst` | Year, indicator, country. National aggregates and `WWW`. |
| `m_io*.fst` | Year, matrix indicator, input, output. May be split into periods; check each file's years. |
| `m_countries.fst` | Year, matrix indicator, origin country, destination country. Bilateral flows, zero domestic diagonal. |
| `*.fst.meta` | Dimensions, labels and cryptographic binding to the FST file. FST is the binary table-storage format used here. |
| `_unit_contract.csv` | Stored units, display multipliers, index bases and aggregation rules actually executed. |
| `_states.csv` / `_anomalies.csv` | Reasons for missing values / events and special treatments, including partial coverage. |
| `_scientific_checks.csv` / `_leontief_diagnostics.csv` | Checked economic identities / stability and accuracy of the linear system. |
| `_gfcf_negative_cells.csv` / `_gfcf_negative_summary.csv` | Investment cells changed in allocation and effect summaries. |
| `_method_solutions.csv` / `meta_indicators.RDS` | Indicator selection / method-specific descriptions and display metadata. |
| `run_manifest.json` / `release_manifest.json` | Inventories, hashes, identity and provenance of the execution / published version. |

CSV is a text table (semicolon-separated in these sidecars); RDS stores an R
object and JSON records structured fields readable as text.

In `m_io`, `values` measures abstract hours, `k_composition` and
`k_depreciation` measure USD, and `consumption_basket` contains unitless
shares. The basket's final-demand block is not applicable. `transfers_values`
measures transfers in hours. Capital matrices have their own column domain:
do not assume all matrix indicators fill the same rectangular region. The
reader and metadata preserve the effective shape.

Every indicator is explained in the [complete dictionary](results-dictionary-en.md).
A stored index of 1 means 2000 = 1. WIOD13 displays it as 1; WIOD16 uses
100 points, following its method-specific contract. A stored rate
of 0.25 may display as 25%. Apply `display_multiplier` exactly once. Do not
apply another rule based on the old `type` field. Current monetary values
are not inflation-adjusted; abstract hours also depend on method assumptions.
Always compare the same unit, labour concept, classification and contract
version.

`NA` is absence, not zero. `source_missing` identifies declared source
absence; `not_applicable` identifies an operation without meaning at that
coordinate. `uncomputed` is an unfinished calculation and cannot be published.
`NaN` and infinities are errors, not missingness categories. Aggregates can
use available components and record partial coverage; a wholly missing group
remains `NA`. Do not sum countries including `WWW`, or obtain national rates
by averaging industry rates.

The standard ratio calculations sum numerator and denominator independently,
so their coverage can differ. For instance, world (`WWW`) persons-engaged
surplus-value rates can include ROW hours without corresponding reproduction
costs, since ROW compensation is absent. Check each operand's coverage before
using the rate; a finite result does not guarantee matching populations.

### Read and select data in R

R is the language used for calculations. Run the following instructions from
the repository root after installing packages and obtaining a published
release. `source()` loads instructions from a file; `<-` assigns a name to
an object. The bootstrap below creates a private environment called `wlv`.
Do not load `scripts/main.R` directly.

```r
source("renv/activate.R")
bootstrap <- new.env(parent = baseenv())
sys.source("scripts/runtime_bootstrap.R", envir = bootstrap)
wlv <- bootstrap$wlv_load_runtime(".")
run_dir <- wlv$wlv_current_result_dir("wiodr13", root = ".", channel = "stable")
countries <- wlv$read_fst_array(file.path(run_dir, "sea_countries.fst"))
dimnames(countries)
gdp <- countries[, "gdp.s.us", "BRA", drop = FALSE]
print(gdp)
units <- read.csv2(file.path(run_dir, "_unit_contract.csv"), stringsAsFactors = FALSE)
units[units$indicator == "gdp.s.us", ]
states <- read.csv2(file.path(run_dir, "_states.csv"), stringsAsFactors = FALSE)
head(states)
```

The reader resolves the manifest chain before loading results. Do not manually
select the directory with the most recent date. Within brackets, an empty
position selects all years; names select indicator and country. `drop = FALSE`
retains axes even when selecting a single country. Use names returned by
`dimnames`, never assumed positions. Change the method to `wiodr16` to read
the other source.

### Turn a selected series into an analysis table

The initial question is the surplus-value rate of employees in industries
classified as productive in Brazil, from 1995 to 2007. This code continues
the previous session, retains all years for auditing and marks the intended
scope; stored ratios and displayed percentages have the same definition.
The [complete example](use-results-en.md#read-a-native-publication-in-r) links
the series to states and anomalies before a use decision is made.

```r
indicator <- "surplus_value.empe_p.r.pc"
unit <- unique(units[units$indicator == indicator,
  c("canonical_unit", "display_unit", "display_multiplier")])
stopifnot(nrow(unit) == 1L)
series <- countries[, indicator, "BRA", drop = FALSE]
analysis <- data.frame(
  year = as.integer(dimnames(series)[[1L]]),
  country = "BRA",
  indicator = indicator,
  stored_value = as.vector(series),
  stringsAsFactors = FALSE
)
analysis$display_value <- analysis$stored_value *
  as.numeric(unit$display_multiplier[[1L]])
analysis$display_unit <- unit$display_unit[[1L]]
analysis$in_requested_period <- analysis$year %in% 1995:2007
analysis$wiodr13_coverage_alert <- analysis$year %in% 2008:2009
print(analysis)
```

The unit sidecar repeats each indicator for its aggregation levels;
`unique()` extracts its common display definition. The resulting `analysis`
is an ordinary R data frame, suitable for a chart, a statistical model or an
explicit CSV export in your analysis project. Missing observations remain
missing. Review `_states.csv` and `_anomalies.csv` before interpreting a
series or discarding rows.

This indicator restricts the population to **employees in productive industries**.
The `surplus_value.empe.r.pc` variant also includes unproductive industries;
`emp` includes non-employees. These choices answer different questions.
A displayed value of 150 means 150%, not 150 hours; moving to 160% is a change
of 10 percentage points. Use the published national rate rather than the mean
of industry rates. Scope columns do not authorize automatic inclusion: inspect
states, anomalies and operand coverage. Years 2008–2009 remain in the audit
table but fall outside the introductory selection.

### Record the data behind an analysis

The channel can select a different release tomorrow. Record the immutable run
used today and preserve the complete manifests alongside the analysis:

```r
manifest <- jsonlite::fromJSON(
  file.path(run_dir, "run_manifest.json"), simplifyVector = FALSE)
manifest[c("method", "run_id", "result_id", "parent_run_id")]
manifest$output_contract
str(manifest$result$provenance, max.level = 2L)
```

The inspected provenance belongs to the calculation, whereas the commit of
your analysis script describes what you subsequently did with its output.
An adequate data note identifies both, the method, years, indicator IDs,
countries/sectors, units, source and unit-contract versions, `run_id`,
`result_id`, the corresponding release, any selection or transformation,
and the access date. Include the relevant
[bibliographic references](references-en.md). Cite a reproduced publication
as that publication; do not silently attribute its results to the current
checkout or merely to the moving `stable` channel.

For external analysis, copy only the selection you need and record the run
and contract. Your research script and outputs can belong to another project.
Experiments within this repository must use a campaign in `temp/<id>/`.
Do not edit published runs. WLVPanel selects its channel through
`WLV_RELEASE_CHANNEL` and verifies manifests, files and metadata; copying
only an FST does not provide a complete panel publication.

Publication is already the export consumed by the panel: there is no second
scientific conversion to run. To install data in another WLVPanel checkout,
place the complete channel, release and referenced-run tree in its `results/`
directory, preserving names and bytes. The panel's `utils/prepare_data.R`
reads that tree and creates display objects. Application installation and
dependencies are documented in the
[WLVPanel repository](https://github.com/rodrigofranklin/wlvpanel).

## Run the project

### Choose the level of reproduction

| Level | Operation | What it establishes |
| --- | --- | --- |
| Reproduce an analysis | Read the same immutable publication and rerun the selection, transformation and analysis script. | The same input data support the reported table or finding. It does not recompute the database. |
| Recalculate selected indicators | Use `recalc_wlv` with a compatible published parent and normalized sources. | Selected variables can be reconstructed while the authenticated matrices are reused. |
| Reproduce the full calculation | Restore the identified environment, prepare pinned sources and run `get_wlv` or the CLI. | The database can be rebuilt from the declared statistical inputs and assumptions. |
| Check software or sensitivity | Run synthetic tests, or conduct a separately identified campaign varying an assumption. | Tests check specified behavior; sensitivity measures dependence on an assumption. Neither alone reproduces the original empirical result. |

First identify the target publication and its code/environment provenance.
The current branch contains the current implementation; it is not necessarily
the version that produced a historical result. Match source identities,
supplements, classification and contracts before comparing outputs. A new
execution receives a new `run_id`; compare numerical values within the
declared tolerances, together with axes, units, missingness and diagnostics.
Equal rounded numbers or a successful exit code alone are insufficient.
Rebuilding the database also does not automatically reproduce the figures,
sample restrictions or specifications of a published article: those require
the article's own analysis steps.

### Installation and preparation

Use Git to obtain the repository and enter the cloned directory. Git records
code revisions; `git rev-parse HEAD` prints the exact commit. Install R 4.6.1,
the version pinned by `renv.lock` and continuous integration. A terminal
executes `Rscript` commands; an R session executes this guide's `r` blocks.
Do not enter code-fence markers along with a command.

Obtain the installer from the official [R for Windows page](https://cran.r-project.org/bin/windows/base/)
or follow the [official Ubuntu repository instructions](https://cran.r-project.org/bin/linux/ubuntu/).
Confirm R 4.6.1 before restoring packages; an older distribution's default R
may differ. On Windows, the [official Rtools page](https://cran.r-project.org/bin/windows/Rtools/)
identifies the compatible toolchain when package compilation is necessary.
With the correct R already installed, Ubuntu 24.04 build dependencies for the
pinned packages can be installed with:

```sh
sudo apt-get update
sudo apt-get install --no-install-recommends git build-essential gfortran pkg-config libcurl4-openssl-dev libssl-dev libxml2-dev libicu-dev zlib1g-dev
Rscript --version
```

These libraries support curl, openssl, xml2, stringi and C/C++ components in
`renv.lock`; the `sudo` commands are Ubuntu-specific. Current calculation
requires no graphical editor, LaTeX or paper-generation tools.
Choose your preferred IDE or editor; the repository does not version RStudio
project files or personal IDE settings. All documented commands work from the
repository root in a terminal.

```sh
git clone https://github.com/rodrigofranklin/wlvdb.git
cd wlvdb
Rscript --vanilla scripts/bootstrap.R
Rscript --vanilla scripts/run_wlv.R --help
Rscript --vanilla scripts/run_wlv.R --list-methods
Rscript --vanilla scripts/run_wlv.R --method wiodr13,wiodr16 --prepare-only --check
Rscript --vanilla scripts/run_wlv.R --method wiodr13,wiodr16 --prepare-only
```

`renv` restores recorded package versions, not economic data. Restoration
requires internet access. On Windows, use package binaries when available;
compilation requires Rtools matching the R version. On Ubuntu, compiled
dependencies may require build tools and development libraries for curl, SSL
and XML. CI (continuous integration: automatic checks on each change) runs
Windows 2022 and Ubuntu 24.04. See [the workflow](../.github/workflows/r-ci.yml)
for the exact environment.

Preparation downloads pinned sources, verifies sizes and checksums, extracts
supported years, normalizes units and validates axes and missingness. Data
live in `source_data/`, including `normalized/` and its manifest. Versioned
supplementary files live in `complementar/`. Cached sources are verified before
reuse. Old shared download packages are unnecessary. `--check` verifies only
arguments and dependencies; actual preparation validates source data.

The download paths and accepted source identities are described in the
[WIOD13](wiodr13.md) and [WIOD16](wiodr16.md) contracts. Source preparation
depends on the providers continuing to serve those exact files. If a file
cannot be obtained or fails its checksum, retain the diagnostic and seek the
authenticated source; replacing it with the latest similarly named file
changes the experiment. A documented historical supplement can be reproduced
as an input without its original construction being independently repeatable:
the Chinese-hours mapping is one such remaining limitation.

### Calculation, recalculation and publication

```sh
Rscript --vanilla scripts/run_wlv.R --method wiodr13,wiodr16 --workers 1 --channel stable
```

This command calculates both methods and publishes the release only when both
pass. Add `--repeat-pp` to prepare and calculate in one call. `workers = 1`
runs sequentially. Larger values create auxiliary R processes and may increase
memory consumption; do not assume linear speedup. To select a separate channel
for a principal run, use `--channel research/input-v3`. An experimental campaign
also requires isolated directories: changing the channel alone does not change
the data and result root.

In the R session initialized by the reading example, the API (function
interface) provides:

```r
wlv$prepare_wlv(c("wiodr13", "wiodr16"))
wlv$get_wlv(c("wiodr13", "wiodr16"), workers = 1, channel = "stable")
wlv$recalc_wlv("wiodr13", at_stage = 4, workers = 1, channel = "stable")
wlv$recalc_wlv("wiodr16", at_stage = 5,
  sea_vars = "gross_output.s.du", workers = 1, channel = "stable")
```

Execute only the desired operations: preparation and calculation above are
alternatives to terminal commands, not additional mandatory steps.
The public functions return the processed method names invisibly; the data
are written to the published run. Read them with the result reader shown
above. The public CLI and these API functions do not offer year, country or
sector filters for a full calculation: each method runs its contracted
coverage. Select a smaller research sample when reading the results.

Recalculation updates variables from an authenticated published run while
preserving matrices, without rebuilding investment allocation or solving
Leontief again. It does not replace a full calculation after source, matrix
assumption, unit or classification changes. Compatible normalized sources
and provenance remain mandatory.

Accepted stages are `1`, `4` and `5`. Stage 1 rebuilds variables from the
beginning and does not accept `sea_vars` selection. Stage 4 rebuilds
matrix-derived indicators and subsequent stages; stage 5 rebuilds final
indicators. Selection at 4 or 5 accepts only existing indicators at that stage
or later. Only selected indicators are replaced; unselected dependencies use
the authenticated parent. Dependent indicators outside the selection are not
implicitly updated. With the same scientific inputs, recalculated indicators
must equal full calculation within tolerance; labels, missingness, structural
zeros and unselected cells are exact.

The [calculation/recalculation correction](validation/issue-28.md) separates
the source price index used by WIOD13 baskets from the rebased published
index. Stage 4 uses authenticated source `GO_P`, with base 1995 = 1 and the
USA → ROW assumption, together with 1995 monetary consumption shares.
Substituting the sector index rebased to 2000 changed the basket's relative weights. The
historical difference affected both basket indices and both constant-price
compensation indicators. A parent predating the correction requires a fresh
full calculation because semantic provenance changed; it is not relabelled
with the new provenance.

Each publication writes to a provisional area (*staging*), rereads files,
validates science and integrity, and installs a new immutable run.
Recalculation records `parent_run_id`, linking child and parent. The channel
marker is written last. If any step fails, the previous release remains
visible. Failure can leave an unreferenced run, but not a partial version
selected by the panel. A global lock prevents concurrent publication.

### Resources

Compressed WIOD13 inputs total approximately 300 MB, WIOD16 647 MB, plus
174 MB of shared EU KLEMS inputs. This is not total storage: extraction,
normalization, matrices, provisional copies and immutable history add space.
A previous campaign verified 9.96 GB of prepared/supplemental files. Check free
space before repeating a run; do not silently use another volume.
MB/GB use millions/billions of bytes; MiB/GiB use powers of two
(1 GiB = 1,073,741,824 bytes). Resident memory is the RAM occupied by a process.

[Real issue #13 measurements](validation/issue-13.md) record the Windows/R
4.6.1 candidate's sequential WIOD16 calculation at about 1,151 s (19.2 min),
with peak resident memory of 15.54 GB (14.48 GiB). Recalculation from stage 1
used 736 s and 15.94 GB; stage 5 used 392 s and 2.77 GB. WIOD13 calculation
with two workers used 427 s and 5.45 GB. These are observations from that
machine and revision, not guaranteed minima or forecasts for other computers.
Leave memory for the operating system and temporary copies; a 16 GB machine
is close to WIOD16's observed peak. First-time downloads can take longer than
the campaign's measured preparation with cached inputs.

The [Leontief benchmark](leontief-benchmark.md) measures only one annual system:
0.38 s and 121.78 MiB for the WIOD16/2013 productive block. Do not interpret
this as the memory requirement or duration of the full calculation.

### Validation and common errors

Synthetic tests use small numbers to verify integration; they do not replace
scientific evidence from real sources. To reproduce the suite, create a
campaign and set `TEMP`, `TMP`, `TMPDIR` before starting R, as described in
[local campaigns](local-campaigns.md). Install
[PowerShell 7.5 or later](https://learn.microsoft.com/powershell/scripting/install/installing-powershell),
open `pwsh` at the repository root and run the block below. Windows PowerShell
5.1 does not satisfy the requirement. The same creation block works on Ubuntu
with PowerShell installed; `$campaign` receives an object, not a line of text.
On Linux without PowerShell, the bash equivalent prints `key=value` lines
(use `root=` and `temporary_directory=`) and the block becomes:

```bash
campaign=$(bash scripts/manage-campaigns.sh -Action New -Id local-check \
  -Purpose 'Local unit and synthetic integration checks')
root=$(printf '%s\n' "$campaign" | sed -n 's/^root=//p')
scratch=$(printf '%s\n' "$campaign" | sed -n 's/^temporary_directory=//p')
export TEMP="$scratch" TMP="$scratch" TMPDIR="$scratch" WLV_CAMPAIGN_ROOT="$root"
R --vanilla
```

```powershell
$campaign = ./scripts/manage-campaigns.ps1 -Action New -Id local-check -Purpose 'Local unit and synthetic integration checks'
$env:TEMP = $campaign.temporary_directory
$env:TMP = $campaign.temporary_directory
$env:TMPDIR = $campaign.temporary_directory
$env:WLV_CAMPAIGN_ROOT = $campaign.root
R --vanilla
```

If `local-check` already exists, inspect `-Action Status -Id local-check` and
resume it when appropriate instead of creating duplicate work. In the R
session started above:

```r
source("renv/activate.R")
testthat::test_dir("tests/testthat", reporter = "summary",
  stop_on_failure = TRUE, stop_on_warning = TRUE)
```

Exit R without saving (`q(save = "no")`), close the campaign with `Complete`
or `Fail` and follow the documented cleanup. `Clean` inspects Windows processes
and requires Windows; `New`, `Status`, `Complete` and `Fail` also work in
PowerShell on Ubuntu. Hosted CI runners discard the campaign and checkout
when the job ends. CI checks PowerShell, R 4.6.1 and temporary-file placement
before the suite; its package cache lives in `renv/local/ci-cache/`, separately
from test data.

```sh
Rscript --vanilla scripts/render_method_catalog.R --check
Rscript --vanilla scripts/render_results_dictionary.R --check
```

| Message/situation | Action |
| --- | --- |
| Missing package | Rerun `scripts/bootstrap.R` using the correct R version and internet connection. |
| Download/checksum failure | Preserve the message and affected file. Resume official preparation; do not disable hashes or substitute a newer source. |
| No published results | Perform a full calculation on the desired channel before recalculation. Historical `results/<method>/` directories are not valid inputs. |
| Incompatible contract/provenance | Prepare/calculate afresh as required by the change. Do not edit manifests to authorize old files. |
| Invalid stage/indicator | Use 1, 4 or 5 and find the indicator's stage in `_method_solutions.csv`; selection is allowed only at 4 and 5. |
| Missingness, identity or Leontief error | Read the coordinate and `results/diagnostics/`. Preserve evidence and fix the cause; do not replace the value with zero. |
| Lock or insufficient memory/storage | Check for an active execution before intervening. Use one worker and clean only closed campaigns through the manager. |
| Panel rejects a file | Verify the complete channel, release, run, FST and sidecar chain, and the configured channel. |

## Understand the code

`scripts/` contains application code and maintenance commands. The package
restorer `scripts/bootstrap.R` and private loader `scripts/runtime_bootstrap.R`
serve different purposes. `tests/` contains verification code and controlled
example data (fixtures) maintained in Git. Generated test results, logs and
campaign data belong in `temp/<id>/`, ignored by Git; do not write them next
to test code.

| Entrypoint/directory | Role in the workflow |
| --- | --- |
| `scripts/bootstrap.R`, `renv.lock` | Reproducible package environment. |
| `scripts/run_wlv.R`, `scripts/runtime_bootstrap.R`, `scripts/main.R` | Terminal commands, private loading and public functions `prepare_wlv`, `get_wlv`, `recalc_wlv`. |
| `catalog/`, `config/`, `parameters/`, `methods/` | Support, units, module/indicator selection, dependencies and economic classification. CSV row order does not determine execution order. |
| `scripts/preparation/`, `scripts/lib/preparation_*`, `source_normalization.R` | Verified downloads, preparation and normalized generation. |
| `scripts/modules/native/source_modules.R`, `indicator_source_derived_modules.R` | Observed and derived variables: employment, hours, exchange, capital and prices. |
| `scripts/modules/native/assumption_modules.R`, `capital_matrix_modules.R` | Economic completion and capital allocation. |
| `scripts/modules/native/matrix_modules.R`, `indicator_common_modules.R` | Values, trade, baskets and economic indicators. |
| `scripts/lib/native_planner.R`, `native_store.R`, `execution.R` | Dependency ordering, resource management and calculation/recalculation. |
| `scripts/lib/scientific_validation.R`, `leontief_diagnostics.R`, `missingness.R` | Identities, numerical stability and missing-value meaning. |
| `scripts/lib/publication*.R`, `contracts/results/` | Provenance, inventories and transactional WLVPanel publication. |
| `tests/testthat/`, `tests/manual/`, `docs/validation/` | Automated tests, reproducible real-data proofs and revision evidence. |

Start with the module for your indicator and read its inputs, units and
assumptions before changing its formula. The dependency graph is the list of
relationships “A needs B”; it orders functions with explicit context instead
of executing historical scripts scattered across the repository.
[Scientific comments](code-commenting.md) explain decision points. Changing an
economic rule requires revising contracts, tests, the dictionary and both
guides together. The [synchronization convention](documentation-sync.md)
defines that review.

## Contribute an improvement

An issue reports a question or defect; a pull request (PR) proposes a concrete
change for review. Contributions can improve explanations, a source mapping,
an economic assumption, a numerical calculation or coverage. State which of
these is changing so reviewers can judge the required evidence.

### Follow one indicator from its meaning to its output

Take `surplus_value.empe.r.pc`, the employee surplus-value rate. Its definition
is total abstract employee labour divided by the estimated value of employee
labour power, minus one. To investigate or improve its implementation:

1. Read [theory](theory-en.md), [methodology](methodology-en.md),
   [assumptions](assumptions-en.md) and its dictionary entry. Specify the
   affected population, unit and expected behavior before changing code.
2. Find `wlv_indicator_surplus_value_empe_r_pc_spec()` in
   `scripts/modules/native/indicator_common_modules.R`. It names the two input
   indicators and calls `wlv_native_stage5_ratio_spec()` in that same file.
   The shared factory defines stage 5, zero-denominator handling and the
   calculation at sector and country levels. Read that factory as well as
   the small indicator wrapper.
3. Trace registration in `scripts/modules/native/zz_indicator_registry.R` and
   selection in `config/modules/common.csv`. Published indicator lists are
   in `config/outputs/sources/wiodr13.csv` and `wiodr16.csv`. The applicable
   `contracts/units/*_v2-units.csv` and `*_v2-aggregations.csv` define stored
   units, display and aggregation. `_method_solutions.csv` in a published
   run is generated evidence of the selected stages, not a source file to
   edit. Legacy similarly named scripts in `scripts/modules/variables/` do not
   replace the active native implementation.
4. Use an independently calculated example to establish expected behavior.
   If two sectors have labour of 100 and 300 hours and labour-power values of
   50 and 100 hours, their rates are 100% and 200%; the aggregate is
   `400 / 150 - 1 = 1.666...`, or about 166.67%. A simple average gives 150%
   and is wrong for this aggregate. Cover a zero denominator and a wholly
   missing group as well. These cases check the intended economic behavior,
   rather than merely repeating the implementation in a test.
5. Match evidence to the change. An editorial correction needs bilingual
   meaning and documentation checks. A formula correction additionally needs
   relevant tests, numerical comparisons and disclosure of affected outputs.
   A changed upstream assumption may require full calculation; selective
   recalculation does not automatically replace dependent indicators outside
   the selection.

The relevant files can be located from the repository root with:

```sh
rg -n 'surplus_value.empe.r.pc|wlv_native_stage5_ratio_spec' scripts/modules/native config contracts/units docs/indicator-descriptions.csv
```

### Add an indicator or extend the method

| Proposed change | Implementation and documentation to inspect |
| --- | --- |
| Clarify an existing indicator | `docs/indicator-descriptions.csv` has PT/EN descriptions; the paired guides explain interpretation. Generated dictionary pages must be regenerated rather than edited directly. |
| Add a derived indicator | A native module specification and explicit registry entry; selected modules in `config/modules/`; selected outputs in `config/outputs/`; applicable unit/aggregation contracts; economic descriptions, missingness behavior and tests. |
| Change labour classification or an imputation | `methods/<method>/_sectors.csv`, active assumption modules, affected matrix dependencies, scientific contracts and sensitivity evidence. Preserve the interpretation of existing published results. |
| Add a statistical source or release | `catalog/sources.csv`, `catalog/methods.csv`, `scripts/preparation/registry.R`, source preparation and normalization, sector/country correspondence, unit and missingness policies, native modules and independent validation. A download adapter alone is insufficient. |

An added source must establish which source fields measure output, inputs,
hours, employment, compensation, investment and capital; their units and
years; the orientation of each axis; and the treatment of unavailable fields.
It also needs source identities and rights, a defensible productive-sector
classification, reproducible mappings and evidence on the resulting estimates.
EXIOBASE, EORA and alternative reduction methods remain deferred until their
public workflow and validation are implemented. Changing a catalogue label
or passing `--allow-experimental` does not supply those missing components.
The [remaining-work register](assumptions-en.md) distinguishes these research
extensions from corrections to currently supported methods.

For an indicator change, start with the relevant tests in
`tests/testthat/test-native-indicator-modules.R`,
`test-native-aggregation-registry.R`, `test-unit-dimensions.R`,
`test-missingness-contracts.R` and `test-scientific-validation.R`.
The public integration and recalculation tests check whether the change
survives the full runtime. Run tests through the campaign workflow in
[validation and common errors](#validation-and-common-errors); keep empirical
comparisons, logs and temporary worktrees inside that campaign. Never use the
preserved campaign 054 for a new attempt.

When economic descriptions or indicator coverage change, regenerate and
check the dictionaries, then review the diff:

```sh
Rscript --vanilla scripts/render_results_dictionary.R
Rscript --vanilla scripts/render_results_dictionary.R --check
Rscript --vanilla scripts/render_method_catalog.R --check
git diff --check
git status --short
```

A reviewable PR explains the economic problem, old and new behavior, affected
methods and periods, assumptions and limitations, changed files, and the
evidence obtained. State explicitly which checks ran and whether any real
source calculation was performed. Include both languages and update contracts
and the documentation revision if scientific semantics or the public workflow
change. Keep generated research data out of Git. Report a failing download
with its source identity and diagnostic; report a numerical discrepancy with
its method, run, indicator, coordinates, observed value and expected behavior.

## Sources and attribution

WIOD13 is the 2013 release, DOI [10.34894/XDTAUZ](https://doi.org/10.34894/XDTAUZ);
WIOD16 is the 2016 release, DOI [10.34894/PJ2M1C](https://doi.org/10.34894/PJ2M1C).
Dataverse records checked on 2026-09-06 were version 2.1 and declared Creative
Commons Attribution 4.0 International (CC BY 4.0). This license permits reuse
with attribution and identification of changes. Release and deposit versions
are different; effective downloads are pinned by file IDs, sizes and hashes
in the [WIOD13](wiodr13.md) and [WIOD16](wiodr16.md) contracts. An updated
deposit does not automatically change the source accepted by the code.

The [official EU KLEMS 2019 archive](https://euklems.eu/archive-history/) also
declares CC BY 4.0. EU KLEMS denotes European analysis of capital (K), labour
(L), energy (E), materials (M) and services (S). Both shared statistical files
have SHA-256 hashes and sizes in [WIOD13](wiodr13.md); the additional
depreciation year is necessary. The 2024 source now shown on the main website
must not silently replace the historical release.

Supplemental files in `complementar/` are versioned: World Bank employment,
Chinese hours and EU KLEMS correspondence/depreciation tables. Their use is
methodological and their identities are recorded in run manifests; they are
not new WIOD observations. The historical China file and missing original
mapping script are documented in the WIOD16 contract. Source rights continue
to apply to derivatives: do not assume a software license replaces data
licenses. Cite WLVDB with method, period, commit, contracts and published IDs,
as well as providers' official citations. Do not use an old “in press” article
notice as a bibliographic reference.

A SHA-256 fingerprint identifies bytes, not the correctness of an assumption.
`_source_manifest.csv` records the normalized generation; the run manifest
records its hashes, supplements, parameters, code, local modification state,
R, packages and `renv.lock` hash. Preserve those records with any data selection
used in analysis. [Issue #13 evidence](validation/issue-13.md) is historical;
[issue #28 verification](validation/issue-28.md) records the recalculation
correction. Campaign 054 is a preserved archive, not a command to repeat.
