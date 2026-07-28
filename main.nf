nextflow.enable.dsl = 2

/*
 * main.nf
 *
 * Workflow entrypoint. 
 *
 */

include { REPEXPREP } from './workflows/repexprep'
include { REPEXANALYSIS } from './workflows/repexanalysis'

workflow {
    REPEXPREP()

    if (params.run_repeatexplorer) {
        REPEXANALYSIS ( REPEXPREP.out.repex_fasta )
    }
}