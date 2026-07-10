# Documento A — Blueprint nf-core-friendly para xveselsky-repexprep

Arquitectura de repositorio, responsabilidades de carpetas y contrato técnico para una pipeline publicable.

## 0. Propósito del documento

Este documento es un blueprint arquitectónico, no una implementación completa. Su objetivo es describir exactamente qué debe existir en cada carpeta y archivo de un repositorio nf-core-friendly llamado xveselsky-repexprep. La pipeline preprocesará lotes grandes de FASTQ paired-end de WGS para generar archivos FASTA intercalados, de longitud uniforme, con pares completos y cobertura genómica controlada para RepeatExplorer2 / SEQLUST. El flujo de trabajo operativo que debe respetar es: desarrollar localmente o en GitHub Codespaces, guardar en GitHub, entrar a MetaCentrum, clonar el repositorio y ejecutarlo allí con qsub / Nextflow.

> Nota: La idea central es evitar el main.nf monstruo. En una pipeline publicable, main.nf debe ser una puerta de entrada; la lógica real vive en workflows/, subworkflows/ y módulos.

## 1. Contrato científico y funcional

- Entrada primaria: FASTQ paired-end de WGS, idealmente Illumina, con una o más lanes por muestra.
- Salida primaria: FASTA intercalado por muestra, con R1 y R2 consecutivos, solo pares completos, listo para RepeatExplorer2.
- Salida secundaria: FASTA combinado opcional para análisis comparativo, manteniendo identidad de muestra mediante prefijos o cabeceras controladas.
- QC inicial: FastQC y estadísticas de secuencia antes de modificar los reads.
- Limpieza: fastp para trimming, retirada de adaptadores, filtrado de calidad y exclusión de N.
- Filtrado opcional: organelos y rDNA mediante referencia proporcionada por el usuario, sin intentar adivinar referencias automáticamente.
- Normalización: todos los reads finales deben tener la misma longitud, preferentemente entre 100 y 200 nt.
- Muestreo: selección aleatoria reproducible de pares completos para cobertura entre 0.1× y 0.5×, adaptada al tamaño genómico.
- Reproducibilidad: versiones, contenedores, parámetros, hashes, command line, trace, timeline, report y seeds registrados.
- Portabilidad: perfiles para local, test, docker, apptainer/singularity y metacentrum.

## 2. Árbol de repositorio recomendado

```text
xveselsky-repexprep/
├── main.nf
├── nextflow.config
├── nextflow_schema.json
├── CITATIONS.md
├── CHANGELOG.md
├── README.md
├── LICENSE
├── workflows/
│   └── repexprep.nf
├── subworkflows/
│   ├── local/
│   │   ├── input_check.nf
│   │   ├── read_qc.nf
│   │   ├── trim_filter.nf
│   │   ├── organelle_filter.nf
│   │   ├── genome_size_estimation.nf
│   │   ├── length_normalization.nf
│   │   ├── coverage_sampling.nf
│   │   ├── repex_formatting.nf
│   │   └── reporting.nf
│   └── nf-core/
├── modules/
│   ├── nf-core/
│   │   ├── fastqc/
│   │   ├── fastp/
│   │   ├── multiqc/
│   │   ├── seqkit/stats/
│   │   ├── seqtk/mergepe/
│   │   ├── kmc/
│   │   └── genomescope2/
│   └── local/
│       ├── validate_samplesheet/
│       ├── merge_lanes/
│       ├── pair_audit/
│       ├── organelle_filter/
│       ├── choose_target_length/
│       ├── crop_fixed_length/
│       ├── plan_coverage/
│       ├── sample_pairs/
│       ├── rename_convert_fasta/
│       ├── interleave_fasta/
│       ├── validate_repex_fasta/
│       └── archive_sample/
├── bin/
│   ├── validate_samplesheet.py
│   ├── pair_audit.py
│   ├── pair_length_hist.py
│   ├── choose_target_length.py
│   ├── crop_pairs_to_length.py
│   ├── parse_genomescope.py
│   ├── plan_coverage.py
│   ├── sample_pairs.py
│   ├── rename_fastq_to_fasta.py
│   ├── validate_repex_fasta.py
│   └── make_toy_pe_fastq.py
├── conf/
│   ├── base.config
│   ├── modules.config
│   ├── test.config
│   ├── test_full.config
│   └── metacentrum.config
├── assets/
│   ├── schema_input.json
│   ├── samplesheet.example.csv
│   ├── samplesheet.test.csv
│   ├── multiqc_config.yml
│   └── test_data/
├── docs/
│   ├── usage.md
│   ├── output.md
│   ├── metacentrum.md
│   ├── developer_guide.md
│   └── troubleshooting.md
├── tests/
│   ├── nf-test/
│   └── data/
├── .github/
│   ├── workflows/
│   │   ├── linting.yml
│   │   ├── tests.yml
│   │   └── release.yml
│   ├── ISSUE_TEMPLATE/
│   └── PULL_REQUEST_TEMPLATE.md
├── .devcontainer/
│   ├── devcontainer.json
│   └── Dockerfile
└── tower.yml / seqera.yml  optional
```

