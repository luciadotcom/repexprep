process INPUT_PROVENANCE {

    tag "${meta.id}"

    label 'process_low'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta),
          path("${meta.id}.input_provenance.tsv"),
          emit: report

    script:
    if (reads.size() != 2) {
        error(
            "INPUT_PROVENANCE requires two FASTQ files for " +
            "sample ${meta.id}."
        )
    }

    def accession = meta.accession ?: ''
    def requestedProvider = meta.provider ?: ''
    def resolvedProvider =
        meta.resolved_provider ?: requestedProvider ?: meta.source

    def originalR1 = meta.original_fastq_1 ?: ''
    def originalR2 = meta.original_fastq_2 ?: ''

    """
    set -euo pipefail

    {
        printf '%s\\n' \
            'sample\tsource\trequested_provider\tresolved_provider\taccession\tread\tmaterialised_file\tbytes\toriginal_path'

        printf '%s\\t%s\\t%s\\t%s\\t%s\\tR1\\t%s\\t%s\\t%s\\n' \
            '${meta.id}' \
            '${meta.source}' \
            '${requestedProvider}' \
            '${resolvedProvider}' \
            '${accession}' \
            '${reads[0]}' \
            "\$(stat -c '%s' '${reads[0]}')" \
            '${originalR1}'

        printf '%s\\t%s\\t%s\\t%s\\t%s\\tR2\\t%s\\t%s\\t%s\\n' \
            '${meta.id}' \
            '${meta.source}' \
            '${requestedProvider}' \
            '${resolvedProvider}' \
            '${accession}' \
            '${reads[1]}' \
            "\$(stat -c '%s' '${reads[1]}')" \
            '${originalR2}'
    } > "${meta.id}.input_provenance.tsv"
    """
}
