#!/bin/bash

nextflow run nf-core/rnaseq \
    --input samplesheet.csv \
    --fasta genomes/hybrid_gencode_reformat.fa.gz \
    --gtf genomes/hybrid_gencode_fixed.gtf.gz \
    --outdir results_hisat2_gencode_new \
    --with_umi \
    --umitools_bc_pattern NNNNNNNNNNN \
    --aligner hisat2 \
    --skip_pseudo_alignment \
    --salmon_quant_libtype ISR \
    -profile podman \
    --trimmer fastp \
    --featurecounts_group_type gene_type \
    --save_unaligned \
    --multiqc_title gencode \
    --save_reference \
    --save_align_intermeds \
    -resume \
    --gencode