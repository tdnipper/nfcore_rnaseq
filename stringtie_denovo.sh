#!/bin/bash

# Run stringtie without -G on hisat2 bam files

if [ ! -d "stringtie" ]; then
    mkdir stringtie
fi

podman run --rm \
    -v ./results_hisat2/genome/:/genomes/ \
    -v ./results_hisat2/hisat2/:/results/ \
    -v ./stringtie:/stringtie/ \
    stringtie:3.0.0--h29c0135_0 \
    bash -c "
        bam_files=\$(find /results/ -name '*.umi_dedup.sorted.bam' -type f) && \
        for bam_file in \${bam_files}; do
            sample_name=\$(basename \${bam_file} .umi_dedup.sorted.bam)
            stringtie -p 12 -m 50 -o /stringtie/\${sample_name}_transcriptome.gtf \${bam_file}
        done && \
        stringtie --merge -p 12 -v -m 50 -T 1 -G /genomes/hybrid_gencode_fixed.filtered.gtf -o /stringtie/merged_transcriptome.gtf \$(find /stringtie/ -name '*_transcriptome.gtf' -type f)
    "