import sys
def reformat_fasta(input_file, output_file, line_length=61):
    """
    Reformats a FASTA file so that each line of the sequence is of a specified length.

    Args:
        input_file (str): Path to the input FASTA file.
        output_file (str): Path to the output FASTA file.
        line_length (int): Desired line length for the sequence.
    """
    with open(input_file, 'r') as infile, open(output_file, 'w') as outfile:
        sequence = ""
        for line in infile:
            if line.startswith(">"):
                # If there's a sequence accumulated, write it to the file
                if sequence:
                    for i in range(0, len(sequence), line_length):
                        outfile.write(sequence[i:i + line_length] + '\n')
                    sequence = ""  # Reset sequence for the next entry
                # Write the header line
                outfile.write(line)
            else:
                # Accumulate sequence lines
                sequence += line.strip()
        
        # Write the last sequence if any
        if sequence:
            for i in range(0, len(sequence), line_length):
                outfile.write(sequence[i:i + line_length] + '\n')


# Example usage
input_fasta = sys.argv[1]
output_fasta = sys.argv[2]
reformat_fasta(input_fasta, output_fasta)