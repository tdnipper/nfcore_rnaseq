#!/bin/bash

nextflow run nf-core/rnaseq \
    -r 3.19.0 \
    --input samplesheet.csv \
    --fasta genomes/hybrid_gencode_reformat.fa.gz \
    --gtf genomes/hybrid_gencode_fixed.filtered.gtf.gz \
    --outdir results_hisat2 \
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
    --skip_gtf_filter \
    --gencode