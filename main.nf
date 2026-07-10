nextflow.enable.dsl = 2

/*
 * main.nf
 *
 * Punto de entrada del pipeline.
 * En una pipeline bien organizada, este archivo debe ser pequeño.
 * Aquí solo activamos DSL2 e importamos el workflow principal.
 */

include { REPEXPREP } from './workflows/repexprep'

workflow {
    REPEXPREP()
}