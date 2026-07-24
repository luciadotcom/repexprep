process PROFILE_READ_LENGTH {

    tag "${meta.id}"
    label 'process_low'

    input:
    tuple val(meta), path(reads)
    val min_retained_fraction

    output:
    tuple val(meta), path("*.read_length_profile.tsv"),
        emit: profiles

    path "versions.yml",
        emit: versions

    script:
    if (reads.size() != 2) {
        error(
            "PROFILE_READ_LENGTH expects exactly two FASTQ files " +
            "for sample '${meta.id}', but received ${reads.size()}."
        )
    }

    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    profile_read_length.py \\
        --r1 "${reads[0]}" \\
        --r2 "${reads[1]}" \\
        --sample "${meta.id}" \\
        --min-retained-fraction "${min_retained_fraction}" \\
        --output "${prefix}.read_length_profile.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | awk '{print \$2}')
    END_VERSIONS
    """
}