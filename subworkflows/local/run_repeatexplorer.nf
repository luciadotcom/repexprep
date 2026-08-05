include { REPEATEXPLORER } from '../../modules/local/repeatexplorer/main'

workflow RUN_REPEATEXPLORER {
    take:
    ch_fasta // channel: [ val(meta), path(fasta) ]

    main:
    ch_versions = Channel.empty()


    REPEATEXPLORER (
        ch_fasta
    )

    ch_versions = ch_versions.mix(REPEATEXPLORER.out.versions)

    emit:
    repex_dir = REPEATEXPLORER.out.repex_dir // channel: [ val(meta), path(dir) ]
    logs = REPEATEXPLORER.out.log
    reports = REPEATEXPLORER.out.report
    versions  = ch_versions                  // channel: [ path(versions.yml) ]
}