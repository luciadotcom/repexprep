process FASTQC {
    tag "$meta.id"
    label 'process_medium'

    publishDir "${params.outdir}/raw_qc/fastqc", mode: 'copy'

    conda "bioconda::fastqc=0.12.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/fastqc:0.12.1--hdfd78af_0' :
        'biocontainers/fastqc:0.12.1--hdfd78af_0' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.html"), emit: html
    tuple val(meta), path("*.zip") , emit: zip
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    // Preserve prefix if defined in task.ext.prefix, otherwise default to meta.id
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    // Check if reads are passed as a list or a single path
    def old_new_pairs = reads instanceof Path ? [reads] : reads
    """
    fastqc \\
        $args \\
        --threads $task.cpus \\
        ${reads}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastqc: \$(fastqc --version | sed -e "s/FastQC v//g")
    END_VERSIONS
    """
}