# Repository layout

## Entry points

- `main.nf`: pipeline entry point.
- `workflows/repexprep.nf`: main scientific workflow.
- `nextflow.config`: global Nextflow configuration.

## Directories

| Directory | Purpose |
|---|---|
| `assets/` | Small static files and templates distributed with the pipeline |
| `bin/` | Custom executable scripts |
| `conf/` | Execution profiles and process-resource configuration |
| `docs/` | Usage, output and development documentation |
| `modules/local/` | Pipeline-specific Nextflow processes |
| `modules/nf-core/` | Reused nf-core modules |
| `subworkflows/local/` | Groups of related pipeline-specific processes |
| `workflows/` | Main workflow composition |
| `samplesheets/` | Small development and test samplesheets |
| `tests/` | Automated test definitions and fixtures |

## Architectural decisions
- The existing repository is retained rather than regenerated from a template.
- `main.nf` remains the lightweight pipeline entrypoint.
- Scientific process compostion is maintained in `workflows/repexprep.nf`
- Pipeline-specific processes are stored in `modules/local/`whilst reusable standard components will be installed under `modules/nf-core/`
- MetaCentrurm-specific execution settings are explicited in `config/metacentrum.config` .


