#!/bin/bash
SAMPLESHEET=$1
FASTA=$2
GTF=$3
DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -f "$SAMPLESHEET" ]; then
	echo "Usage: bash run_pipeline.sh <path_to_samplesheet> <path_to_genome_fasta> <path_to_genome_gtf>"
	exit 1
fi

if [ ! -f "$FASTA" ]; then
	echo "Usage: bash run_pipeline.sh <path_to_samplesheet> <path_to_genome_fasta> <path_to_genome_gtf>"
	exit 1
fi

if [ ! -f "$GTF" ]; then
	echo "Usage: bash run_pipeline.sh <path_to_samplesheet> <path_to_genome_fasta> <path_to_genome_gtf>"
	exit 1
fi

bash scripts/run_pipeline.sh $SAMPLESHEET $FASTA $GTF $DIR && \
bash scripts/stringtie_denovo.sh $GTF $DIR && \
bash scripts/stringtie_merge.sh $GTF $DIR && \
bash scripts/run_pipeline_denovo_transcriptome.sh $SAMPLESHEET $FASTA $GTF $DIR