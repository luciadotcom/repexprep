process SELECT_GLOBAL_TARGET_LENGTH {
    tag "global"
    label 'process_single'

    input:
    path profiles
    val target_length_mode
    val target_read_length
    val min_retained_fraction
    val min_target_read_length
    val max_target_read_length

    output:
    path "global_target_length.tsv"     , emit: global_target
    path "target_length_per_sample.tsv" , emit: per_sample_report
    path "versions.yml"                 , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    

    def fixed_target_arg = (target_read_length != null && target_read_length != -1 && target_read_length != '') ? "--target-read-length ${target_read_length}" : ''
    def min_len_arg      = (min_target_read_length != null && min_target_read_length != -1 && min_target_read_length != '') ? "--min-target-read-length ${min_target_read_length}" : ''
    def max_len_arg      = (max_target_read_length != null && max_target_read_length != -1 && max_target_read_length != '') ? "--max-target-read-length ${max_target_read_length}" : ''
    def min_fraction_arg = (min_retained_fraction != null && min_retained_fraction != '') ? "--min-retained-fraction ${min_retained_fraction}" : ''

    """
    select_global_target_length.py \\
        --profiles ${profiles.join(' ')} \\
        --mode "${target_length_mode}" \\
        ${fixed_target_arg} \\
        ${min_fraction_arg} \\
        ${min_len_arg} \\
        ${max_len_arg} \\
        ${args} \\
        --output-global "global_target_length.tsv" \\
        --output-per-sample "target_length_per_sample.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | awk '{print \$2}')
    END_VERSIONS
    """
}