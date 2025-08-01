#!/bin/bash

nextflow run nf-core/rnaseq \
    -r 3.19.0 \
    --input samplesheet_unsplit.csv \
    --fasta genomes/hybrid_gencode_reformat.fa.gz \
    --gtf stringtie/stringtie_merged_transcriptome.filtered.gtf.gz \
    --outdir results_denovoTranscriptome \
    --with_umi \
    --umitools_bc_pattern NNNNNNNNNNNN \
    --skip_alignment \
    --pseudo_aligner salmon \
    --salmon_quant_libtype ISR \
    -profile podman \
    --save_unaligned \
    --save_reference \
    --remove_ribo_rna \
    --trimmer fastp \
    --extra_fastp_args "--adapter_sequence AGATCGGAAGAGCACACGTCTGAACTCCAGTCA --adapter_sequence_r2 AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT" \
    -resume \
    --featurecounts_group_type gene_type \
    --gencode