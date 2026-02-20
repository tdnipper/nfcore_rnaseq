# De Novo Transcriptome Assembly Pipeline

A Nextflow pipeline for reference-guided de novo transcriptome assembly and quantification from paired-end RNA-seq data. The pipeline discovers novel transcripts and isoforms absent from the reference annotation, then quantifies them across experimental conditions.

---

## Overview

The pipeline runs four sequential stages:

```
Raw FASTQ (paired-end, UMI-tagged)
        │
        ▼
[Stage 1] RNASEQ — nf-core/rnaseq + HISAT2
        │  Adapter trimming, UMI deduplication, genome alignment
        │  Output: UMI-deduped sorted BAMs
        │
        ▼
[Stage 2] STRINGTIE_DENOVO — StringTie 3.0.0 (per-sample)
        │  Pure de novo assembly (no reference constraint)
        │  Output: per-sample GTFs
        │
        ▼
[Stage 3] STRINGTIE_MERGE — StringTie 3.0.0 --merge
        │  Consolidate all per-sample GTFs, anchored to reference annotation
        │  Output: gencode_merged_transcriptome.gtf
        │
        ▼
[Stage 4] RUN_PIPELINE_DENOVO — nf-core/rnaseq + Salmon
           Pseudo-alignment quantification against assembled transcriptome
           Output: TPM and count estimates per transcript
```

---

## Pipeline Design

### Stage 1 — Genome Alignment (`scripts/run_pipeline.sh`)

Runs **nf-core/rnaseq v3.22.0** using the HISAT2 aligner.

Key parameters:
- `--trimmer fastp` with explicit Illumina TruSeq adapter sequences
- `--with_umi --umitools_bc_pattern NNNNNNNNNNNN` — removes PCR duplicates using 12 bp UMI barcodes
- `--skip_pseudo_alignment` — alignment only, no Salmon at this stage
- `--save_reference` — saves the filtered reference GTF used for alignment
- `-resume` — Nextflow resume is always enabled

Output directory: `<dir>/results_hisat2/`
- `hisat2/*.umi_dedup.sorted.bam` — deduplicated, sorted alignments
- `genome/<genome>.filtered.gtf` — reference GTF filtered to sequences present in the FASTA

### Stage 2 — De Novo Assembly (`main.nf: STRINGTIE_DENOVO`)

Runs **StringTie 3.0.0** on each BAM independently inside a container.

Key design choice: StringTie is run **without `-G`** (no reference guide), so transcripts are assembled purely from the read evidence. This maximises discovery of novel transcripts and isoforms.

Parameters used:
- `-p 12` — 12 threads
- `-m 50` — minimum isoform read coverage of 50
- `--rf` — reverse-forward strand orientation

After per-sample assembly, a preliminary merge is run with `stringtie --merge` guided by the reference GTF to produce `merged_transcriptome.gtf`.

Output directory: `<dir>/stringtie/`
- `<sample>_transcriptome.gtf` — one GTF per sample

### Stage 3 — GTF Merge (`main.nf: STRINGTIE_MERGE`, `scripts/stringtie_merge.sh`)

Runs **StringTie 3.0.0 --merge** to consolidate all per-sample GTFs into a single transcriptome annotation, guided by the reference GTF.

Using the reference as a guide (`-G reference.gtf`) ensures that known transcripts are retained with their original identifiers while novel transcripts are added alongside them.

Output: `<dir>/stringtie/gencode_merged_transcriptome.gtf`

### Stage 4 — Quantification (`scripts/run_pipeline_denovo_transcriptome.sh`)

Runs **nf-core/rnaseq v3.22.0** with Salmon pseudo-alignment against the assembled transcriptome.

Key parameters:
- `--skip_alignment` — no HISAT2 in this stage
- `--pseudo_aligner salmon` — Salmon builds an index from the merged GTF + genome FASTA
- Same UMI and trimming settings as Stage 1

Output directory: `<dir>/results_denovoTranscriptome/`
- `salmon/` — per-sample TPM tables, count matrices, and Salmon index

---

## Requirements

- **Nextflow** (tested with nf-core/rnaseq v3.22.0)
- **Podman** (or Docker) — used by nf-core/rnaseq stages; StringTie stages use a named container image
- **StringTie container**: `stringtie:3.0.0--h29c0135_0`
- Sufficient disk space for intermediate BAMs (~2–3× raw data size)

---

## Input Files

### Samplesheet (CSV)

