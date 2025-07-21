podman run --rm -it \
    -v ./genomes/:/genomes/ \
    -v ./bbsplit/:/out/ \
    -v ./raw_data/:/raw_data/ \
    bbmap:39.19--he5f24ec_0 bash /out/run_bbsplit.sh