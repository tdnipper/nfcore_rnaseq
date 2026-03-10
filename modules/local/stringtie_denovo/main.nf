process STRINGTIE_DENOVO {
    tag "$meta.id"
    label 'process_high'

    container 'biocontainers/stringtie:3.0.3--h29c0135_0'

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("*_transcriptome.gtf"), emit: gtf
    path "versions.yml",                          emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def strand = meta.strandedness == 'forward' ? '--fr' :
                 meta.strandedness == 'reverse' ? '--rf' : ''
    """
    stringtie \\
        $bam \\
        $strand \\
        -p $task.cpus \\
        $args \\
        -o ${prefix}_transcriptome.gtf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stringtie: \$(stringtie --version 2>&1)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_transcriptome.gtf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stringtie: \$(stringtie --version 2>&1)
    END_VERSIONS
    """
}
