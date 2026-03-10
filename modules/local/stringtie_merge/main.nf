process STRINGTIE_MERGE {
    tag "merge"
    label 'process_high'

    container 'biocontainers/stringtie:3.0.3--h29c0135_0'

    input:
    path(per_sample_gtfs)
    path(ref_gtf)

    output:
    path("merged_transcriptome.gtf"), emit: gtf
    path "versions.yml",              emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    stringtie --merge \\
        -p $task.cpus \\
        -v \\
        -G $ref_gtf \\
        $args \\
        -o merged_transcriptome.gtf \\
        $per_sample_gtfs

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stringtie: \$(stringtie --version 2>&1)
    END_VERSIONS
    """

    stub:
    """
    touch merged_transcriptome.gtf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stringtie: \$(stringtie --version 2>&1)
    END_VERSIONS
    """
}
