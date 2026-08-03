process ENA_FASTQ_DOWNLOAD {

    tag "${meta.id}"

    label 'process_high'

    input:
    tuple val(meta),
          val(urls),
          val(md5s)

    output:
    tuple val(meta),
          path("${meta.id}_R{1,2}.fastq.gz"),
          emit: reads

    tuple val(meta),
          path("${meta.id}.acquisition_manifest.tsv"),
          emit: manifest

    path "versions.yml",
         emit: versions

    script:
    if (urls.size() != 2) {
        error(
            "ENA_FASTQ_DOWNLOAD requires exactly two FASTQ URLs " +
            "for sample ${meta.id}; received ${urls.size()}."
        )
    }

    def urlText = urls.join("\n")

    def md5Values = md5s ?: ["", ""]
    def md5Text   = md5Values.join("\n")

    """
    set -euo pipefail

    printf '%s\\n' '${urlText}' > ena_urls.txt
    printf '%s\\n' '${md5Text}' > ena_md5.txt

    mapfile -t URLS < ena_urls.txt
    mapfile -t MD5S < ena_md5.txt

    if [[ "\${#URLS[@]}" -ne 2 ]]; then
        echo "Expected exactly two ENA FASTQ URLs." >&2
        exit 1
    fi

    for INDEX in 0 1; do
        READ_NUMBER=\$((INDEX + 1))
        OUTPUT="${meta.id}_R\${READ_NUMBER}.fastq.gz"

        curl \
            --location \
            --fail \
            --show-error \
            --silent \
            --retry 5 \
            --retry-delay 10 \
            --continue-at - \
            "\${URLS[\$INDEX]}" \
            --output "\$OUTPUT"

        gzip -t "\$OUTPUT"

        EXPECTED_MD5="\${MD5S[\$INDEX]:-}"

        if [[ -n "\$EXPECTED_MD5" ]]; then
            echo "\$EXPECTED_MD5  \$OUTPUT" \
                | md5sum --check --status
        fi
    done

    {
        printf '%s\\n' \
            'sample\taccession\tprovider\tread\turl\texpected_md5\tactual_md5\tbytes\tlocal_file'

        for INDEX in 0 1; do
            READ_NUMBER=\$((INDEX + 1))
            OUTPUT="${meta.id}_R\${READ_NUMBER}.fastq.gz"
            EXPECTED_MD5="\${MD5S[\$INDEX]:-}"
            ACTUAL_MD5=\$(md5sum "\$OUTPUT" | cut -d' ' -f1)
            FILE_BYTES=\$(stat -c '%s' "\$OUTPUT")

            printf '%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n' \
                '${meta.id}' \
                '${meta.accession}' \
                'ena' \
                "R\${READ_NUMBER}" \
                "\${URLS[\$INDEX]}" \
                "\$EXPECTED_MD5" \
                "\$ACTUAL_MD5" \
                "\$FILE_BYTES" \
                "\$OUTPUT"
        done
    } > "${meta.id}.acquisition_manifest.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        curl: \$(curl --version | head -n 1 | awk '{print \$2}')
        gzip: \$(gzip --version | head -n 1 | awk '{print \$2}')
    END_VERSIONS
    """
}
