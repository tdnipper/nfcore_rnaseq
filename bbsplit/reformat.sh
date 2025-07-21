#!/bin/bash

# Directory containing interleaved fastq files
INTERLEAVED_DIR="/interleaved/"

# Output directory for split fastq files
OUTPUT_DIR="/split/"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Loop through all interleaved fastq.gz files in the interleaved directory
for FILE in "$INTERLEAVED_DIR"/*.fastq.gz; do
    # Extract the base name of the file (without path and extension)
    BASENAME=$(basename "$FILE" .fastq.gz)

    # Run reformat.sh to split interleaved files into paired-end files
    reformat.sh \
        in="$FILE" \
        out1="$OUTPUT_DIR/${BASENAME}_1.fastq.gz" \
        out2="$OUTPUT_DIR/${BASENAME}_2.fastq.gz"

done

echo "Reformatting completed. Interleaved files have been split into paired-end files."
