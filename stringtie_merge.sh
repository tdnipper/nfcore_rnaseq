#!/bin/bash

# Merge GTF files from rnaseq pipeline using StringTie

if [ ! -d "stringtie" ]; then
    mkdir stringtie
fi

podman run --rm \
    -v ./results_hisat2_gencode_new/genome/:/genomes/ \
    -v ./results_hisat2_gencode_new/hisat2/stringtie/:/results/ \
    -v ./stringtie:/stringtie/ \
    stringtie:3.0.0--h29c0135_0 \
    bash -c "
        cp /genomes/hybrid_gencode_reformat.filtered.gtf reference.gtf && \
        gtf_files=\$(find /results/ -name '*.transcripts.gtf' -type f) && \
        stringtie --merge -p 12 -o /stringtie/gencode_merged_transcriptome.gtf -G reference.gtf \${gtf_files}
    "