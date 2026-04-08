/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    De novo transcriptome assembly and quantification workflow
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Steps:
        1. GUNZIP reference inputs (if compressed)
        2. GFFREAD reference GTF → reference transcript FASTA (for strandedness inference)
        3. FASTQ_QC_TRIM_FILTER_SETSTRANDEDNESS
               FastQC → UMI extract → fastp → FastQC → strandedness inference
               FQ_LINT on raw and trimmed reads (paired-end, if !skip_fq_lint)
        4. HISAT2_EXTRACTSPLICESITES + HISAT2_BUILD (or use provided index)
        5. FASTQ_ALIGN_HISAT2
        6. BAM_DEDUP_STATS_SAMTOOLS_UMITOOLS
        7. STRINGTIE_DENOVO (per sample, no -G)
        8. STRINGTIE_MERGE (all samples + reference GTF)
        9. FIX_REF_ID (replace gene_id with ref_gene_id)
       10. GFFREAD de novo GTF → de novo transcript FASTA
       11. SALMON_INDEX
       12. QUANTIFY_PSEUDO_ALIGNMENT (Salmon quant → tx2gene → tximeta)
       13. MULTIQC
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { GUNZIP as GUNZIP_FASTA       } from '../modules/nf-core/gunzip/main'
include { GUNZIP as GUNZIP_GTF         } from '../modules/nf-core/gunzip/main'
include { GFFREAD as GFFREAD_REF       } from '../modules/nf-core/gffread/main'
include { GFFREAD as GFFREAD_DENOVO    } from '../modules/nf-core/gffread/main'
include { HISAT2_EXTRACTSPLICESITES    } from '../modules/nf-core/hisat2/extractsplicesites/main'
include { HISAT2_BUILD                 } from '../modules/nf-core/hisat2/build/main'
include { SALMON_INDEX                 } from '../modules/nf-core/salmon/index/main'
include { MULTIQC                      } from '../modules/nf-core/multiqc/main'

include { STRINGTIE_DENOVO             } from '../modules/local/stringtie_denovo/main'
include { STRINGTIE_MERGE              } from '../modules/local/stringtie_merge/main'
include { FIX_REF_ID                   } from '../modules/local/fix_ref_id/main'

include { FASTQ_QC_TRIM_FILTER_SETSTRANDEDNESS } from '../subworkflows/nf-core/fastq_qc_trim_filter_setstrandedness/main'
include { FASTQ_ALIGN_HISAT2                   } from '../subworkflows/nf-core/fastq_align_hisat2/main'
include { BAM_DEDUP_STATS_SAMTOOLS_UMITOOLS    } from '../subworkflows/nf-core/bam_dedup_stats_samtools_umitools/main'
include { QUANTIFY_PSEUDO_ALIGNMENT            } from '../subworkflows/nf-core/quantify_pseudo_alignment/main'

