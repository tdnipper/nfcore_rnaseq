#!/bin/bash

# Directory containing raw fastq files
RAW_DATA_DIR="/raw_data/"

# Output directory for trimmed fastq files
OUTPUT_DIR="/trimmed/"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Loop through all _R1.fastq.gz files in the raw_data directory
for R1_FILE in "$RAW_DATA_DIR"/*_R1.fastq.gz; do
    # Derive the corresponding _R2 file
    R2_FILE="${R1_FILE/_R1.fastq.gz/_R2.fastq.gz}"

    # Extract the base name of the file (without path and _R1.fastq.gz)
    BASENAME=$(basename "$R1_FILE" _R1.fastq.gz)

    # Check if the corresponding _R2 file exists
    if [[ -f "$R2_FILE" ]]; then
        # Run fastp to trim reads
        fastp \
            -i "$R1_FILE" \
            -I "$R2_FILE" \
            -o "$OUTPUT_DIR/${BASENAME}_trimmed_1.fastq.gz" \
            -O "$OUTPUT_DIR/${BASENAME}_trimmed_2.fastq.gz" \
            --html "$OUTPUT_DIR/${BASENAME}_fastp_report.html" \
            --json "$OUTPUT_DIR/${BASENAME}_fastp_report.json"
    else
        echo "Warning: Missing R2 file for $R1_FILE. Skipping..."
    fi
done

echo "Read trimming completed."
