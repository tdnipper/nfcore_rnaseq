#!/usr/bin/env nextflow

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    nfcore_rnaseq_denovo
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    De novo transcriptome assembly and quantification pipeline for paired-end
    UMI-tagged RNA-seq data.

    Steps: FastQC → UMI extract → fastp → HISAT2 align → UMI dedup →
           StringTie de novo → StringTie merge → fix_ref_id →
           Salmon index → Salmon quant → tximeta → MultiQC

    Usage:
        nextflow run main.nf \
            --input samplesheet.csv \
            --fasta genome.fa.gz \
            --gtf genome.gtf.gz \
            --outdir results
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

nextflow.enable.dsl = 2

include { DENOVO_RNASEQ } from './workflows/denovo_rnaseq'

//
// Validate required parameters
//
def validateParams() {
    if (!params.input)  error "Please provide --input samplesheet (CSV)"
    if (!params.fasta)  error "Please provide --fasta genome FASTA file"
    if (!params.gtf)    error "Please provide --gtf reference annotation GTF"
}

//
// Parse samplesheet CSV into reads channel
// Expected columns: sample, fastq_1, fastq_2 (optional), strandedness
//
def parseSamplesheet(samplesheet) {
    Channel
        .fromPath(samplesheet)
        .splitCsv(header: true, strip: true)
        .map { row ->
            def meta = [
                id          : row.sample,
                strandedness: row.strandedness ?: 'auto',
                single_end  : (!row.fastq_2 || row.fastq_2.trim() == '')
            ]
            def reads = meta.single_end
                ? [ file(row.fastq_1) ]
                : [ file(row.fastq_1), file(row.fastq_2) ]
            return [ meta, reads ]
        }
}

workflow {

    validateParams()

    // Check available memory for HISAT2 index build
    if (!params.hisat2_index) {
        def hisat2_build_memory = params.hisat2_build_memory ?: 0
        def max_mem = (params.max_memory as nextflow.util.MemoryUnit).toGiga()
        if (max_mem >= hisat2_build_memory) {
            log.info ""
            log.info "HISAT2 index build: ${max_mem} GB available (>= ${hisat2_build_memory} GB threshold) -- splice sites and exons WILL be used"
            log.info ""
        } else {
            log.warn "HISAT2 index build: ${max_mem} GB available (< ${hisat2_build_memory} GB threshold) -- splice sites and exons will NOT be used"
            log.warn "Set --hisat2_build_memory to a smaller value to override this check"
        }
    }

    ch_reads       = parseSamplesheet(params.input)
    ch_samplesheet = Channel.value([ [id:'samplesheet'], file(params.input) ])

    DENOVO_RNASEQ ( ch_reads, ch_samplesheet )
}
