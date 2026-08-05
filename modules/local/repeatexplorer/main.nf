process REPEATEXPLORER {
    tag "$meta.id"
    label 'process_high'

    container '/cvmfs/singularity.metacentrum.cz/RepeatExplorer/repex_tarean.sif'

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("${meta.id}_repex"), emit: repex_dir

    tuple val(meta),
          path("${meta.id}.repeatexplorer.log"),
          emit: log

    tuple val(meta),
          path("${meta.id}.repeatexplorer_run.tsv"),
          emit: report
    path "versions.yml"               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}_repex"
    def memory_kb = task.memory ? task.memory.toUnit('KB').toBigInteger() : ''
    def memory_opt = memory_kb ? "-r ${memory_kb}" : ''
    def paired_opt = meta.single_end ? '' : '-p'
    def taxon = params.repeatexplorer_taxon ?: 'VIRIDIPLANTAE3.0'
   
   
    """
    set -euo pipefail

    export TMPDIR="\${SCRATCHDIR:-\$PWD/tmp}"
    mkdir -p "\$TMPDIR"

    START_TIME=\$(date --iso-8601=seconds)

    set +e

    seqclust \\
        '${fasta}' \\
        -c '${task.cpus}' \\
        ${memory_opt} \\
        ${paired_opt} \\
        -tax '${taxon}' \\
        -v '${prefix}' \\
        ${args} \\
        > '${meta.id}.repeatexplorer.log' 2>&1
    
    EXIT_STATUS=\$?

    set -e

    END_TIME=\$(date --iso-8601=seconds)
    
    {
        printf '%s\\n' \
            'sample\tinput_fasta\ttaxon\tcpus\tmemory\texit_status\tstart_time\tend_time\toutput_directory'

        printf '%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n' \
            '${meta.id}' \
            '${fasta}' \
            '${taxon}' \
            '${task.cpus}' \
            '${task.memory}' \
            "\$EXIT_STATUS" \
            "\$START_TIME" \
            "\$END_TIME" \
            '${prefix}'
    } > '${meta.id}.repeatexplorer_run.tsv'

    if [[ "\$EXIT_STATUS" -ne 0 ]]; then
        echo \
            "RepeatExplorer failed for sample ${meta.id}." \
            >&2

        tail -n 100 \
            '${meta.id}.repeatexplorer.log' \
            >&2 || true

        exit "\$EXIT_STATUS"
    fi

    if [[ ! -d '${prefix}' ]]; then
        echo \
            "RepeatExplorer did not create the expected directory: ${prefix}" \
            >&2

        exit 1
    fi

    if [[ -z "\$(find '${prefix}' -mindepth 1 -print -quit)" ]]; then
        echo \
            "RepeatExplorer output directory is empty: ${prefix}" \
            >&2

        exit 1
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        repeatexplorer: \$(seqclust --help 2>&1 | head -n 1 | sed 's/#//g')
    END_VERSIONS
    """
}