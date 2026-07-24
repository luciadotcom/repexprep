include { LENGTH_NORMALIZATION } from '../../subworkflows/local/length_normalization/main'

workflow {

    // Validar argumentos mínimos
    if (!params.r1 || !params.r2 || !params.sample) {
        error "Faltan parámetros obligatorios: --r1, --r2 o --sample"
    }

    // Canal de lectura simple y directo
    ch_reads = Channel.of([
        [ id: params.sample ],
        [ file(params.r1), file(params.r2) ]
    ])

    // Parámetros opcionales con fallback
    mode       = params.target_length_mode ?: 'global_auto'
    target_len = params.target_read_length ?: null
    min_frac   = params.min_retained_fraction ? params.min_retained_fraction as Double : 0.95
    min_len    = params.min_target_read_length ? params.min_target_read_length as Integer : 1
    max_len    = params.max_target_read_length ? params.max_target_read_length as Integer : 1000

    LENGTH_NORMALIZATION (
        ch_reads,
        mode,
        target_len,
        min_frac,
        min_len,
        max_len
    )

    // Visualizar salidas
    LENGTH_NORMALIZATION.out.global_target.view { "GLOBAL TARGET: $it" }
    LENGTH_NORMALIZATION.out.normalized_reads.view { "NORMALIZED READS: $it" }
    LENGTH_NORMALIZATION.out.crop_reports.view { "CROP REPORT: $it" }
}
