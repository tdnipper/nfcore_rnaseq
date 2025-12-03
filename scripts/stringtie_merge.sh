#!/bin/bash

# Merge GTF files from rnaseq pipeline using StringTie

GENOME_PATH=$1
GENOME=$(basename "$GENOME_PATH" .gtf.gz)
DIR=$2

if [ ! -d "$DIR/stringtie" ]; then
    echo "Stringtie directory does not exist. Please run stringtie_denovo.sh first."
    exit 1
fi

podman run --rm \
    -v "$DIR/results_hisat2/genome/":/genomes/ \
    -v "$DIR/stringtie":/stringtie/ \
    -v "$DIR/results_hisat2/hisat2/stringtie/":/results/ \
    stringtie:3.0.0--h29c0135_0 \
    bash -c "
        cp /genomes/$GENOME.filtered.gtf reference.gtf && \
        gtf_files=\$(find /results/ -name '*.gtf' -type f) && \
        stringtie --merge -p 12 -o /stringtie/gencode_merged_transcriptome.gtf -G reference.gtf \${gtf_files}
    "