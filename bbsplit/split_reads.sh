#!/bin/bash

RAW_DATA_DIR="/raw_data/"

OUTPUT_DIR="/out/"

cd "$(dirname "$0")"

for reads_file in "$RAW_DATA_DIR"/*_human.fastq.gz; do
    BASENAME=$(basename "$reads_file" _human.fastq.gz)
    reformat.sh in="$reads_file" \
        out1="$OUTPUT_DIR/${BASENAME}_R1.fastq.gz" \
        out2="$OUTPUT_DIR/${BASENAME}_R2.fastq.gz"
done
