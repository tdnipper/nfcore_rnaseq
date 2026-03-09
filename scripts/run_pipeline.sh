#!/bin/bash
SAMPLESHEET=$1
FASTA=$2
GTF=$3
DIR=$4
nextflow run nf-core/rnaseq \
    -r 3.23 \
    --input $SAMPLESHEET \
    --fasta $FASTA \
    --gtf $GTF \
    --outdir $DIR/results_hisat2 \
    --with_umi \
    --umitools_bc_pattern NNNNNNNNNNNN \
    --aligner hisat2 \
    --hisat2_index $DIR/hisat2_index.tar.gz \
    --save_reference \
    --skip_pseudo_alignment \
    -profile podman \
    --save_unaligned \
    --save_align_intermeds \
    --trimmer fastp \
    --extra_fastp_args "--adapter_sequence AGATCGGAAGAGCACACGTCTGAACTCCAGTCA --adapter_sequence_r2 AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT --trim_poly_g" \
    -resume