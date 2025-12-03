Nextflow wrapper

This repository contains a simple Nextflow wrapper `main.nf` that runs the existing helper scripts in sequence:

1. `scripts/run_pipeline.sh`
2. `scripts/stringtie_denovo.sh`
3. `scripts/stringtie_merge.sh`
4. `scripts/run_pipeline_denovo_transcriptome.sh`

Usage

Run the workflow with Nextflow (Nextflow must be installed on your system):

```bash
nextflow run main.nf --samplesheet <path_to_samplesheet> --fasta <path_to_fasta> --gtf <path_to_gtf> [--dir <project_dir>]
```

Notes and caveats

- `run_pipeline.sh` itself invokes `nextflow run nf-core/rnaseq` and many scripts use `podman`. This wrapper will therefore invoke nested Nextflow and container commands — which is allowed but can be harder to debug. If you prefer, consider running nf-core/rnaseq directly or refactoring to call core tasks inside this Nextflow pipeline instead of nesting.

- The scripts must be executable and present at the relative paths used in the wrapper (e.g. `scripts/run_pipeline.sh`).

- The wrapper uses `bash` to invoke the scripts and preserves the script behavior (including their internal `podman` usage and volume mounts). Make sure required tools (Nextflow, Podman, etc.) are installed on the host.

Troubleshooting

- If a script expects certain directories to exist or creates files under `--dir`, ensure you pass a `--dir` value where the pipeline has write access.
- If you want Nextflow to manage containers directly (instead of scripts calling `podman`), refactor the script commands into Nextflow `process` blocks and add `container` directives.
