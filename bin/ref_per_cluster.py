#!/usr/bin/env python3
"""
Extract a single FASTA read at the 90th percentile length from a FASTQ(.gz).

Nearest-rank percentile:
    For n reads and percentile p (default 90),
    k = ceil(p/100 * n); the percentile value is the kth value in the
    sorted list of lengths (1-based). This value is guaranteed to be
    an observed length.

Usage:
    python fastq_90th_to_fasta.py input.fastq.gz -o output.fasta
    # Optional: choose a different percentile
    python fastq_90th_to_fasta.py input.fastq.gz -o output.fasta -p 90

Notes:
  - Two-pass approach:
      Pass 1: read lengths only
      Pass 2: emit first read whose length equals the percentile length
  - Supports .gz compressed FASTQ; will also read plain .fastq if provided.
"""

import argparse
import gzip
import math
import os
import sys

def open_maybe_gzip(path, mode="rt"):
    """
    Open a file which may be gzip-compressed based on extension.
    mode: 'rt' for text read, 'rb' for binary, etc.
    """
    if path.endswith(".gz"):
        return gzip.open(path, mode)
    return open(path, mode)

def iter_fastq_records(fh):
    """
    Iterate FASTQ records assuming 4-line format:
      @header
      sequence
      +
      quality

    Yields (header_line, sequence, quality_line).
    Minimal validation included.
    """
    line_num = 0
    while True:
        header = fh.readline()
        if not header:  # EOF
            break
        line_num += 1

        seq = fh.readline()
        plus = fh.readline()
        qual = fh.readline()
        line_num += 3

        if not seq or not plus or not qual:
            raise ValueError(f"Unexpected EOF; incomplete FASTQ record near line {line_num}")

        header = header.rstrip("\n")
        seq = seq.rstrip("\n")
        plus = plus.rstrip("\n")
        qual = qual.rstrip("\n")

        if not header.startswith("@"):
            # Some tools may insert spaces; still check basic format
            raise ValueError(f"FASTQ header does not start with '@' near line {line_num-3}: {header}")

        if not plus.startswith("+"):
            raise ValueError(f"FASTQ '+' line malformed near line {line_num-1}: {plus}")

        if len(seq) != len(qual):
            # Strict check; many pipelines rely on this being equal
            raise ValueError(
                f"Sequence and quality length mismatch near line {line_num-3}: "
                f"len(seq)={len(seq)} len(qual)={len(qual)}"
            )

        yield header, seq, qual

def compute_nearest_rank_percentile_length(in_path, percentile=90):
    """
    First pass: collect all read lengths and compute nearest-rank percentile length.
    Returns the target length (an observed read length).
    """
    lengths = []
    with open_maybe_gzip(in_path, "rt") as fh:
        for _, seq, _ in iter_fastq_records(fh):
            lengths.append(len(seq))

    n = len(lengths)
    if n == 0:
        raise ValueError("Input FASTQ contains zero reads.")

    lengths.sort()
    k = math.ceil((percentile / 100.0) * n)  # 1-based rank
    idx = k - 1                             # convert to 0-based index
    target_len = lengths[idx]
    return target_len, n

def write_first_read_with_length(in_path, out_path, target_len):
    """
    Second pass: find the first read whose length equals target_len
    and write it to FASTA. Header is derived from FASTQ header.
    """
    with open_maybe_gzip(in_path, "rt") as fh, open(out_path, "wt") as out_fh:
        for header, seq, _ in iter_fastq_records(fh):
            if len(seq) == target_len:
                # Convert FASTQ header to FASTA header
                fasta_header = header.lstrip("@").strip()
                out_fh.write(f">{fasta_header}\n")
                out_fh.write(seq.strip() + "\n")
                return True
    return False

def main():
    parser = argparse.ArgumentParser(
        description="Output a FASTA with a single read whose length is the nearest-rank percentile (default 90th) of lengths in a FASTQ(.gz)"
    )
    parser.add_argument("input", help="Input FASTQ file (can be .gz)")
    parser.add_argument("-o", "--output", help="Output FASTA file; default: input basename + '.fa'")
    parser.add_argument("-p", "--percentile", type=float, default=90.0,
                        help="Percentile to use (default: 90). Must be in (0,100].")
    args = parser.parse_args()

    if not (0 < args.percentile <= 100):
        print("Error: --percentile must be > 0 and <= 100", file=sys.stderr)
        sys.exit(2)

    in_path = args.input
    if not os.path.exists(in_path):
        print(f"Error: input file not found: {in_path}", file=sys.stderr)
        sys.exit(2)

    out_path = args.output
    if not out_path:
        base = os.path.basename(in_path)
        # Strip common fastq extensions
        for ext in (".fastq.gz", ".fq.gz", ".fastq", ".fq"):
            if base.endswith(ext):
                base = base[: -len(ext)]
                break
        out_path = base + ".fa"

    try:
        target_len, n_reads = compute_nearest_rank_percentile_length(in_path, percentile=args.percentile)
        found = write_first_read_with_length(in_path, out_path, target_len)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    if not found:
        # Should not happen with nearest-rank, but guard just in case
        print(
            f"Warning: did not find a read with length {target_len} in second pass. "
            f"This is unexpected. No output written.",
            file=sys.stderr
        )
        sys.exit(3)

    print(f"Percentile {args.percentile}% length: {target_len} (from {n_reads} reads)")
    print(f"Wrote 1 FASTA read to: {out_path}")

if __name__ == "__main__":
    main()