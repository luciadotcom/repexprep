include { RUN_REPEATEXPLORER } from '../subworkflows/local/run_repeatexplorer'

workflow REPEXANALYSIS {

    take:
    ch_repex_fasta
    
    main:

    RUN_REPEATEXPLORER (
        ch_repex_fasta
    )
}