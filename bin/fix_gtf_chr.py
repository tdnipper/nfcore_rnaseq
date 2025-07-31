import sys

def fix_gtf_column(input_file, output_file):
    with open(input_file, 'r') as infile, open(output_file, 'w') as outfile:
        for line in infile:
            if line.startswith("#"):
                # Write header lines as-is
                outfile.write(line)
                continue
            
            fields = line.strip().split('\t')
            if fields[0].isdigit():
                fields[0] = f"chr{fields[0]}"
            
            outfile.write('\t'.join(fields) + '\n')

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python fix_gtf_column.py <input_file> <output_file>")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    fix_gtf_column(input_file, output_file)