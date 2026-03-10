# Project Instructions

## Test Data

- Test data can be derived from fasta files in `raw_data/`
- Reference genome: `../genomes/hybrid/human_h1n1.fa.gz`
- Reference GTF: `../genomes/hybrid/human_h1n1.gtf.gz`

## Pipeline

- Use DSL2 (not DSL1)
- Reference `memory.md` for pipeline logic and execution

## Test Run Command

```bash
nextflow run -resume main.nf --samplesheet samplesheet.csv --fasta ../genomes/hybrid/human_h1n1.fa.gz --gtf ../genomes/hybrid/human_h1n1.gtf.gz --dir ./output
```

## Environment

- Use `.venv` for Python modules and nf-core
- Use Podman for container runtime

## Git

- Don't credit Claude Code in commits and PRs
