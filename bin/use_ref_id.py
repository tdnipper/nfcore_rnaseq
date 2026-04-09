#!/usr/bin/env python3
"""Replace gene_id with ref_gene_id in a StringTie-merged GTF.

After StringTie merge with -G, transcripts matching reference genes get a
ref_gene_id attribute. This script copies ref_gene_id into gene_id so that
known transcripts retain their original identifiers (e.g. ENSG IDs) in
downstream quantification.

Uses regex-based GTF attribute parsing to handle edge cases robustly.
"""

import gzip as gz
import re
import sys

# Match GTF attribute pairs: key "value"
ATTR_PATTERN = re.compile(r'(\w+)\s+"([^"]*)"')


def replace_gene_id_with_ref_gene_id(gtf_file, output_file):
    open_func = gz.open if gtf_file.endswith('.gz') else open
    write_func = gz.open if output_file.endswith('.gz') else open

    with open_func(gtf_file, 'rt') as infile, write_func(output_file, 'wt') as outfile:
        for line in infile:
            if line.startswith('#'):
                outfile.write(line)
                continue

            fields = line.strip().split('\t')
            if len(fields) < 9:
                outfile.write(line)
                continue

            attributes = fields[8]
            attr_pairs = ATTR_PATTERN.findall(attributes)
            attr_dict = {key: value for key, value in attr_pairs}

            if 'gene_id' in attr_dict and 'ref_gene_id' in attr_dict:
                ref_id = attr_dict['ref_gene_id']
                # Replace gene_id value in-place to preserve original attribute order
                attributes = re.sub(
                    r'(gene_id\s+")[^"]*(")',
                    rf'\g<1>{ref_id}\g<2>',
                    attributes,
                    count=1,
                )
                fields[8] = attributes

            outfile.write('\t'.join(fields) + '\n')


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: use_ref_id.py <input_gtf> <output_gtf>")
        sys.exit(1)

    replace_gene_id_with_ref_gene_id(sys.argv[1], sys.argv[2])