```csv
sample,fastq_1,fastq_2,strandedness
mock,raw_data/mock_R1.fastq.gz,raw_data/mock_R2.fastq.gz,reverse
infect,raw_data/infect_R1.fastq.gz,raw_data/infect_R2.fastq.gz,reverse
```

Fields:
- `sample` — sample name (used for output file naming)
- `fastq_1` / `fastq_2` — paths to paired-end FASTQ files (can be relative to working directory)
- `strandedness` — library strandedness (`reverse`, `forward`, or `unstranded`)

### Reference Files

- **Genome FASTA** — the reference genome sequence
- **Genome GTF** — reference gene annotation (e.g., GENCODE or Ensembl GTF)

---

## Running the Pipeline

### Basic usage

```bash
nextflow run main.nf \
  --samplesheet samplesheet.csv \
  --fasta /path/to/genome.fa \
  --gtf /path/to/annotation.gtf \
  --dir /path/to/output
```

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `--samplesheet` | Yes | Path to CSV samplesheet |
| `--fasta` | Yes | Path to reference genome FASTA |
| `--gtf` | Yes | Path to reference genome GTF |
| `--dir` | No | Output directory (defaults to current working directory) |

### Resuming a run

All nf-core/rnaseq invocations include `-resume`. To resume the outer Nextflow pipeline after a failure:

```bash
nextflow run main.nf \
  --samplesheet samplesheet.csv \
  --fasta /path/to/genome.fa \
  --gtf /path/to/annotation.gtf \
  --dir /path/to/output \
  -resume
```

---

## Output Structure

```
<dir>/
├── results_hisat2/               # Stage 1 outputs
│   ├── hisat2/
│   │   └── *.umi_dedup.sorted.bam
│   └── genome/
│       └── <genome>.filtered.gtf
├── stringtie/                    # Stages 2 & 3 outputs
│   ├── <sample>_transcriptome.gtf   # per-sample de novo assemblies
│   ├── merged_transcriptome.gtf     # preliminary merge (Stage 2)
│   ├── reference.gtf                # copy of reference used for merge
│   └── gencode_merged_transcriptome.gtf  # final assembled transcriptome
├── results_denovoTranscriptome/  # Stage 4 outputs
│   └── salmon/
│       └── <sample>/             # per-sample Salmon quantification
└── nextflow_outputs/             # Nextflow process manifests
    ├── rnaseq/
    ├── stringtie_denovo/
    ├── stringtie_merge/
    └── run_pipeline_denovo/
```

---

## Utility Scripts (`bin/`)

Python helper scripts used for reference file preparation:

| Script | Purpose |
|--------|---------|
| `filter_gtf.py` | Removes GTF entries for sequences not present in the FASTA |
| `fix_gene_type.py` | Converts `gene_biotype`/`transcript_biotype` to `gene_type`/`transcript_type` |
| `fix_gtf_chr.py` | Prepends `chr` to numeric chromosome names (e.g. `1` → `chr1`) |
| `get_genes.py` | Extracts only gene-level features from a GTF |
| `reformat_fasta.py` | Reformats FASTA to 61 bp per line |
| `use_ref_id.py` | Replaces `gene_id` with `ref_gene_id` when both attributes are present |

These are useful when the reference genome uses non-standard chromosome naming conventions or attribute fields that differ from GENCODE/Ensembl defaults.

---

## Configuration (`nextflow.config`)

```groovy
process {
  executor = 'local'
  cpus = 2
  memory = '4 GB'
}
workDir = './work'
```

The outer Nextflow pipeline runs locally. The nf-core/rnaseq sub-pipelines (Stages 1 and 4) have their own internal resource configuration managed by nf-core profiles. To run on a cluster, update `executor` to your scheduler (e.g. `slurm`, `sge`) and adjust `cpus`/`memory` accordingly.

---

## Notes

- **Nested Nextflow**: Stages 1 and 4 invoke `nextflow run nf-core/rnaseq` as subprocesses. This is supported but means you will see two layers of Nextflow logs.
- **Strandedness**: Both samples in the example samplesheet use `reverse` stranded libraries. StringTie is run with `--rf` accordingly.
- **UMI design**: The 12 bp UMI (`NNNNNNNNNNNN`) is expected to be part of the read structure. Ensure your library was prepared with compatible UMI chemistry.
- **Novel transcript IDs**: Transcripts assembled by StringTie that do not match the reference are assigned IDs in the form `MSTRG.<n>.<n>`. Reference-matching transcripts retain their original IDs.
