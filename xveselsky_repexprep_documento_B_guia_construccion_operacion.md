# Documento B — Guía desde cero: desarrollo → GitHub → MetaCentrum → qsub/Nextflow

Construcción y operación paso a paso de xveselsky-repexprep siguiendo el flujo de ejecución acordado.

## 0. El guion obligatorio

Esta guía sigue estrictamente este esquema: 1) desarrollar la pipeline localmente o en GitHub Codespaces; 2) guardarla en GitHub; 3) entrar a MetaCentrum; 4) clonar el repositorio; 5) ejecutarla allí con qsub / Nextflow.

0. Desarrollar localmente o en GitHub Codespaces
1. Guardar en GitHub
1. Entrar a MetaCentrum
1. Clonar el repositorio en MetaCentrum
1. Ejecutar con qsub / Nextflow

## 1. Preparación conceptual antes de tocar comandos

No vas a escribir un único script. Vas a construir un repositorio de pipeline.

| Fase | Lugar | Contenido |
| --- | --- | --- |
| Desarrollo | Tu ordenador o Codespaces | Código, estructura, módulos, docs, tests pequeños. |
| Versionado | GitHub | Historial, ramas, issues, pull requests, releases y CI. |
| Producción | MetaCentrum | FASTQ reales, PBS/qsub, Apptainer/Singularity, Nextflow, scratch y resultados. |

## 2. Opción A: desarrollar localmente con VS Code

Usa esta opción si tu ordenador tiene Git, Java, Conda/Mamba y, si quieres probar contenedores, Docker o Podman.

```bash
# En tu ordenador local
mkdir -p ~/workspace
cd ~/workspace

# Crear entorno de desarrollo
mamba create -n nfdev -c conda-forge -c bioconda nf-core nextflow git openjdk -y
mamba activate nfdev

nf-core --version
nextflow -version
git --version
```

> Nota: No corras WGS real localmente. El objetivo local es escribir, lintar y probar con datos de juguete.

## 3. Opción B: desarrollar en GitHub Codespaces

Usa esta opción si quieres un entorno limpio y reproducible en el navegador o desde VS Code.

1. Crear un repositorio vacío en GitHub, por ejemplo xveselsky-repexprep.
1. Abrir Code → Codespaces → Create codespace on main.
1. Instalar nf-core/nextflow en el devcontainer o usar .devcontainer ya incluido.
1. Crear la pipeline con nf-core pipelines create o copiar el template ya generado.
1. Correr nf-core lint y tests de juguete, nunca FASTQ grandes.

## 4. Crear el esqueleto con nf-core pipelines create

Este paso debe hacerse antes de meter lógica propia.

```bash
# Desde tu local o Codespaces, dentro de un directorio de trabajo limpio
nf-core pipelines create

# Valores sugeridos en el asistente:
# Pipeline name: repexprep
# Description: WGS preprocessing for RepeatExplorer2 comparative repeatome analysis
# Author: Jan Veselsky
# Organisation / prefix: xveselsky
# License: MIT or GPL-3.0, según estrategia de publicación
# Enable GitHub Actions / CI: yes
# Enable nf-test: yes
# Enable Docker/Singularity/Conda profiles: yes
```

```bash
cd xveselsky-repexprep
git status
```

## 5. Instalar módulos nf-core y crear módulos locales

Instala módulos existentes con nf-core tools. La lógica RepeatExplorer-specific va como módulos locales.

```bash
# Módulos comunitarios cuando existan
nf-core modules install fastqc
nf-core modules install fastp
nf-core modules install multiqc
nf-core modules install seqkit/stats
nf-core modules install seqtk/mergepe
# opcionales según implementación:
# nf-core modules install kmc
# nf-core modules install samtools/fastq
# nf-core modules install bowtie2/align

# Módulos locales específicos
mkdir -p modules/local/{validate_samplesheet,merge_lanes,pair_audit,organelle_filter,choose_target_length,crop_fixed_length,plan_coverage,sample_pairs,rename_convert_fasta,interleave_fasta,validate_repex_fasta,archive_sample}
mkdir -p subworkflows/local bin assets docs tests/data
```

## 6. Estructura mínima que debes ir rellenando

