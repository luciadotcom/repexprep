nextflow.enable.dsl = 2

params.input = null

include {
    VALIDATE_REPEX_FASTA
} from '../../../modules/local/validate_repex_fasta/main'

include {
    RUN_REPEATEXPLORER
} from '../../../subworkflows/local/run_repeatexplorer'


workflow {

    if (!params.input) {
        error "Provide --input <repex.fasta>"
    }

    input_ch = Channel.of(
        tuple(
            [
                id         : 'repex_smoke',
                sample     : 'repex_smoke',
                single_end : false
            ],
            file(
                params.input,
                checkIfExists: true
            )
        )
    )

    VALIDATE_REPEX_FASTA(input_ch)

    RUN_REPEATEXPLORER(
        VALIDATE_REPEX_FASTA.out.fasta
    )

    RUN_REPEATEXPLORER.out.repex_dir.view {
        meta,
        directory ->

        "REPEATEXPLORER_PASS: ${meta.id} | ${directory}"
    }
}
