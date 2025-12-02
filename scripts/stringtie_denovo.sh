#!/bin/bash

# Run stringtie without -G on hisat2 bam files

GENOME_PATH=$1
GENOME=$(basename $GENOME_PATH .gtf.gz)
DIR=$2

if [ ! GENOME_PATH ]; then
    echo "Usage: bash stringtie_denovo.sh <path_to_genome_gtf>"
    exit 1
fi

if [ ! -d "$DIR/stringtie" ]; then
    mkdir -p "$DIR/stringtie"
fi

podman run --rm \
    -v $DIR/results_hisat2/genome/:/genomes/ \
    -v $DIR/results_hisat2/hisat2/:/results/ \
    -v $DIR/stringtie:/stringtie/ \
    stringtie:3.0.0--h29c0135_0 \
    bash -c "
        bam_files=\$(find /results/ -name '*.umi_dedup.sorted.bam' -type f) && \
        for bam_file in \${bam_files}; do
            sample_name=\$(basename \${bam_file} .umi_dedup.sorted.bam)
            stringtie -p 12 -m 50 --rf -o /stringtie/\${sample_name}_transcriptome.gtf \${bam_file}
        done && \
        stringtie --merge -p 12 -v -m 50 -T 1 -G /genomes/$GENOME.filtered.gtf -o /stringtie/merged_transcriptome.gtf \$(find /stringtie/ -name '*_transcriptome.gtf' -type f)
    "