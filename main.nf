#!/usr/bin/env nextflow

/*
Simple Nextflow wrapper to orchestrate the existing scripts in this repository.
It runs the following steps (in order):
  1) run_pipeline.sh
  2) stringtie_denovo.sh
  3) stringtie_merge.sh
  4) run_pipeline_denovo_transcriptome.sh

Notes:
- Some scripts internally call Podman/Nextflow; this wrapper simply invokes them in sequence.
- Provide required inputs with `--samplesheet`, `--fasta`, `--gtf`. Optionally set `--dir`.
- Example: `nextflow run main.nf --samplesheet samplesheet.csv --fasta path.fa --gtf annotations.gtf.gz --dir /path/to/project`
*/

params.samplesheet = null
params.fasta = null
params.gtf = null
params.dir = null
params.repo = "${pwd()}"

if (!params.samplesheet || !params.fasta || !params.gtf) {
    println "Usage: nextflow run main.nf --samplesheet <path> --fasta <path> --gtf <path> [--dir <dir>]"
    System.exit(1)
}

if (!params.dir) {
    params.dir = pwd().toString()
}

Channel
    .value(true)
    .set { start_ch }

process RUN_PIPELINE {
    tag "run_pipeline"
    input:
    val dummy from start_ch

    output:
    stdout into run_done

    script:
    """
    echo "Starting run_pipeline.sh (nf-core/rnaseq wrapper)"
    bash "${params.repo}/scripts/run_pipeline.sh" "${params.samplesheet}" "${params.fasta}" "${params.gtf}" "${params.dir}" || exit 1
    echo "RUN_PIPELINE_DONE"
    """
}

process STRINGTIE_DENOVO {
    tag "stringtie_denovo"
    input:
    val token from run_done

    output:
    stdout into denovo_done

    script:
    """
    echo "Starting stringtie_denovo.sh"
    bash ${params.repo}/scripts/stringtie_denovo.sh "${params.gtf}" "${params.dir}"
    echo "STRINGTIE_DENOVO_DONE"
    """
}

process STRINGTIE_MERGE {
    tag "stringtie_merge"
    input:
    val token from denovo_done

    output:
    stdout into merge_done

    script:
    """
    echo "Starting stringtie_merge.sh"
    bash ${params.repo}/scripts/stringtie_merge.sh "${params.gtf}" "${params.dir}"
    echo "STRINGTIE_MERGE_DONE"
    """
}

process RUN_PIPELINE_DENOVO {
    tag "run_pipeline_denovo_transcriptome"
    input:
    val token from merge_done

    output:
    stdout into final_done

    script:
    """
    echo "Starting run_pipeline_denovo_transcriptome.sh (nf-core/rnaseq wrapper)"
    bash "${params.repo}/scripts/run_pipeline_denovo_transcriptome.sh" "${params.samplesheet}" "${params.fasta}" "${params.gtf}" "${params.dir}" || exit 1
    echo "ALL_DONE"
    """
}

workflow {
    RUN_PIPELINE()
    STRINGTIE_DENOVO()
    STRINGTIE_MERGE()
    RUN_PIPELINE_DENOVO()

    final_done.subscribe { line -> println "Workflow finished: ${line}" }
}
