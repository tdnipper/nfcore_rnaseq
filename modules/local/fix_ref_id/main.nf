process FIX_REF_ID {
    tag "fix_ref_id"
    label 'process_single'

    container 'biocontainers/python:3.10.4'

    input:
    path(merged_gtf)

    output:
    path("merged_transcriptome_id.gtf"), emit: gtf
    path "versions.yml",                 emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    use_ref_id.py $merged_gtf merged_transcriptome_id.gtf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    touch merged_transcriptome_id.gtf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}
