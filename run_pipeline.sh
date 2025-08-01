#!/bin/bash

nextflow run nf-core/rnaseq \
    -r 3.19.0 \
    --input samplesheet_unsplit.csv \
    --fasta genomes/hybrid_gencode_reformat.fa.gz \
    --gtf genomes/hybrid_gencode_fixed.gtf.gz \
    --outdir results_hisat2 \
    --with_umi \
    --umitools_bc_pattern NNNNNNNNNNNN \
    --aligner hisat2 \
    --skip_pseudo_alignment \
    -profile podman \
    --featurecounts_group_type gene_type \
    --save_unaligned \
    --save_reference \
    --save_align_intermeds \
    --remove_ribo_rna \
    --trimmer fastp \
    --extra_fastp_args "--adapter_sequence AGATCGGAAGAGCACACGTCTGAACTCCAGTCA --adapter_sequence_r2 AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT" \
    -resume \
    --gencode