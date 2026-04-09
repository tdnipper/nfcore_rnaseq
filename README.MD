# De Novo Transcriptome Assembly Pipeline

A Nextflow DSL2 pipeline for reference-guided de novo transcriptome assembly and quantification from paired-end RNA-seq data. The pipeline discovers novel transcripts and isoforms absent from the reference annotation, then quantifies them across experimental conditions.

---

## Overview

The pipeline runs as a single Nextflow DSL2 workflow, leveraging nf-core modules and subworkflows:

```bash
Raw FASTQ (paired-end, UMI-tagged)
        │
        ▼
  QC & Preprocessing
  │  FastQC (raw) → UMI extract → fastp trimming → FastQC (trimmed)
  │  FQ_LINT validation, strandedness inference
  │
  ▼
  Genome Alignment
  │  HISAT2 build (with splice sites) → HISAT2 align (--dta)
  │  SAMTOOLS sort/index → UMI deduplication
  │
  ▼
  De Novo Assembly
  │  StringTie per-sample in nascent mode (--nasc, no -G) → StringTie merge (with -G)
  │  fix_ref_id (replace gene_id with ref_gene_id)
  │
  ▼
  Quantification
  │  GFFREAD → Salmon index → Salmon quant
  │  tx2gene → tximeta (gene & transcript count matrices)
  │
  ▼
  MultiQC Report
```

---

## Pipeline Steps

| Step | Process                                  | Description                                                     |
| ---- | ---------------------------------------- | --------------------------------------------------------------- |
| 0    | GUNZIP_FASTA / GUNZIP_GTF                | Decompress reference inputs if gzipped                          |
| 1    | GFFREAD_REF                              | Extract reference transcript FASTA (for strandedness inference) |
| 2    | FASTQ_QC_TRIM_FILTER_SETSTRANDEDNESS     | FastQC, UMI extract, fastp, FQ_LINT, strandedness inference     |
| 3    | HISAT2_EXTRACTSPLICESITES + HISAT2_BUILD | Build HISAT2 index with splice site awareness                   |
| 4    | FASTQ_ALIGN_HISAT2                       | Align reads with `--dta`, sort and index BAMs                   |
| 5    | BAM_DEDUP_STATS_SAMTOOLS_UMITOOLS        | UMI-based deduplication                                         |
| 6    | STRINGTIE_DENOVO                         | Per-sample de novo assembly (no reference guide)                |
| 7    | STRINGTIE_MERGE                          | Merge all per-sample GTFs, anchored to reference annotation     |
| 8    | FIX_REF_ID                               | Replace `gene_id` with `ref_gene_id` in merged GTF              |
| 9    | GFFREAD_DENOVO                           | Extract de novo transcript FASTA from merged GTF                |
| 10   | SALMON_INDEX                             | Build Salmon index from de novo transcripts                     |
| 11   | QUANTIFY_PSEUDO_ALIGNMENT                | Salmon quant, tx2gene, tximeta count matrices                   |
| 12   | MULTIQC                                  | Aggregate QC report                                             |

---

## Pipeline Design

### De Novo Assembly Strategy

StringTie is run **without `-G`** (no reference guide) on each sample independently. This maximises discovery of novel transcripts and isoforms by assembling purely from read evidence. The per-sample GTFs are then merged with `stringtie --merge -G reference.gtf` to consolidate transcripts while retaining known gene identifiers.

After merging, `use_ref_id.py` replaces `gene_id` with `ref_gene_id` so that known transcripts retain their original identifiers (e.g., ENSG IDs) in downstream quantification.

### Strandedness Inference

When `strandedness` is set in the samplesheet (e.g., `reverse`), that value is used directly. When set to `auto`, the pipeline builds a temporary Salmon index from the reference transcripts and infers strandedness from a subsample of reads.

---

## Requirements

- **Nextflow** ≥ 22.10.0 (DSL2)
- **Podman** — configured as the container runtime (`podman.enabled = true`)
- Sufficient disk space for intermediate BAMs (~2–3× raw data size)

All software dependencies are handled via containers (pulled from `quay.io/biocontainers/`).

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
- `strandedness` — library strandedness (`reverse`, `forward`, `unstranded`, or `auto`)

### Reference Files

- **Genome FASTA** — reference genome sequence (`.fa` or `.fa.gz`)
- **Genome GTF** — reference gene annotation (`.gtf` or `.gtf.gz`)

---

## Running the Pipeline

### Basic usage

```bash
nextflow run tdnipper/nfcore_rnaseq \
  -r $VERSION \
  --input samplesheet.csv \
  --fasta /path/to/genome.fa.gz \
  --gtf /path/to/annotation.gtf.gz \
  --outdir results
```

### Parameters

