process ORGANELLE_FILTER {

    tag "${meta.id}"

    label 'process_medium'

    container "${params.organelle_filter_container}"

    publishDir "${params.outdir}/organelle_filter/fastq",
        mode: 'copy',
        pattern: "*.organelle_filtered.fastq.gz"

    publishDir "${params.outdir}/organelle_filter/reports",
        mode: 'copy',
        pattern: "*.organelle_filter_report.tsv"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta),
          path("*_R*.organelle_filtered.fastq.gz"),
          emit: reads

    tuple val(meta),
          path("*.organelle_filter_report.tsv"),
          emit: report

    script:
    def sample_id = meta.id
    def org_ref = meta.organelle_fasta
        ? meta.organelle_fasta.toString().trim()
        : ""

    def skip = params.skip_organelle_filter ?: false

    """
    set -euo pipefail

    # ------------------------------------------------------------
    # Required commands
    # ------------------------------------------------------------

    for cmd in minimap2 samtools gzip zcat awk sha256sum; do
        if ! command -v "\$cmd" >/dev/null 2>&1; then
            echo "[ORGANELLE_FILTER] ERROR: required command not found: \$cmd" >&2
            echo "[ORGANELLE_FILTER] PATH=\$PATH" >&2
            exit 127
        fi
    done

    # ------------------------------------------------------------
    # Input and output files
    # ------------------------------------------------------------

    R1="${reads[0]}"
    R2="${reads[1]}"

    ORG_REF="${org_ref}"
    SKIP_FILTER="${skip}"

    OUT_R1="${sample_id}_R1.organelle_filtered.fastq.gz"
    OUT_R2="${sample_id}_R2.organelle_filtered.fastq.gz"

    REPORT="${sample_id}.organelle_filter_report.tsv"

    # ------------------------------------------------------------
    # FASTQ record counter
    #
    # In addition to counting records, this verifies that the FASTQ
    # contains complete four-line records.
    # ------------------------------------------------------------

    count_reads() {
        local fastq="\$1"

        zcat -f "\$fastq" |
            awk -v file="\$fastq" '
                END {
                    if (NR % 4 != 0) {
                        print \
                            "[ORGANELLE_FILTER] ERROR: incomplete FASTQ record in " file \
                            > "/dev/stderr"
                        exit 2
                    }

                    print NR / 4
                }
            '
    }

    # ------------------------------------------------------------
    # Validate input pairing
    # ------------------------------------------------------------

    INPUT_R1_READS=\$(count_reads "\$R1")
    INPUT_R2_READS=\$(count_reads "\$R2")

    if [[ "\$INPUT_R1_READS" -ne "\$INPUT_R2_READS" ]]; then
        echo "[ORGANELLE_FILTER] ERROR: input R1/R2 read counts differ" >&2
        echo "[ORGANELLE_FILTER] R1=\$INPUT_R1_READS R2=\$INPUT_R2_READS" >&2
        exit 1
    fi

    INPUT_PAIRS="\$INPUT_R1_READS"

    # ------------------------------------------------------------
    # Report header
    # ------------------------------------------------------------

    printf "sample\\torganelle_fasta\\torganelle_fasta_sha256\\tstatus\\tinput_r1_reads\\tinput_r2_reads\\tretained_r1_reads\\tretained_r2_reads\\tinput_pairs\\tretained_pairs\\tremoved_pairs\\tremoved_reads\\tretained_fraction\\tremoved_fraction\\tsync_status\\n" \
        > "\$REPORT"

    # ------------------------------------------------------------
    # Optional complete skip
    # ------------------------------------------------------------

    if [[ "\$SKIP_FILTER" == "true" || "\$SKIP_FILTER" == "TRUE" ]]; then

        cp "\$R1" "\$OUT_R1"
        cp "\$R2" "\$OUT_R2"

        printf "${sample_id}\\tNA\\tNA\\tSKIPPED_BY_PARAM\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t0\\t0\\t1.000000\\t0.000000\\tPASS\\n" \
            "\$INPUT_R1_READS" \
            "\$INPUT_R2_READS" \
            "\$INPUT_R1_READS" \
            "\$INPUT_R2_READS" \
            "\$INPUT_PAIRS" \
            "\$INPUT_PAIRS" \
            >> "\$REPORT"

        exit 0
    fi

    # ------------------------------------------------------------
    # Skip samples without an organelle reference
    # ------------------------------------------------------------

    if [[ -z "\$ORG_REF" ||
          "\$ORG_REF" == "NA" ||
          "\$ORG_REF" == "null" ||
          "\$ORG_REF" == "." ]]; then

        cp "\$R1" "\$OUT_R1"
        cp "\$R2" "\$OUT_R2"

        printf "${sample_id}\\tNA\\tNA\\tSKIPPED_NO_REFERENCE\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t0\\t0\\t1.000000\\t0.000000\\tPASS\\n" \
            "\$INPUT_R1_READS" \
            "\$INPUT_R2_READS" \
            "\$INPUT_R1_READS" \
            "\$INPUT_R2_READS" \
            "\$INPUT_PAIRS" \
            "\$INPUT_PAIRS" \
            >> "\$REPORT"

        exit 0
    fi

    # ------------------------------------------------------------
    # Resolve and validate the organelle reference
    # ------------------------------------------------------------

    if [[ "\$ORG_REF" != /* ]]; then
        ORG_REF="${projectDir}/\$ORG_REF"
    fi

    if [[ ! -s "\$ORG_REF" ]]; then
        echo \
            "[ORGANELLE_FILTER] ERROR: organelle reference does not exist or is empty: \$ORG_REF" \
            >&2
        exit 1
    fi

    ORG_REF_SHA256=\$(
        sha256sum "\$ORG_REF" |
            awk '{ print \$1 }'
    )

    # ------------------------------------------------------------
    # Organelle filtering
    #
    # -f 12:
    #     retain alignments where both the read and its mate are
    #     unmapped
    #
    # -F 2304:
    #     exclude secondary and supplementary alignments
    # ------------------------------------------------------------

    minimap2 \
        -t ${task.cpus} \
        -ax sr \
        "\$ORG_REF" \
        "\$R1" \
        "\$R2" \
        |
        samtools fastq \
            -@ ${task.cpus} \
            -f 12 \
            -F 2304 \
            -1 >(gzip -c > "\$OUT_R1") \
            -2 >(gzip -c > "\$OUT_R2") \
            -0 /dev/null \
            -s /dev/null \
            -n -

    # ------------------------------------------------------------
    # Validate retained pairing
    # ------------------------------------------------------------

    RETAINED_R1_READS=\$(count_reads "\$OUT_R1")
    RETAINED_R2_READS=\$(count_reads "\$OUT_R2")

    if [[ "\$RETAINED_R1_READS" -ne "\$RETAINED_R2_READS" ]]; then
        echo "[ORGANELLE_FILTER] ERROR: retained R1/R2 read counts differ" >&2
        echo \
            "[ORGANELLE_FILTER] R1=\$RETAINED_R1_READS R2=\$RETAINED_R2_READS" \
            >&2
        exit 1
    fi

    RETAINED_PAIRS="\$RETAINED_R1_READS"
    REMOVED_PAIRS=\$(( INPUT_PAIRS - RETAINED_PAIRS ))

    if [[ "\$REMOVED_PAIRS" -lt 0 ]]; then
        echo "[ORGANELLE_FILTER] ERROR: negative number of removed pairs" >&2
        echo \
            "[ORGANELLE_FILTER] input=\$INPUT_PAIRS retained=\$RETAINED_PAIRS" \
            >&2
        exit 1
    fi

    REMOVED_READS=\$(( REMOVED_PAIRS * 2 ))

    # ------------------------------------------------------------
    # Calculate retained and removed fractions
    # ------------------------------------------------------------

    if [[ "\$INPUT_PAIRS" -gt 0 ]]; then

        RETAINED_FRACTION=\$(
            awk \
                -v retained="\$RETAINED_PAIRS" \
                -v total="\$INPUT_PAIRS" \
                'BEGIN {
                    printf "%.6f", retained / total
                }'
        )

        REMOVED_FRACTION=\$(
            awk \
                -v removed="\$REMOVED_PAIRS" \
                -v total="\$INPUT_PAIRS" \
                'BEGIN {
                    printf "%.6f", removed / total
                }'
        )

    else
        RETAINED_FRACTION="NA"
        REMOVED_FRACTION="NA"
    fi

    # ------------------------------------------------------------
    # Final auditable report
    # ------------------------------------------------------------

    printf "${sample_id}\\t%s\\t%s\\tPASS\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\tPASS\\n" \
        "\$ORG_REF" \
        "\$ORG_REF_SHA256" \
        "\$INPUT_R1_READS" \
        "\$INPUT_R2_READS" \
        "\$RETAINED_R1_READS" \
        "\$RETAINED_R2_READS" \
        "\$INPUT_PAIRS" \
        "\$RETAINED_PAIRS" \
        "\$REMOVED_PAIRS" \
        "\$REMOVED_READS" \
        "\$RETAINED_FRACTION" \
        "\$REMOVED_FRACTION" \
        >> "\$REPORT"
    """
}