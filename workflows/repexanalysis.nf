include { RUN_REPEATEXPLORER } from '../subworkflows/local/run_repeatexplorer'

workflow REPEXANALYSIS {

    take:
    ch_repex_fasta
    
    main:

    RUN_REPEATEXPLORER (
        ch_repex_fasta
    )

    emit: 

    repex_dir = RUN_REPEATEXPLORER.out.repex_dir
    logs = RUN_REPEATEXPLORER.out.logs
    reports = RUN_REPEATEXPLORER.out.reports
    versions = RUN_REPEATEXPLORER.out.versions
}