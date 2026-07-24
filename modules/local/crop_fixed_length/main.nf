process CROP_FIXED_LENGTH {

    tag "${meta.id}"
    label 'process_low'

    input:
    tuple val(meta), path(reads), path(global_target)

    output:
    tuple val(meta), path("${prefix}.cropped_R*.fastq.gz"),
        emit: reads

    tuple val(meta), path("${prefix}.crop_report.tsv"),
        emit: reports

    path "versions.yml",
        emit: versions

    script:
    if (reads.size() != 2) {
        error(
            "CROP_FIXED_LENGTH expects exactly two FASTQ files " +
            "for sample '${meta.id}', but received ${reads.size()}."
        )
    }

    def sorted_reads = reads.sort {
        first, second ->
            first.name <=> second.name
    }

    def r1 = sorted_reads[0]
    def r2 = sorted_reads[1]

    prefix = task.ext.prefix ?: "${meta.id}"

    """
    crop_fixed_length.py \\
        --r1 "${r1}" \\
        --r2 "${r2}" \\
        --sample "${meta.id}" \\
        --target-file "${global_target}" \\
        --output-r1 "${prefix}.cropped_R1.fastq.gz" \\
        --output-r2 "${prefix}.cropped_R2.fastq.gz" \\
        --report "${prefix}.crop_report.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | awk '{print \$2}')
        crop_fixed_length: "0.1.0"
    END_VERSIONS
    """
} 
