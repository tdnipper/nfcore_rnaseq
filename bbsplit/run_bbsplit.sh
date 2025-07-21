#!/bin/bash

# Directory containing raw fastq files
RAW_DATA_DIR="/trimmed/"

# Directory containing the index files
INDEX_DIR="/out/"

# Output directory for bbsplit results
OUTPUT_DIR="/out/"

# Change to the directory containing the script
cd "$(dirname "$0")"

# Loop through all _trimmed_1.fastq.gz files in the raw_data directory
for R1_FILE in "$RAW_DATA_DIR"/*_trimmed_1.fastq.gz; do
    # Derive the corresponding _trimmed_2 file
    R2_FILE="${R1_FILE/_trimmed_1.fastq.gz/_trimmed_2.fastq.gz}"

    # Extract the base name of the file (without path and _trimmed_1.fastq.gz)
    BASENAME=$(basename "$R1_FILE" _trimmed_1.fastq.gz)

    # Check if the corresponding _trimmed_2 file exists
    if [[ -f "$R2_FILE" ]]; then
        # Run bbsplit
        bbsplit.sh \
            in="$R1_FILE" \
            in2="$R2_FILE" \
            ref="$INDEX_DIR/ref" \
            basename="$OUTPUT_DIR/${BASENAME}_%.fastq.gz" \
            out1="$OUTPUT_DIR/${BASENAME}_1.fastq.gz" \
            out2="$OUTPUT_DIR/${BASENAME}_2.fastq.gz" \
            outu1="$OUTPUT_DIR/${BASENAME}_unmapped_1.fastq.gz" \
            outu2="$OUTPUT_DIR/${BASENAME}_unmapped_2.fastq.gz" \
            refstats="$OUTPUT_DIR/${BASENAME}_stats.txt" \
            
    else
        echo "Warning: Missing R2 file for $R1_FILE. Skipping..."
    fi
done

echo "BBSplit processing completed."