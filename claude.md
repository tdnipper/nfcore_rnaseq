test data can be derived from fasta files in raw_data

../genomes/hybrid/human_h1n1.fa.gz and ../genomes/hybrid/human_h1n1.gtf.gz are fasta and gtf references respectively

Use DSL2 instead of DSL1

test run command nextflow run -resume main.nf --samplesheet samplesheet.csv --fasta ../genomes/hybrid/human_h1n1.fa.gz --gtf ../genomes/hybrid/human_h1n1.gtf.gz --dir ./output