| Archivo/carpeta | Qué escribir ahí |
| --- | --- |
| workflows/repexprep.nf | Conecta subworkflows en orden biológico. |
| subworkflows/local/read_qc.nf | FastQC + seqkit stats crudos. |
| subworkflows/local/trim_filter.nf | fastp + post-QC. |
| subworkflows/local/length_normalization.nf | Histograma, target length y crop. |
| subworkflows/local/coverage_sampling.nf | Coverage plan y sampling de pares. |
| subworkflows/local/repex_formatting.nf | Renombrado, FASTA, interleaving, validación. |
| bin/*.py | Scripts deterministas llamados por módulos locales. |
| conf/metacentrum.config | PBSPro + Apptainer/Singularity + recursos MetaCentrum. |
| assets/schema_input.json | Validación de samplesheet. |
| docs/usage.md y docs/output.md | Manual de uso y outputs. |
| tests/ | Datos toy y nf-test. |

## 7. Probar localmente o en Codespaces con datos de juguete

```bash
# Crear datos toy con el script de la pipeline
python bin/make_toy_pe_fastq.py --sample toyA --pairs 5000 --length 151 --outdir tests/data

cat > assets/samplesheet.test.csv <<'EOF'
sample,fastq_1,fastq_2,lane,organism,genome_size_bp,ploidy
TOYA,tests/data/toyA_R1.fastq.gz,tests/data/toyA_R2.fastq.gz,L001,Toy organism,135000000,2
EOF

# Ejecutar test rápido
nextflow run . \
  -profile test,conda \
  --input assets/samplesheet.test.csv \
  --outdir results_test \
  --target_read_length 150 \
  --target_coverage 0.1 \
  -resume

# Lint nf-core
nf-core pipelines lint .
```

## 8. Guardar en GitHub

Trabaja en `dev`. `main` queda para releases. `TEMPLATE` se conserva para sincronizar template nf-core.

```bash
# Dentro del repositorio local/Codespaces
git status
git checkout -b dev

git add .
git commit -m "Initial nf-core-style repexprep skeleton"

# Si el remoto aún no existe:
git remote add origin git@github.com:xveselsky/xveselsky-repexprep.git

# Subir
git push -u origin dev
```

> Nota: Antes de resultados publicables crea un tag: `git tag v0.1.0 && git push origin v0.1.0`.

## 9. Entrar a MetaCentrum

```bash
ssh xveselsky@skirit.metacentrum.cz

# Elegir almacenamiento persistente, no trabajar con WGS en $HOME si hay poco cupo
mkdir -p /storage/brno12-cerit/home/$USER/projects
cd /storage/brno12-cerit/home/$USER/projects

# Cargar módulos disponibles
module avail nextflow
module avail mambaforge
module avail apptainer
module avail singularity
```

> Nota: El login node es para preparar y lanzar, no para procesar FASTQ grandes.

## 10. Clonar el repositorio en MetaCentrum

```bash
cd /storage/brno12-cerit/home/$USER/projects

git clone git@github.com:xveselsky/xveselsky-repexprep.git
cd xveselsky-repexprep

git checkout dev
# o, para una versión congelada:
# git checkout v0.1.0

ls
```

## 11. Preparar datos reales y samplesheet en MetaCentrum

Los FASTQ deben vivir en `/storage` o en otra ruta accesible desde nodos de cómputo. Usa rutas absolutas.

```bash
mkdir -p /storage/brno12-cerit/home/$USER/repexprep_runs/run_001
cd /storage/brno12-cerit/home/$USER/repexprep_runs/run_001

cat > samplesheet.csv <<'EOF'
sample,fastq_1,fastq_2,lane,organism,genome_size_bp,ploidy,organelle_fasta,target_coverage,target_read_length
SAMPLE_A,/storage/path/A_R1.fastq.gz,/storage/path/A_R2.fastq.gz,L001,Species A,135000000,2,/storage/path/organelle_A.fa,0.5,150
SAMPLE_B,/storage/path/B_R1.fastq.gz,/storage/path/B_R2.fastq.gz,L001,Species B,13000000000,2,/storage/path/organelle_B.fa,0.1,150
EOF
```

## 12. Crear el job PBS que lanza Nextflow

Este script es el “head job”: mantiene vivo Nextflow y Nextflow somete las tareas individuales a PBS.

```bash
#!/bin/bash
#PBS -N repexprep_head
#PBS -l select=1:ncpus=2:mem=8gb:scratch_local=20gb
#PBS -l walltime=72:00:00
#PBS -j oe

set -euo pipefail

module add mambaforge
module add nextflow
# module add apptainer   # si existe como módulo separado
# module add singularity  # alternativa según MetaCentrum

# Si usas Conda solo para Nextflow/nf-core:
# mamba activate nfdev

export NXF_HOME=/storage/brno12-cerit/home/$USER/.nextflow
export NXF_WORK=/storage/brno12-cerit/home/$USER/nxf_work/repexprep_run_001
export NXF_SINGULARITY_CACHEDIR=/storage/brno12-cerit/home/$USER/singularity_cache
export APPTAINER_CACHEDIR=/storage/brno12-cerit/home/$USER/apptainer_cache

mkdir -p "$NXF_HOME" "$NXF_WORK" "$NXF_SINGULARITY_CACHEDIR" "$APPTAINER_CACHEDIR"

cd /storage/brno12-cerit/home/$USER/projects/xveselsky-repexprep

nextflow run . \
  -profile metacentrum,singularity \
  --input /storage/brno12-cerit/home/$USER/repexprep_runs/run_001/samplesheet.csv \
  --outdir /storage/brno12-cerit/home/$USER/repexprep_runs/run_001/results \
  --target_read_length auto \
  --target_coverage auto \
  -work-dir "$NXF_WORK" \
  -resume \
  -with-report \
  -with-trace \
  -with-timeline \
  -with-dag
```

## 13. Ejecutar con qsub / Nextflow

```bash
cd /storage/brno12-cerit/home/$USER/repexprep_runs/run_001
qsub launch_repexprep.pbs

# Monitorizar
qstat -u $USER

# Ver logs del head job cuando aparezcan
ls -lh repexprep_head.*
tail -f repexprep_head.o*
```

## 14. Smoke test interactivo en MetaCentrum

El modo interactivo sirve solo para comprobar módulos, rutas, contenedores y ejecución de juguete. No lo uses para WGS real.

```bash
qsub -I -l select=1:ncpus=4:mem=16gb:scratch_local=20gb -l walltime=02:00:00

module add mambaforge
module add nextflow
cd /storage/brno12-cerit/home/$USER/projects/xveselsky-repexprep

nextflow run . \
  -profile test,conda \
  --input assets/samplesheet.test.csv \
  --outdir results_test_metacentrum \
  --target_read_length 150 \
  --target_coverage 0.1 \
  -resume
```

## 15. Recursos iniciales recomendados

| Label | Tareas | Recursos iniciales |
| --- | --- | --- |
| process_low | Validación, parsing, checksums, archivado pequeño. | 1 CPU, 1-4 GB, 1-2 h |
| process_medium | FastQC, fastp, SeqKit, conversión FASTA. | 2-8 CPUs, 4-16 GB, 4-12 h |
| process_high | Filtrado organelar, sampling de muestras grandes. | 8-16 CPUs, 16-64 GB, 12-48 h |
| process_long | KMC / GenomeScope2 en WGS grandes. | 8-32 CPUs, 64-256 GB, 24-72 h |
| head job Nextflow | Solo orquestación. | 1-2 CPUs, 4-8 GB, 48-72 h |

## 16. Comprobar resultados

```bash
RESULTS=/storage/brno12-cerit/home/$USER/repexprep_runs/run_001/results

find "$RESULTS" -maxdepth 3 -type f | sort | head -100

# Archivos clave
ls -lh "$RESULTS"/repeatexplorer_ready/per_sample/
ls -lh "$RESULTS"/planning/coverage_plan.tsv
ls -lh "$RESULTS"/multiqc/multiqc_report.html
ls -lh "$RESULTS"/pipeline_info/execution_report.html

# Validación final por muestra
find "$RESULTS" -name "*.final_validation.json" -print
```

Un resultado aceptable debe tener FASTA final, JSON de validación con `ok=true`, coverage_plan.tsv, MultiQC y pipeline_info.

## 17. Errores frecuentes

| Síntoma | Causa probable | Arreglo |
| --- | --- | --- |
| El job muere enseguida | Módulo Nextflow/Conda no cargado o ruta del repo incorrecta. | Revisar repexprep_head.o*, module avail, pwd y git status. |
| Nextflow no puede enviar jobs | Perfil pbspro mal configurado o queue no válida. | Ajustar conf/metacentrum.config, bajar queueSize y revisar colas. |
| No descarga contenedores | Cache de Singularity/Apptainer no accesible o red. | Usar cache en /storage, pre-pull o perfil conda para test. |
| FASTA final falla validación | Pares rotos, headers mal, Ns o longitudes distintas. | Abrir final_validation.json, revisar stage de crop/pair audit. |
| Coverage insuficiente | Pocos pares sobreviven a trimming/filtro/longitud. | Bajar target length o target coverage, o resecuenciar. |
| GenomeScope falla | Cobertura demasiado baja o genoma complejo. | Usar genome_size_bp manual y tratar estimación como metadata. |
| -resume no salta tareas | Cambió work-dir, params, repo o se borró .nextflow/cache. | Mantener work-dir y lanzar el mismo comando con -resume. |

## 18. Checklist final de ejecución desde cero

- [ ] Crear repo con nf-core pipelines create localmente o en Codespaces.
- [ ] Añadir módulos nf-core y módulos locales.
- [ ] Añadir bin scripts, schemas, configs, docs y tests.
- [ ] Correr nextflow run . -profile test,conda con datos toy.
- [ ] Correr nf-core pipelines lint . y corregir errores.
- [ ] Commit y push a GitHub en rama dev.
- [ ] Entrar a MetaCentrum por SSH.
- [ ] Clonar repo desde GitHub en /storage.
- [ ] Preparar samplesheet con rutas absolutas a FASTQ y referencias.
- [ ] Crear launch_repexprep.pbs.
- [ ] qsub launch_repexprep.pbs.
- [ ] Monitorizar qstat y logs.
- [ ] Verificar FASTA RE2-ready, MultiQC, coverage_plan y validation JSON.
- [ ] Para resultados publicables, usar tag fijo vX.Y.Z y guardar report/trace/timeline/dag.