## 3. Responsabilidades por archivo y carpeta

| Ruta | Rol | Contenido esperado |
| --- | --- | --- |
| main.nf | Entrada mínima del pipeline. | Importa workflows/repexprep.nf, valida que --input existe y llama al workflow principal. No debe contener procesos largos. |
| nextflow.config | Configuración global. | Define manifest, plugins, params por defecto, perfiles, includeConfig, trace/report/timeline/dag y límites generales. No debe codificar rutas privadas de MetaCentrum. |
| nextflow_schema.json | Contrato de parámetros. | Describe --input, --outdir, --target_coverage, --target_read_length, organelle/rDNA flags, recursos, strict modes y validaciones para launch/help. |
| workflows/repexprep.nf | DAG principal. | Conecta subworkflows en orden: input, QC, trimming, filtro, estimación, normalización, sampling, formato RE2, reporting. |
| subworkflows/local/ | Bloques lógicos reutilizables. | Agrupa módulos por etapa científica. Un subworkflow puede llamar a módulos nf-core y locales. |
| modules/nf-core/ | Módulos externos instalados. | FastQC, fastp, MultiQC, seqkit, seqtk, KMC, GenomeScope2, etc. No editarlos manualmente; actualizar con nf-core tools. |
| modules/local/ | Lógica específica del pipeline. | Procesos para pairing, longitud uniforme, coverage plan, renombrado y validación RE2. Cada módulo debe tener main.nf, meta.yml y tests. |
| bin/ | Scripts auxiliares versionados. | Python/awk/R llamados por módulos locales. Deben ser deterministas, tener argparse y fallar con mensajes claros. |
| conf/ | Perfiles de ejecución. | base.config para recursos generales, modules.config para publishDir y args, test configs, metacentrum.config para PBSPro y Apptainer/Singularity. |
| assets/ | Recursos pequeños y schemas. | Samplesheets ejemplo, schema_input.json, MultiQC custom config, test data pequeño. No meter bases de datos grandes. |
| docs/ | Documentación del usuario y desarrollador. | usage.md, output.md, metacentrum.md, developer_guide.md y troubleshooting.md. Se escribe junto con el código. |
| tests/ | Pruebas automatizadas. | nf-test para módulos y subworkflows, datos toy y casos negativos: pares rotos, Ns, cobertura insuficiente, genoma desconocido. |
| .github/ | Colaboración y CI/CD. | Workflows de lint/test/release, plantillas de issues y PR, protección de ramas y automatización para publicación. |
| .devcontainer/ | Ambiente reproducible de desarrollo. | Usado por GitHub Codespaces y VS Code Dev Containers para tener nf-core, Nextflow, Java, nf-test y herramientas básicas. |

## 4. Qué debe hacer cada subworkflow

