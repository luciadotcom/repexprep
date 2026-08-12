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

    def runRepeatExplorer =
        params.run_repeatexplorer
            ?.toString()
            ?.toBoolean() ?: false

    if (runRepeatExplorer) {
        REPEXANALYSIS(REPEXPREP.out.repex_fasta)
    }
}