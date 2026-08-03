process RESOLVE_REMOTE_PROVIDER {

    tag "${meta.id}"

    label 'process_low'

    input:
    val(meta)

    output:
    tuple val(meta),
          path("${meta.id}.remote_resolution.json"),
          emit: resolution

    path "versions.yml",
         emit: versions

    script:
    def accession = meta.accession
    def provider  = meta.provider

    """
    resolve_remote_provider.py \
        --sample '${meta.id}' \
        --accession '${accession}' \
        --provider '${provider}' \
        --output '${meta.id}.remote_resolution.json'

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | sed 's/Python //')
        remote_provider_resolver: "1.0"
    END_VERSIONS
    """
}
