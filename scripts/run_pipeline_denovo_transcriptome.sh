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
    --outdir $DIR/results_denovoTranscriptome \
    --with_umi \
    --umitools_bc_pattern NNNNNNNNNNNN \
    --skip_alignment \
    --pseudo_aligner salmon \
    -profile podman \
    --save_unaligned \
    --save_reference \
    --trimmer fastp \
    --extra_fastp_args "--adapter_sequence AGATCGGAAGAGCACACGTCTGAACTCCAGTCA --adapter_sequence_r2 AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT" \
    -resume