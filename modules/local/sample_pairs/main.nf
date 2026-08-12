process SAMPLE_PAIRS {

    tag "${meta.id}"

    label 'process_low'

    input:
    tuple val(meta), path(reads), path(coverage_plan)

    output:
    tuple val(meta), path("${meta.id}_R*.sampled.fastq.gz"), emit: reads
    tuple val(meta), path("${meta.id}.sampling_report.tsv"), emit: report

    script:
    def samplingSeed =
        meta.sampling_seed != null
            ? meta.sampling_seed
            : params.sampling_seed

    if (samplingSeed == null) {
        error(
            "ERROR [sample_pairs]: Missing sampling seed for " +
            "sample '${meta.id}'."
        )
    }

    """
    sample_pairs.py \
        --sample ${meta.id} \
        --r1 ${reads[0]} \
        --r2 ${reads[1]} \
        --coverage-plan ${coverage_plan} \
        --seed ${samplingSeed} \
        --out-r1 ${meta.id}_R1.sampled.fastq.gz \
        --out-r2 ${meta.id}_R2.sampled.fastq.gz \
        --report ${meta.id}.sampling_report.tsv
    """
}