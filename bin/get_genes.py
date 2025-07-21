import gzip as gz
import sys

def write_gene_lines(gtf_file, output_file):
    """
    Write gene lines from a GTF file to an output file.
    """
    # Use gzip.open for both .gz and non-gz files
    open_func = gz.open if gtf_file.endswith('.gz') else open
    write_func = gz.open if output_file.endswith('.gz') else open

    with open_func(gtf_file, 'rt') as infile, write_func(output_file, 'wt') as outfile:
        for line in infile:
            if line.startswith('#'):  # Skip header lines
                continue
            
            fields = line.strip().split('\t')
            if len(fields) < 9:  # Don't edit lines that don't have enough fields
                continue
            
            # Check if the feature type is "gene"
            if fields[2] == "gene":
                outfile.write(line)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python get_genes.py <input_gtf_file> <output_gtf_file>")
        sys.exit(1)
    
    input_gtf = sys.argv[1]
    output_gtf = sys.argv[2]
    write_gene_lines(input_gtf, output_gtf)