| Subworkflow | Responsabilidad |
| --- | --- |
| input_check.nf | Validar samplesheet con schema_input.json y checks propios. Agrupar lanes por sample y emitir tuplas meta + fastqs. |
| read_qc.nf | Ejecutar FastQC y seqkit stats sobre reads crudos. Publicar HTML/ZIP y tablas para MultiQC. |
| trim_filter.nf | Ejecutar fastp PE con auto adapter detection, calidad configurable, n_base_limit 0 y salida paired-only. |
| organelle_filter.nf | Opcional. Mapear contra organelle_fasta/rDNA_fasta y emitir reads nucleares, reads filtrados y stats. |
| genome_size_estimation.nf | Usar genome_size_bp si existe; si no, KMC/GenomeScope2/ntCard según perfil. Marcar confianza. |
| length_normalization.nf | Elegir target length global o fijo. Mantener solo pares donde ambos mates >= L y recortar ambos a L. |
| coverage_sampling.nf | Calcular pares necesarios = coverage × genome_size / (2 × L). Muestrear pares reproduciblemente. |
| repex_formatting.nf | Renombrar, convertir FASTQ a FASTA, intercalar forward/reverse y producir FASTA RE2-ready. |
| reporting.nf | MultiQC, summary TSV, reproducibility ledger, software_versions.yml, checksums y tar.gz por muestra. |

## 5. Módulos locales: contrato mínimo

Cada módulo local debe parecerse a un módulo nf-core: un directorio propio, un main.nf con un proceso atómico, un meta.yml con descripción, inputs, outputs, herramientas y versión, y pruebas nf-test. La regla práctica es que un módulo haga una sola cosa y que sus outputs sean explícitos. Esto convierte bugs de pairing y longitud en animales enjaulados, no en murciélagos dentro de la catedral.

```text
modules/local/crop_fixed_length/
├── main.nf      # process CROP_FIXED_LENGTH
├── meta.yml     # descripción, input/output, tools, authors
├── tests/
│   └── main.nf.test
└── README.md    # opcional, útil si el módulo es complejo
```

## 6. Flujo de datos y metadata

Todos los canales deben transportar un mapa `meta`. No se deben pasar rutas desnudas durante media pipeline.

```groovy
meta = [
  id: row.sample,
  lane: row.lane,
  organism: row.organism,
  genome_size_bp: row.genome_size_bp,
  ploidy: row.ploidy,
  organelle_fasta: row.organelle_fasta,
  target_coverage: row.target_coverage,
  target_read_length: row.target_read_length
]

// Forma recomendada de canal:
tuple(meta, [ fastq_1, fastq_2 ])
```

## 7. Parámetros que deben existir en nextflow_schema.json

| Parámetro | Default | Uso |
| --- | --- | --- |
| --input | required | CSV samplesheet. |
| --outdir | required | Directorio final de resultados. Nunca debe ser work/. |
| --target_read_length | auto | auto o entero 100-200. Para análisis comparativo se recomienda un único valor global. |
| --target_coverage | auto | auto o número entre 0.1 y 0.5. |
| --min_repex_read_length / --max_repex_read_length | 100 / 200 | Límites prácticos RE2. |
| --preferred_read_length | 150 | Primer intento para PE150. |
| --organelle_fasta / --rdna_fasta | null | Referencias opcionales para filtrado. |
| --organelle_filter_mode | none or any_mate | none, any_mate, both_mates, fragment. |
| --estimate_genome_size | true | Ejecuta estimación si falta genome_size_bp. |
| --genome_size_estimator | kmc_genomescope2 | kmc_genomescope2 o ntcard_only. |
| --random_seed | 42 | Seed global para sampling determinista. |
| --strict_repex_validation | true | Falla si FASTA final no cumple longitud, pares, headers o alfabeto. |
| --max_pairs | 0 | Cap opcional para salidas demasiado grandes. |
| --save_intermediates | false | Guardar FASTQ intermedios grandes solo cuando haga falta. |

## 8. Contrato de outputs

