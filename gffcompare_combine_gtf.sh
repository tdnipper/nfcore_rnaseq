podman run --rm -it \
    -v ./stringtie:/stringtie/ \
    -v ./genomes:/genomes/ \
    -v ./results_hisat2/:/results_hisat2/ \
    quay.io/biocontainers/gffcompare:0.12.6--h9948957_4 \
    bash -c " 
        cp /results_hisat2/genome/hybrid_gencode_fixed.filtered.gtf hybrid_gencode_fixed.filtered.gtf && \
        gffcompare -V -r hybrid_gencode_fixed.filtered.gtf \
        -o /stringtie/compare \
        /stringtie/stringtie_merged_transcriptome.gtf 
    "