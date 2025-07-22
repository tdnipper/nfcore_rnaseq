# Check if the bbsplit/trimmed directory exists, and create it if not
if [ ! -d "./bbsplit/trimmed" ]; then
    mkdir -p ./bbsplit/trimmed
fi

# Trim reads before running bbsplit
podman run --rm -it \
    -v ./genomes/:/genomes/ \
    -v ./raw_data/:/raw_data/ \
    -v ./bbsplit/:/out/ \
    -v ./bbsplit/trimmed/:/trimmed/ \
    fastp:0.23.4--h5f740d0_0 bash /out/trim_reads.sh

# Run bbsplit to split reads
podman run --rm -it \
    -v ./genomes/:/genomes/ \
    -v ./bbsplit/:/out/ \
    -v ./bbsplit/trimmed/:/trimmed/ \
    bbmap:39.19--he5f24ec_0 bash /out/run_bbsplit.sh