workflow DENOVO_RNASEQ {

    take:
    ch_reads     // channel: [ val(meta), [ reads ] ]
    ch_samplesheet // path to samplesheet CSV for SE colData

    main:

    ch_versions      = Channel.empty()
    ch_multiqc_files = Channel.empty()

    /*
    ============================================================
        STEP 0: Prepare reference genome inputs
    ============================================================
    */

    // Decompress FASTA if gzipped
    if (params.fasta.endsWith('.gz')) {
        GUNZIP_FASTA ( Channel.value([ [id:'genome_fasta'], file(params.fasta) ]) )
        ch_fasta      = GUNZIP_FASTA.out.gunzip.map { meta, f -> f }
        ch_versions   = ch_versions.mix(GUNZIP_FASTA.out.versions)
    } else {
        ch_fasta      = Channel.value(file(params.fasta))
    }

    // Decompress GTF if gzipped
    if (params.gtf.endsWith('.gz')) {
        GUNZIP_GTF ( Channel.value([ [id:'genome_gtf'], file(params.gtf) ]) )
        ch_gtf      = GUNZIP_GTF.out.gunzip.map { meta, f -> f }
        ch_versions = ch_versions.mix(GUNZIP_GTF.out.versions)
    } else {
        ch_gtf = Channel.value(file(params.gtf))
    }

    // Create meta-wrapped channels for modules that require tuple input
    ch_fasta_meta = ch_fasta.map { f -> [ [id: f.simpleName], f ] }
    ch_gtf_meta   = ch_gtf.map  { f -> [ [id: f.simpleName], f ] }

    /*
    ============================================================
        STEP 1: Reference transcript FASTA (for strandedness inference)
    ============================================================
    */

    GFFREAD_REF ( ch_gtf_meta, ch_fasta )
    ch_transcript_fasta_ref = GFFREAD_REF.out.gffread_fasta.map { meta, f -> f }
    ch_versions = ch_versions.mix(GFFREAD_REF.out.versions)

    /*
    ============================================================
        STEP 2: QC, trimming, and strandedness inference
                FQ_LINT, FastQC, UMI extract, fastp are all handled here
    ============================================================
    */

    FASTQ_QC_TRIM_FILTER_SETSTRANDEDNESS (
        ch_reads,
        ch_fasta,               // genome fasta (path) - used for strandedness inference decoy
        ch_transcript_fasta_ref, // ref transcript fasta (path) - for strandedness salmon index
        ch_gtf,                 // ref GTF (path) - for strandedness salmon quant gene map
        [],                     // ch_salmon_index: empty → subworkflow builds it (make_salmon_index=true)
        [],                     // ch_sortmerna_index: not used
        [],                     // ch_bbsplit_index: not used
        [],                     // ch_rrna_fastas: not used
        true,                   // skip_bbsplit
        params.skip_fastqc,
        false,                  // skip_trimming
        !params.with_umi,       // skip_umi_extract
        true,                   // make_salmon_index: build ref salmon index internally for inference
        false,                  // make_sortmerna_index
        'fastp',                // trimmer
        params.min_trimmed_reads,
        false,                  // save_trimmed
        false,                  // remove_ribo_rna
        params.with_umi,
        params.umi_discard_read,
        params.stranded_threshold,
        params.unstranded_threshold,
        params.skip_fq_lint,    // skip_linting
        false,                  // fastp_merge
    )

    ch_trimmed_reads = FASTQ_QC_TRIM_FILTER_SETSTRANDEDNESS.out.reads
    ch_versions      = ch_versions.mix(FASTQ_QC_TRIM_FILTER_SETSTRANDEDNESS.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(FASTQ_QC_TRIM_FILTER_SETSTRANDEDNESS.out.multiqc_files)

    /*
    ============================================================
        STEP 3: Build HISAT2 index (if not provided)
                EXTRACTSPLICESITES always runs; BUILD uses splice sites
                only when task.memory >= params.hisat2_build_memory
    ============================================================
    */

    // HISAT2_EXTRACTSPLICESITES always runs — HISAT2_BUILD decides internally
    // whether to use splice sites based on available memory vs params.hisat2_build_memory
    HISAT2_EXTRACTSPLICESITES ( ch_gtf_meta )
    ch_splicesites = HISAT2_EXTRACTSPLICESITES.out.txt  // tuple val(meta), path(*.txt)
    ch_versions    = ch_versions.mix(HISAT2_EXTRACTSPLICESITES.out.versions)

    if (params.hisat2_index) {
        ch_hisat2_index = Channel.value([ [id:'hisat2_index'], file(params.hisat2_index) ])
    } else {
        HISAT2_BUILD (
            ch_fasta_meta,
            ch_gtf_meta,
            ch_splicesites
        )
        ch_hisat2_index = HISAT2_BUILD.out.index  // tuple val(meta), path(hisat2/)
        ch_versions     = ch_versions.mix(HISAT2_BUILD.out.versions)
    }

    /*
    ============================================================
        STEP 4: Align with HISAT2 + sort/index BAM
    ============================================================
    */

    FASTQ_ALIGN_HISAT2 (
        ch_trimmed_reads,
        ch_hisat2_index,    // tuple val(meta), path(hisat2/) — HISAT2_ALIGN expects a tuple
        ch_splicesites,     // tuple val(meta), path(*.splice_sites.txt)
        ch_fasta_meta       // tuple val(meta), path(fasta) — BAM_SORT_STATS_SAMTOOLS expects tuple
    )
    ch_versions      = ch_versions.mix(FASTQ_ALIGN_HISAT2.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        FASTQ_ALIGN_HISAT2.out.stats.map    { meta, f -> f },
        FASTQ_ALIGN_HISAT2.out.flagstat.map { meta, f -> f },
        FASTQ_ALIGN_HISAT2.out.idxstats.map { meta, f -> f },
        FASTQ_ALIGN_HISAT2.out.summary.map  { meta, f -> f },
    )

    /*
    ============================================================
        STEP 5: UMI deduplication (only when --with_umi is true)
    ============================================================
    */

    if (params.with_umi) {
        ch_bam_bai = FASTQ_ALIGN_HISAT2.out.bam
            .join(FASTQ_ALIGN_HISAT2.out.bai, by: [0], remainder: true)
            .join(FASTQ_ALIGN_HISAT2.out.csi, by: [0], remainder: true)
            .map { meta, bam, bai, csi ->
                bai ? [ meta, bam, bai ] : [ meta, bam, csi ]
            }

        BAM_DEDUP_STATS_SAMTOOLS_UMITOOLS ( ch_bam_bai, params.umitools_dedup_stats )
        ch_bam_for_assembly = BAM_DEDUP_STATS_SAMTOOLS_UMITOOLS.out.bam
        ch_versions  = ch_versions.mix(BAM_DEDUP_STATS_SAMTOOLS_UMITOOLS.out.versions)
        ch_multiqc_files = ch_multiqc_files.mix(
            BAM_DEDUP_STATS_SAMTOOLS_UMITOOLS.out.deduplog.map { meta, f -> f },
            BAM_DEDUP_STATS_SAMTOOLS_UMITOOLS.out.stats.map    { meta, f -> f },
            BAM_DEDUP_STATS_SAMTOOLS_UMITOOLS.out.flagstat.map { meta, f -> f },
            BAM_DEDUP_STATS_SAMTOOLS_UMITOOLS.out.idxstats.map { meta, f -> f },
        )
    } else {
        ch_bam_for_assembly = FASTQ_ALIGN_HISAT2.out.bam
    }

    /*
    ============================================================
        STEP 6: StringTie de novo assembly (per sample, no -G)
    ============================================================
    */

    STRINGTIE_DENOVO ( ch_bam_for_assembly )
    ch_versions = ch_versions.mix(STRINGTIE_DENOVO.out.versions.first())

    /*
    ============================================================
        STEP 7: StringTie merge (all samples + reference GTF)
    ============================================================
    */

    ch_all_gtfs = STRINGTIE_DENOVO.out.gtf.collect { meta, gtf -> gtf }

    STRINGTIE_MERGE ( ch_all_gtfs, ch_gtf )
    ch_versions = ch_versions.mix(STRINGTIE_MERGE.out.versions)

    /*
    ============================================================
        STEP 8: Replace gene_id with ref_gene_id
    ============================================================
    */

    FIX_REF_ID ( STRINGTIE_MERGE.out.gtf )
    ch_fixed_gtf = FIX_REF_ID.out.gtf
    ch_versions  = ch_versions.mix(FIX_REF_ID.out.versions)

    /*
    ============================================================
        STEP 9: Extract de novo transcript FASTA for Salmon
    ============================================================
    */

    GFFREAD_DENOVO (
        ch_fixed_gtf.map { gtf -> [ [id:'merged_transcriptome_id'], gtf ] },
        ch_fasta
    )
    ch_denovo_fasta = GFFREAD_DENOVO.out.gffread_fasta.map { meta, f -> f }
    ch_versions     = ch_versions.mix(GFFREAD_DENOVO.out.versions)

    /*
    ============================================================
        STEP 10: Build Salmon index from de novo transcript FASTA
    ============================================================
    */

    SALMON_INDEX ( ch_fasta, ch_denovo_fasta )
    ch_versions = ch_versions.mix(SALMON_INDEX.out.versions)

    /*
    ============================================================
        STEP 11: Salmon quantification + tx2gene + tximeta
                 Uses the same trimmed reads — no re-processing
    ============================================================
    */

    QUANTIFY_PSEUDO_ALIGNMENT (
        ch_samplesheet,           // [ val(meta), path(samplesheet) ] for SE colData
        ch_trimmed_reads,         // same trimmed reads from step 2
        SALMON_INDEX.out.index,
        ch_denovo_fasta,
        ch_fixed_gtf,
        'gene_id',
        'gene_name',
        'salmon',
        false,                    // alignment_mode
        params.salmon_quant_libtype ?: '', // '' → module auto-maps from meta.strandedness (ISR/ISF/IU)
        null,                     // kallisto_quant_fraglen
        null,                     // kallisto_quant_fraglen_sd
    )
    ch_versions      = ch_versions.mix(QUANTIFY_PSEUDO_ALIGNMENT.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        QUANTIFY_PSEUDO_ALIGNMENT.out.multiqc.map { meta, f -> f }
    )

    /*
    ============================================================
        STEP 12: MultiQC
    ============================================================
    */

    if (!params.skip_multiqc) {
        MULTIQC (
            ch_multiqc_files.collect(),
            [],  // multiqc_config
            [],  // extra_multiqc_config
            [],  // multiqc_logo
            [],  // replace_names
            [],  // sample_names
        )
    }

    emit:
    multiqc_report = params.skip_multiqc ? Channel.empty() : MULTIQC.out.report
    versions       = ch_versions
}
