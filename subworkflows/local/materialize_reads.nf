nextflow.enable.dsl = 2

include { FETCH_READS } from '../../subworkflows/local/fetch_reads'
include { INPUT_PROVENANCE } from '../../modules/local/input_provenance/main'

def emptyToNull(value) {
    def text = value?.toString()?.trim()
    return text ? text : null
}

def buildInputMeta(row) {

    def source = row.source.toString().trim().toLowerCase()

    def requestedProvider = row.provider
        ? row.provider.toString().trim().toLowerCase()
        : source == 'local'
            ? 'local'
            : 'auto'

    return [
        id                    : row.sample.toString().trim(),
        sample                : row.sample.toString().trim(),

        source                : source,
        provider              : requestedProvider,
        resolved_provider     : source == 'local'
            ? 'local'
            : null,

        accession             : emptyToNull(row.accession),

        organism              : emptyToNull(row.organism),

        genome_size_1C_bp     : row.genome_size_1C_bp
            ? row.genome_size_1C_bp as Long
            : null,

        ploidy                : row.ploidy
            ? row.ploidy as Integer
            : null,

        target_coverage       : row.target_coverage
            ? row.target_coverage as Double
            : null,

        target_read_length    : row.target_read_length
            ? row.target_read_length as Integer
            : null,
        sampling_seed         : emptyToNull(row.sampling_seed) !=null
            ? row.sampling_seed as Integer
            : null,
            
        organelle_fasta       : emptyToNull(row.organelle_fasta),

        original_fastq_1      : emptyToNull(row.fastq_1),
        original_fastq_2      : emptyToNull(row.fastq_2),

        single_end            : false
    ]
}


workflow MATERIALIZE_READS {

    take:
    validated_samplesheet
    certificate_ch

    main:

    row_ch = validated_samplesheet
        .splitCsv(
            header: true,
            strip: true
        )
        .map { row ->

            def meta = buildInputMeta(row)

            tuple(
                meta,
                emptyToNull(row.fastq_1),
                emptyToNull(row.fastq_2)
            )
        }


   
    source_branches = row_ch.branch {

        local:
            it[0].source == 'local'

        accession:
            it[0].source == 'accession'
    }

    local_reads_ch = source_branches.local.map {
        meta,
        fastq_1,
        fastq_2 ->

        def reads = [
            file(
                fastq_1,
                checkIfExists: true
            ),
            file(
                fastq_2,
                checkIfExists: true
            )
        ]

        tuple(meta, reads)
    }

    remote_meta_ch = source_branches.accession.map {
        meta,
        fastq_1,
        fastq_2 ->

        meta
    }


    FETCH_READS(
        remote_meta_ch,
        certificate_ch
    )


    reads_ch = local_reads_ch
        .mix(FETCH_READS.out.reads)
        .map {
            meta,
            reads ->

            if (reads == null || reads.size() != 2) {
                error(
                    "Sample '${meta.id}' must resolve to exactly " +
                    "two paired-end FASTQ files."
                )
            }

            tuple(meta, reads)
        }

    INPUT_PROVENANCE(reads_ch)

    emit:
    reads = reads_ch

    input_provenance = INPUT_PROVENANCE.out.report
    
    remote_provider_reports =
        FETCH_READS.out.provider_reports

    remote_manifests =
        FETCH_READS.out.ena_manifest

    versions =
        FETCH_READS.out.versions
}