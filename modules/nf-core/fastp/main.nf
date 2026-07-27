process FASTP {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::fastp=0.23.4"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/fastp:0.23.4--h002b4bf_1' :
        'biocontainers/fastp:0.23.4--h002b4bf_1' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.fastp.fastq.gz"), emit: reads
    tuple val(meta), path("*.json")          , emit: json
    tuple val(meta), path("*.html")          , emit: html
    tuple val(meta), path("*.fail.fastq.gz") , optional: true, emit: reads_fail
    path "versions.yml"                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    if (meta.single_end) {
        """
        fastp \\
            --in1 ${reads[0]} \\
            --out1 ${prefix}.fastp.fastq.gz \\
            --thread $task.cpus \\
            --json ${prefix}.fastp.json \\
            --html ${prefix}.fastp.html \\
            $args

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            fastp: \$(fastp --version 2>&1 | sed -e "s/fastp //g")
        END_VERSIONS
        """
    } else {
        """
        fastp \\
            --in1 ${reads[0]} \\
            --in2 ${reads[1]} \\
            --out1 ${prefix}_1.fastp.fastq.gz \\
            --out2 ${prefix}_2.fastp.fastq.gz \\
            --thread $task.cpus \\
            --json ${prefix}.fastp.json \\
            --html ${prefix}.fastp.html \\
            $args

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            fastp: \$(fastp --version 2>&1 | sed -e "s/fastp //g")
        END_VERSIONS
        """
    }
}