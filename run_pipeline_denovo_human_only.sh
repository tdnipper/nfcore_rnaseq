#!/bin/bash

nextflow run nf-core/rnaseq \
    --input human_only_samplesheet.csv \
    --fasta genomes/hybrid_gencode.fa.gz \
    --gtf stringtie/gencode_merged_transcriptome.gtf.gz \
    --outdir results_denovoTranscriptome_human_only \
    --with_umi \
    --umitools_bc_pattern NNNNNNNNNNN \
    --aligner star_salmon \
    --pseudo_aligner salmon \
    --salmon_quant_libtype ISR \
    -profile podman \
    --trimmer fastp \
    --save_unaligned \
    --multiqc_title gencode \
    -resume \
    --gencode