```text
results/
├── pipeline_info/
│   ├── execution_report.html
│   ├── execution_timeline.html
│   ├── execution_trace.txt
│   ├── pipeline_dag.html
│   ├── software_versions.yml
│   └── reproducibility_ledger.yml
├── raw_qc/
├── trimmed/
├── organelle_filter/
├── genome_size/
├── planning/
│   ├── coverage_plan.tsv
│   └── target_length_decisions.tsv
├── repeatexplorer_ready/
│   ├── per_sample/
│   │   ├── SAMPLE.repex.fasta
│   │   ├── SAMPLE.repex.fasta.gz
│   │   ├── SAMPLE.read_name_map.tsv.gz
│   │   └── SAMPLE.final_validation.json
│   └── combined/
│       ├── project.combined.repex.fasta.gz
│       └── project.combined_manifest.tsv
├── archives/
│   └── SAMPLE.preprocessing_summary.tar.gz
├── multiqc/
│   ├── multiqc_report.html
│   └── multiqc_data/
└── checksums/
    └── sha256sum.txt
```

## 9. Desarrollo, GitHub, Codespaces, VS Code y MetaCentrum: separación de tareas

| Entorno | Qué se hace ahí | Por qué |
| --- | --- | --- |
| GitHub | Repositorio, issues, PRs, ramas, releases, CI, revisión de código. | GitHub es el registro público y auditable del pipeline; no debe ser solo un sitio para “subir archivos”. |
| GitHub Codespaces | Crear y editar el repo, correr lint, nf-test pequeño, docs, revisar estructura y devcontainer. | Ambiente reproducible de desarrollo; útil cuando no quieres configurar todo localmente. |
| VS Code local | Edición cómoda, Git, revisión de docs, pequeños tests locales si tienes Docker/Conda. | Mejor ergonomía para escribir, buscar y refactorizar; no para WGS real. |
| VS Code Remote-SSH a MetaCentrum | Editar configs específicos del clúster, samplesheets y scripts PBS ya clonados. | Útil para pequeñas correcciones en el repo clonado, pero el cálculo se lanza con qsub. |
| MetaCentrum | Smoke tests HPC, contenedores Apptainer/Singularity, datos reales, qsub, Nextflow head job, performance. | Ahí viven los datos grandes y el scheduler. No se desarrolla a lo bruto en login nodes. |

## 10. Publication-readiness checklist

- [ ] Repositorio creado con nf-core pipelines create, no a mano desde cero.
- [ ] Ramas main, dev y TEMPLATE conservadas según convención nf-core.
- [ ] Pipeline DSL2, con workflow principal, subworkflows y módulos atómicos.
- [ ] nextflow_schema.json completo y assets/schema_input.json para samplesheet.
- [ ] Módulos nf-core instalados sin edición manual.
- [ ] Módulos locales con tests y meta.yml.
- [ ] Perfiles test, docker, apptainer/singularity y metacentrum.
- [ ] CI con lint, nf-test y minimal run.
- [ ] README, usage.md, output.md, metacentrum.md, troubleshooting.md y CITATIONS.md.
- [ ] Release semántico, CHANGELOG.md y tag versionado antes de resultados publicables.
- [ ] Smoke test local/Codespaces y smoke test MetaCentrum antes de producción.

## 11. Fuentes y criterios incorporados

- RepeatExplorer2 / TAREAN / SEQLUST: necesidad de reads no ensamblados, paired-end, FASTA intercalado, longitud uniforme, baja cobertura y ausencia de Ns.
- nf-core: template oficial, DSL2, módulos/subworkflows, schema, lint, CI, ramas y documentación.
- Nextflow / Seqera: perfiles de ejecución, pbspro, apptainer/singularity, cache/resume, report/trace/timeline/dag.
- MetaCentrum: ejecución mediante PBS, no usar frontends para cómputo pesado, uso de scratch y contenedores Singularity/Apptainer.
- fastp, FastQC, MultiQC, SeqKit, seqtk, KMC, GenomeScope2 y ntCard como herramientas candidatas versionadas.
