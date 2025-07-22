#!/bin/bash

nextflow run nf-core/rnaseq \
    -r 3.19.0 \
    --input samplesheet.csv \
    --fasta genomes/hybrid_gencode.fa.gz \
    --gtf stringtie/stringtie_transcriptome.gtf.gz \
    --outdir results_denovoTranscriptome \
    --with_umi \
    --umitools_bc_pattern NNNNNNNNNNN \
    --aligner star_salmon \
    --pseudo_aligner salmon \
    --salmon_quant_libtype ISR \
    -profile podman \
    --trimmer fastp \
    --save_unaligned \
    --multiqc_title gencode \
    --save_reference \
    -resume \
    --gencode