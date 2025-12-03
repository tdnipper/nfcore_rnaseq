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

process RNASEQ {
    tag "rnaseq"
    publishDir "${params.dir}/nextflow_outputs/rnaseq", mode: 'copy', overwrite: true
    input:
    val dummy from start_ch

    output:
    stdout into run_done

    script:
    """
    echo "Starting run_pipeline.sh (nf-core/rnaseq wrapper)"
    bash "${params.repo}/scripts/run_pipeline.sh" "${params.samplesheet}" "${params.fasta}" "${params.gtf}" "${params.dir}" || exit 1
    # create a small manifest for published outputs
    echo "results_hisat2: ${params.dir}/results_hisat2" > rnaseq.outputs.txt || true
    echo "RUN_PIPELINE_DONE"
    """
}

process STRINGTIE_DENOVO {
    tag "stringtie_denovo"
    publishDir "${params.dir}/nextflow_outputs/stringtie_denovo", mode: 'copy', overwrite: true
    input:
    val token from run_done

    output:
    stdout into denovo_done

    script:
    """
    echo "Checking for hisat2 results"
    if [ ! -d "${params.dir}/results_hisat2/hisat2" ]; then
        echo "ERROR: expected hisat2 results in ${params.dir}/results_hisat2/hisat2 but directory not found"
        exit 1
    fi

    echo "Starting stringtie_denovo.sh"
    bash "${params.repo}/scripts/stringtie_denovo.sh" "${params.gtf}" "${params.dir}"
    # publish a small manifest pointing to per-sample GTFs
    echo "stringtie_dir: ${params.dir}/stringtie" > stringtie_denovo.outputs.txt || true
    echo "STRINGTIE_DENOVO_DONE"
    """
}

process STRINGTIE_MERGE {
    tag "stringtie_merge"
    publishDir "${params.dir}/nextflow_outputs/stringtie_merge", mode: 'copy', overwrite: true
    input:
    val token from denovo_done

    output:
    stdout into merge_done

    script:
    """
    echo "Checking for per-sample GTFs in ${params.dir}/stringtie"
    shopt -s nullglob || true
    gtfs=("${params.dir}/stringtie"/*.gtf)
    if [ "${#gtfs[@]}" -eq 0 ]; then
        echo "ERROR: no GTF files found in ${params.dir}/stringtie. Run stringtie_denovo first."
        exit 1
    fi

    echo "Starting stringtie_merge.sh"
    bash "${params.repo}/scripts/stringtie_merge.sh" "${params.gtf}" "${params.dir}"
    # publish location of merged GTF
    echo "merged_gtf: ${params.dir}/stringtie/gencode_merged_transcriptome.gtf" > stringtie_merge.outputs.txt || true
    echo "STRINGTIE_MERGE_DONE"
    """
}

process RUN_PIPELINE_DENOVO {
    tag "run_pipeline_denovo_transcriptome"
    publishDir "${params.dir}/nextflow_outputs/run_pipeline_denovo", mode: 'copy', overwrite: true
    input:
    val token from merge_done

    output:
    stdout into final_done

    script:
    """
    echo "Starting run_pipeline_denovo_transcriptome.sh (nf-core/rnaseq wrapper)"
    bash "${params.repo}/scripts/run_pipeline_denovo_transcriptome.sh" "${params.samplesheet}" "${params.fasta}" "${params.gtf}" "${params.dir}" || exit 1
    echo "results_denovoTranscriptome: ${params.dir}/results_denovoTranscriptome" > run_pipeline_denovo.outputs.txt || true
    echo "ALL_DONE"
    """
}

workflow {
    RNASEQ()
    STRINGTIE_DENOVO()
    STRINGTIE_MERGE()
    RUN_PIPELINE_DENOVO()

    final_done.subscribe { line -> println "Workflow finished: ${line}" }
}
