import gzip as gz
import sys

# Fix GTF files by replacing 'gene_biotype' with 'gene_type' and 'transcript_biotype' with 'transcript_type'
# in the attributes field (9th column) of GTF files.
# Used with custom wsn and FLUC GTF to match gencode after cat

def copy_biotype_to_type(gtf_file, output_file):
    # Use gzip.open for both .gz and non-gz files
    open_func = gz.open if gtf_file.endswith('.gz') else open
    write_func = gz.open if output_file.endswith('.gz') else open

    with open_func(gtf_file, 'rt') as infile, write_func(output_file, 'wt') as outfile:
        for line in infile:
            if line.startswith('#'):  # Skip header lines
                outfile.write(line)
                continue
            
            fields = line.strip().split('\t')
            if len(fields) < 9:  # Don't edit lines that don't have enough fields
                outfile.write(line)
                continue
            
            # Extract the attributes field (9th column)
            # and split it into key-value pairs
            attributes = fields[8]
            attr_dict = {}
            for attr in attributes.split(';'):
                if attr.strip():
                    key, value = attr.strip().split(' ', 1)
                    attr_dict[key] = value.strip('"')
            
            # Replace 'gene_id' with 'ref_gene_id' if both exist
            if 'gene_biotype' in attr_dict:
                attr_dict['gene_type'] = attr_dict['gene_biotype']
            if 'transcript_biotype' in attr_dict:
                attr_dict['transcript_type'] = attr_dict['transcript_biotype']
            
            # Reassemble the attributes and write the line
            updated_attributes = '; '.join(f'{key} "{value}"' for key, value in attr_dict.items()) + ';'
            fields[8] = updated_attributes
            outfile.write('\t'.join(fields) + '\n')

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python replace_gene_id_with_ref_gene_id.py <input_gtf_file> <output_gtf_file>")
        sys.exit(1)
    
    input_gtf = sys.argv[1]
    output_gtf = sys.argv[2]
    copy_biotype_to_type(input_gtf, output_gtf)