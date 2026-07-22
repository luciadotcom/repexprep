nextflow.enable.dsl = 2

/*
 * main.nf
 *
 * Workflow entrypoint.  Punto de entrada del pipeline.
 * Small file. Here we only activate DSL2 and import the main workflow (in other words, REPEX is called here).
 *
 */

include { REPEXPREP } from './workflows/repexprep'

workflow {
    REPEXPREP()
}