#!/usr/bin/env nextflow

/*
Nextflow wrapper for this repository (updated)

This workflow orchestrates the original helper scripts and now includes two
native Nextflow `process` blocks that run StringTie directly in a container.

Steps (in order):
    1) `RNASEQ` — runs the existing `scripts/run_pipeline.sh` (nf-core/rnaseq wrapper).
    2) `STRINGTIE_DENOVO` — native Nextflow process using the `stringtie` container;
         assembles per-sample transcriptomes from hisat2 BAMs and writes GTFs to
         `${params.dir}/stringtie`.
    3) `STRINGTIE_MERGE` — native Nextflow process using the `stringtie` container;
         merges per-sample GTFs into a consolidated GTF under `${params.dir}/stringtie`.
    4) `RUN_PIPELINE_DENOVO` — runs the existing
         `scripts/run_pipeline_denovo_transcriptome.sh` (nf-core/rnaseq wrapper for
         pseudo-alignment / salmon).

Design notes:
    - Moving StringTie into native processes removes the need for Podman calls
        inside those scripts and lets Nextflow manage container execution for them.
    - The rnaseq steps still call the original scripts to preserve nf-core
        configuration and profiles; they can be ported to native processes later.
    - Each process publishes a small manifest under
        `${params.dir}/nextflow_outputs/<process>` describing main output locations.

Usage:
    nextflow run main.nf --samplesheet <path> --fasta <path> --gtf <path> [--dir <dir>]

Requirements:
    - Nextflow and a container runtime (Docker or Podman) available on the host.
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
    container 'stringtie:3.0.0--h29c0135_0'
    input:
    val token from run_done

    output:
    stdout into denovo_done

    script:
    """
    set -euo pipefail
    echo "Checking for hisat2 results"
    if [ ! -d "${params.dir}/results_hisat2/hisat2" ]; then
        echo "ERROR: expected hisat2 results in ${params.dir}/results_hisat2/hisat2 but directory not found"
        exit 1
    fi

    mkdir -p "${params.dir}/stringtie"

    GENOME=$(basename "${params.gtf}" .gtf.gz)

    bam_files=\$(find "${params.dir}/results_hisat2/hisat2" -name '*.umi_dedup.sorted.bam' -type f)
    for bam_file in \${bam_files}; do
        sample_name=\$(basename \${bam_file} .umi_dedup.sorted.bam)
        stringtie -p 12 -m 50 --rf -o "${params.dir}/stringtie/\${sample_name}_transcriptome.gtf" \${bam_file}
    done

    stringtie --merge -p 12 -v -m 50 -T 1 -G "${params.dir}/results_hisat2/genome/${GENOME}.filtered.gtf" -o "${params.dir}/stringtie/merged_transcriptome.gtf" \$(find "${params.dir}/stringtie" -name '*_transcriptome.gtf' -type f)

    # publish a small manifest pointing to per-sample GTFs
    echo "stringtie_dir: ${params.dir}/stringtie" > stringtie_denovo.outputs.txt || true
    echo "STRINGTIE_DENOVO_DONE"
    """
}

process STRINGTIE_MERGE {
    tag "stringtie_merge"
    publishDir "${params.dir}/nextflow_outputs/stringtie_merge", mode: 'copy', overwrite: true
    container 'stringtie:3.0.0--h29c0135_0'
    input:
    val token from denovo_done

    output:
    stdout into merge_done

    script:
    """
    set -euo pipefail
    echo "Checking for per-sample GTFs in ${params.dir}/stringtie"
    shopt -s nullglob || true
    gtfs=("${params.dir}/stringtie"/*.gtf)
    if [ "${#gtfs[@]}" -eq 0 ]; then
        echo "ERROR: no GTF files found in ${params.dir}/stringtie. Run stringtie_denovo first."
        exit 1
    fi

    GENOME=$(basename "${params.gtf}" .gtf.gz)

    cp "${params.dir}/results_hisat2/genome/${GENOME}.filtered.gtf" "${params.dir}/stringtie/reference.gtf" || { echo "Reference GTF not found"; exit 1; }

    gtf_files=\$(find "${params.dir}/stringtie" -name '*.gtf' -type f)
    if [ -z "\${gtf_files}" ]; then echo 'No GTFs found in ${params.dir}/stringtie'; exit 1; fi

    stringtie --merge -p 12 -o "${params.dir}/stringtie/gencode_merged_transcriptome.gtf" -G "${params.dir}/stringtie/reference.gtf" \${gtf_files}

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