| Parameter                | Required | Default        | Description                                  |
| ------------------------ | -------- | -------------- | -------------------------------------------- |
| `--input`                | Yes      | —              | Path to CSV samplesheet                      |
| `--fasta`                | Yes      | —              | Path to reference genome FASTA               |
| `--gtf`                  | Yes      | —              | Path to reference genome GTF                 |
| `--outdir`               | No       | `./results`    | Output directory                             |
| `--hisat2_index`         | No       | —              | Pre-built HISAT2 index (skips HISAT2_BUILD)  |
| `--with_umi`             | No       | `true`         | Enable UMI extraction and deduplication      |
| `--umitools_bc_pattern`  | No       | `NNNNNNNNNNNN` | UMI barcode pattern (12 bp)                  |
| `--stringtie_min_length` | No       | `50`           | Minimum assembled transcript length (bp). Applied to both per-sample de novo assembly and merge. |
| `--stringtie_min_tpm`    | No       | `1`            | Minimum TPM for StringTie merge. Transcripts below this threshold are excluded from the merged assembly. Lower for maximum sensitivity. |
| `--skip_fastqc`          | No       | `false`        | Skip FastQC steps                            |
| `--skip_multiqc`         | No       | `false`        | Skip MultiQC report                          |
| `--max_memory`           | No       | `202 GB`       | Maximum available RAM                        |
| `--max_cpus`             | No       | `16`           | Maximum available CPU cores                  |
| `--max_time`             | No       | `48 h`         | Maximum wall time per process                |

See `nextflow.config` for the full list of configurable parameters.

### Resuming a run

```bash
nextflow run tdnipper/nfcore_rnaseq \
  -r $VERSION \
  --input samplesheet.csv \
  --fasta /path/to/genome.fa.gz \
  --gtf /path/to/annotation.gtf.gz \
  --outdir results \
  -resume
```

---

## Output Structure

```text
results/
├── fastqc/
│   ├── raw/                        # FastQC on raw reads
│   └── trim/                       # FastQC on trimmed reads
├── trimming/                       # fastp trimmed reads and reports
├── alignment/
│   ├── hisat2/                     # HISAT2 alignment logs
│   ├── samtools/                   # Sorted BAMs, indices, and stats
│   │   └── stats/
│   └── dedup/                      # UMI-deduplicated BAMs and stats
│       └── stats/
├── stringtie/
│   ├── denovo/                     # Per-sample de novo GTFs
│   └── merge/                      # Merged GTF + fixed ref_id GTF
├── salmon/
│   ├── quant/                      # Per-sample Salmon quantification
│   ├── tximeta/                    # Gene and transcript count matrices
│   └── se/                         # SummarizedExperiment objects
├── multiqc/                        # Aggregated QC report
└── pipeline_info/                  # Nextflow timeline, report, trace, DAG
```

---

## Project Structure

```text
.
├── main.nf                         # Pipeline entry point
├── nextflow.config                 # All parameters and process configuration
├── workflows/
│   └── denovo_rnaseq.nf            # Main workflow (13 steps)
├── modules/
│   ├── nf-core/                    # nf-core community modules
│   └── local/                      # Custom local modules
│       ├── stringtie_denovo/       # Per-sample de novo assembly (no -G)
│       ├── stringtie_merge/        # Merge with reference GTF
│       └── fix_ref_id/             # Replace gene_id with ref_gene_id
├── subworkflows/
│   └── nf-core/                    # nf-core subworkflows
│       ├── fastq_qc_trim_filter_setstrandedness/
│       ├── fastq_align_hisat2/
│       ├── bam_dedup_stats_samtools_umitools/
│       └── quantify_pseudo_alignment/
└── bin/
    └── use_ref_id.py               # Python script: ref_gene_id replacement
```

---

## Utility Scripts (`bin/`)

Python helper scripts for reference file preparation:

| Script             | Purpose                                                                                            |
| ------------------ | -------------------------------------------------------------------------------------------------- |
| `use_ref_id.py`    | Replaces `gene_id` with `ref_gene_id` when both attributes are present (used by FIX_REF_ID process)|
| `filter_gtf.py`    | Removes GTF entries for sequences not present in the FASTA                                         |
| `fix_gene_type.py` | Converts `gene_biotype`/`transcript_biotype` to `gene_type`/`transcript_type`                      |
| `fix_gtf_chr.py`   | Prepends `chr` to numeric chromosome names (e.g. `1` → `chr1`)                                     |
| `get_genes.py`     | Extracts only gene-level features from a GTF                                                       |
| `reformat_fasta.py`| Reformats FASTA to 61 bp per line                                                                  |

---

## Configuration

The pipeline is configured via `nextflow.config`. Key settings:

- **Container runtime**: Podman with `quay.io` registry (resolves `biocontainers/` prefixes)
- **Resource labels**: `process_single`, `process_low`, `process_medium`, `process_high`, `process_high_memory` — all capped by `max_memory` and `max_cpus`
- **publishDir**: Results are published via symlink by default (`publish_dir_mode = 'symlink'`)
- **Execution reports**: Timeline, trace, report, and DAG are generated in `<outdir>/pipeline_info/`

---

## Notes

- **UMI design**: The 12 bp UMI (`NNNNNNNNNNNN`) is expected to be part of the read structure. Ensure your library was prepared with compatible UMI chemistry.
- **Novel transcript IDs**: Transcripts assembled by StringTie that do not match the reference are assigned IDs in the form `MSTRG.<n>.<n>`. Reference-matching transcripts retain their original IDs after `fix_ref_id` processing.
- **HISAT2 index build**: When available memory exceeds `hisat2_build_memory` (default 200 GB), splice sites and exons are incorporated into the index for improved alignment sensitivity.
