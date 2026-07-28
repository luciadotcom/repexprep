process REPEATEXPLORER {
    tag "$meta.id"
    label 'process_high'

    container '/cvmfs/singularity.metacentrum.cz/RepeatExplorer/repex_tarean.sif'

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("${meta.id}_repex"), emit: repex_dir
    path "versions.yml"               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}_repex"
    def memory_kb = task.memory ? task.memory.toUnit('KB').toBigInteger() : ''
    def memory_opt = memory_kb ? "-r ${memory_kb}" : ''
    def paired_opt = meta.single_end ? '' : '-p'

    """
    export TMPDIR="\${SCRATCHDIR:-\$PWD/tmp}"
    mkdir -p "\$TMPDIR"

    seqclust \\
        $fasta \\
        -c $task.cpus \\
        $memory_opt \\
        $paired_opt \\
        -tax VIRIDIPLANTAE3.0 \\
        -v $prefix \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        repeatexplorer: \$(seqclust --help 2>&1 | head -n 1 | sed 's/#//g')
    END_VERSIONS
    """
}