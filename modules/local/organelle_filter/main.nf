process ORGANELLE_FILTER {

    tag "${meta.id}"

    label 'process_medium'

    container "${params.organelle_filter_container}"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta),
          path("*_R*.organelle_filtered.fastq.gz"),
          emit: reads

    tuple val(meta),
          path("*.organelle_filter_report.tsv"),
          emit: report

    tuple val(meta),
          path("*.organelle_method_record.tsv"),
          emit: method_record

    tuple val(meta),
          path("*.organelle_reference_record.tsv"),
          emit: reference_record,
          optional: true

    script:
    def sample_id = meta.id

    def org_ref_raw = meta.organelle_fasta
        ? meta.organelle_fasta.toString().trim()
        : ""

    /*
     * Convert a repository-relative reference path to an absolute path
     * before constructing the Bash script.
     *
     * Absolute paths and explicit missing-value markers are retained.
     */
    def org_ref = (
        org_ref_raw &&
        !["NA", "null", "."].contains(org_ref_raw) &&
        !org_ref_raw.startsWith("/")
    )
        ? "${projectDir}/${org_ref_raw}"
        : org_ref_raw

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
    METHOD_RECORD="${sample_id}.organelle_method_record.tsv"
    REFERENCE_RECORD="${sample_id}.organelle_reference_record.tsv"

    # ------------------------------------------------------------
    # FASTQ record counter
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
    # Per-sample report header
    # ------------------------------------------------------------

    printf "sample\\treference_id\\tstatus\\tinput_r1_reads\\tinput_r2_reads\\tretained_r1_reads\\tretained_r2_reads\\tinput_pairs\\tretained_pairs\\tremoved_pairs\\tremoved_reads\\tretained_fraction\\tremoved_fraction\\tsync_status\\n" \
        > "\$REPORT"

    # ------------------------------------------------------------
    # Method metadata record
    # ------------------------------------------------------------

    MINIMAP2_VERSION=\$(
        minimap2 --version |
            head -n 1
    )

    SAMTOOLS_VERSION=\$(
        samtools --version |
            awk 'NR == 1 { print \$2 }'
    )

    printf "minimap2_samtools_fastq\\tremove_pair_if_either_mate_maps\\t-ax sr\\t12\\t2304\\t%s\\t%s\\n" \
        "\$MINIMAP2_VERSION" \
        "\$SAMTOOLS_VERSION" \
        > "\$METHOD_RECORD"

    # ------------------------------------------------------------
    # Optional complete skip
    # ------------------------------------------------------------

    if [[ "\$SKIP_FILTER" == "true" || "\$SKIP_FILTER" == "TRUE" ]]; then

        cp "\$R1" "\$OUT_R1"
        cp "\$R2" "\$OUT_R2"

        printf "${sample_id}\\tNA\\tSKIPPED_BY_PARAM\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t0\\t0\\t1.000000\\t0.000000\\tPASS\\n" \
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

        printf "${sample_id}\\tNA\\tSKIPPED_NO_REFERENCE\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t0\\t0\\t1.000000\\t0.000000\\tPASS\\n" \
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
    # Validate the resolved organelle reference
    # ------------------------------------------------------------

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

    REFERENCE_ID="orgref_\${ORG_REF_SHA256:0:12}"

    printf "%s\\t%s\\t%s\\n" \
        "\$REFERENCE_ID" \
        "\$ORG_REF" \
        "\$ORG_REF_SHA256" \
        > "\$REFERENCE_RECORD"

    # ------------------------------------------------------------
    # Organelle filtering
    #
    # samtools fastq -f 12:
    # retain records where both the read and mate are unmapped
    #
    # samtools fastq -F 2304:
    # exclude secondary and supplementary alignments
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
    # Final per-sample report
    # ------------------------------------------------------------

    printf "${sample_id}\\t%s\\tPASS\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\tPASS\\n" \
        "\$REFERENCE_ID" \
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
