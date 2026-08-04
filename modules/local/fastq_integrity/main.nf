process FASTQ_INTEGRITY {

    tag "${meta.id}"

    label 'process_low'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta),
          path(reads),
          emit: reads

    tuple val(meta),
          path("${meta.id}.fastq_integrity.tsv"),
          emit: report

    path "versions.yml",
         emit: versions

    script:
    if (reads.size() != 2) {
        error(
            "FASTQ_INTEGRITY requires exactly two FASTQ files " +
            "for sample ${meta.id}; received ${reads.size()}."
        )
    }

    def readList = reads.collect { "'${it}'" }.join(" ")

    """
    set -euo pipefail

    READS=( ${readList} )

    {
        printf '%s\\n' \
            'sample\tread\tfile\tbytes\tcompression\tstatus'

        for INDEX in 0 1; do
            FILE="\${READS[\$INDEX]}"
            READ_NUMBER=\$((INDEX + 1))

            if [[ ! -s "\$FILE" ]]; then
                echo "FASTQ file is missing or empty: \$FILE" >&2
                exit 1
            fi

            FILE_BYTES=\$(stat -c '%s' "\$FILE")

            if [[ "\$FILE" == *.gz ]]; then
                gzip -t "\$FILE"
                COMPRESSION="gzip"
            else
                COMPRESSION="none"
            fi

            printf '%s\\tR%s\\t%s\\t%s\\t%s\\tPASS\\n' \
                '${meta.id}' \
                "\$READ_NUMBER" \
                "\$FILE" \
                "\$FILE_BYTES" \
                "\$COMPRESSION"
        done
    } > "${meta.id}.fastq_integrity.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gzip: \$(gzip --version | head -n 1 | awk '{print \$2}')
    END_VERSIONS
    """
}
