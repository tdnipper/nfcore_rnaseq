podman run --rm -it \
    -v ./stringtie:/stringtie/ \
    -v ./genomes:/genomes/ \
    -v ./results_hisat2/:/results_hisat2/ \
    quay.io/biocontainers/gffcompare:0.12.6--h9948957_4 \
    bash -c " 
        cp /results_hisat2/genome/hybrid_gencode_fixed.filtered.gtf hybrid_gencode_fixed.gtf && \
        gunzip -c /stringtie/stringtie_transcriptome.filtered.gtf.gz -c > stringtie_transcriptome.filtered.gtf && \
        gffcompare -V -r hybrid_gencode_fixed.gtf \
        -o /stringtie/upstream_merge \
        /results_hisat2/hisat2/stringtie/*.gtf
    "