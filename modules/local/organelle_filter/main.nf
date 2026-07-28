process ORGANELLE_FILTER {

    tag "${meta.id}"

    label 'process_medium'

    container "${params.organelle_filter_container}"

    publishDir "${params.outdir}/organelle_filter/fastq", mode: 'copy', pattern: "*.organelle_filtered.fastq.gz"
    publishDir "${params.outdir}/organelle_filter/reports", mode: 'copy', pattern: "*.organelle_filter_report.tsv"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*_R*.organelle_filtered.fastq.gz"), emit: reads
    tuple val(meta), path("*.organelle_filter_report.tsv"), emit: report

    script:
    def sample_id = meta.id
    def org_ref   = meta.organelle_fasta ? meta.organelle_fasta.toString().trim() : ""
    def skip      = params.skip_organelle_filter ?: false

    """
    set -euo pipefail

    R1="${reads[0]}"
    R2="${reads[1]}"

    ORG_REF="${org_ref}"
    SKIP_FILTER="${skip}"

    OUT_R1="${sample_id}_R1.organelle_filtered.fastq.gz"
    OUT_R2="${sample_id}_R2.organelle_filtered.fastq.gz"
    REPORT="${sample_id}.organelle_filter_report.tsv"

    count_pairs() {
        zcat -f "\$1" | awk 'END { print NR / 4 }'
    }

    INPUT_PAIRS=\$(count_pairs "\$R1")

    printf "sample\\torganelle_fasta\\tstatus\\tinput_pairs\\tkept_pairs\\tremoved_pairs\\tremoved_fraction\\n" > "\$REPORT"

    if [[ "\$SKIP_FILTER" == "true" || "\$SKIP_FILTER" == "TRUE" ]]; then
        cp "\$R1" "\$OUT_R1"
        cp "\$R2" "\$OUT_R2"

        KEPT_PAIRS="\$INPUT_PAIRS"
        REMOVED_PAIRS=0
        REMOVED_FRACTION=0

        printf "${sample_id}\\tNA\\tSKIPPED_BY_PARAM\\t%s\\t%s\\t%s\\t%s\\n" \
            "\$INPUT_PAIRS" "\$KEPT_PAIRS" "\$REMOVED_PAIRS" "\$REMOVED_FRACTION" >> "\$REPORT"

        exit 0
    fi

    if [[ -z "\$ORG_REF" || "\$ORG_REF" == "NA" || "\$ORG_REF" == "null" || "\$ORG_REF" == "." ]]; then
        cp "\$R1" "\$OUT_R1"
        cp "\$R2" "\$OUT_R2"

        KEPT_PAIRS="\$INPUT_PAIRS"
        REMOVED_PAIRS=0
        REMOVED_FRACTION=0

        printf "${sample_id}\\tNA\\tSKIPPED_NO_REFERENCE\\t%s\\t%s\\t%s\\t%s\\n" \
            "\$INPUT_PAIRS" "\$KEPT_PAIRS" "\$REMOVED_PAIRS" "\$REMOVED_FRACTION" >> "\$REPORT"

        exit 0
    fi

    if [[ "\$ORG_REF" != /* ]]; then
        ORG_REF="${projectDir}/\$ORG_REF"
    fi

    if [[ ! -s "\$ORG_REF" ]]; then
        echo "[ORGANELLE_FILTER] ERROR: organelle reference does not exist or is empty: \$ORG_REF" >&2
        exit 1
    fi

    minimap2 -t ${task.cpus} -ax sr "\$ORG_REF" "\$R1" "\$R2" \\
        | samtools fastq \\
            -@ ${task.cpus} \\
            -f 12 \\
            -F 2304 \\
            -1 >(gzip -c > "\$OUT_R1") \\
            -2 >(gzip -c > "\$OUT_R2") \\
            -0 /dev/null \\
            -s /dev/null \\
            -n -

    KEPT_PAIRS=\$(count_pairs "\$OUT_R1")
    REMOVED_PAIRS=\$(( INPUT_PAIRS - KEPT_PAIRS ))

    if [[ "\$INPUT_PAIRS" -gt 0 ]]; then
        REMOVED_FRACTION=\$(awk -v r="\$REMOVED_PAIRS" -v t="\$INPUT_PAIRS" 'BEGIN { printf "%.6f", r / t }')
    else
        REMOVED_FRACTION="NA"
    fi

    printf "${sample_id}\\t%s\\tPASS\\t%s\\t%s\\t%s\\t%s\\n" \\
        "\$ORG_REF" "\$INPUT_PAIRS" "\$KEPT_PAIRS" "\$REMOVED_PAIRS" "\$REMOVED_FRACTION" >> "\$REPORT"
    """
}