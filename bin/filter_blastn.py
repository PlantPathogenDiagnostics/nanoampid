#!/usr/bin/env python3
"""
BLAST filter & report generator

Reads a CSV with columns:
  'Barcode','qseqid','Read Count','query_fasta_file_path','blast_output_file_path'

Reads corresponding BLAST tabular files (outfmt 6-like) with columns:
  'qseqid','pident','slen','qlen','length','qcovs','mismatch','gapopen','evalue','bitscore','salltitles'

Computes % subject coverage:
  %_Ref_Cov = 100 * length / slen

Filters by:
  - minimum % subject coverage
  - minimum % identity (pident)
  - maximum qlen

Generates Excel with two sheets:
  - 'unfiltered': all hits for provided qseqids
  - 'filtered'  : per-qseqid best subject by pident, then dedup per (Barcode, salltitles)
                  preferring highest pident and qlen closest to slen

Output columns:
  'Barcode','qseqid','read_count','salltitles','pident','length','qlen','slen',
  'mismatch','gapopen','evalue','bitscore','%_Ref_Cov','Sequence'

Usage Examples:

# 1) Basic run without read counts
python blast_filter_report_with_counts.py blast_results.csv \
  --min-ref-cov 85 --min-pident 95 --max-qlen 2000 \
  -o my_blast_report.xlsx

# 2) With read counts sheet
python blast_filter_report_with_counts.py blast_results.csv \
  --read-counts read_count_results.csv \
  -o my_blast_with_counts.xls

"""

import argparse
import os
import sys
from typing import Dict, Tuple, Optional
import pandas as pd

# --------------------------- FASTA parsing --------------------------- #

def extract_fasta_id(header_line: str) -> str:
    """
    Extract qseqid from a FASTA header line.
    Assumes header starts with '>' and qseqid is the first whitespace-delimited token (without '>').
    Example: '>Q123 some description' -> 'Q123'
    """
    header_line = header_line.strip()
    if not header_line.startswith(">"):
        raise ValueError(f"FASTA header does not start with '>': {header_line}")
    # Take first token after '>'
    return header_line[1:].split()[0]

def read_fasta_to_dict(fasta_path: str) -> Dict[str, str]:
    """
    Reads a FASTA file and returns a dict mapping qseqid -> sequence.
    Handles multi-line sequences.
    """
    seqs: Dict[str, str] = {}
    if not os.path.exists(fasta_path):
        raise FileNotFoundError(f"FASTA file not found: {fasta_path}")
    current_id = None
    current_chunks = []
    with open(fasta_path, "r") as fh:
        for line in fh:
            if not line:
                continue
            if line.startswith(">"):
                # save previous
                if current_id is not None:
                    seqs[current_id] = "".join(current_chunks)
                current_id = extract_fasta_id(line)
                current_chunks = []
            else:
                current_chunks.append(line.strip())
        # save last
        if current_id is not None:
            seqs[current_id] = "".join(current_chunks)
    return seqs

# --------------------------- BLAST parsing --------------------------- #

BLAST_COLUMNS = [
    'qseqid', 'pident', 'slen', 'qlen', 'length', 'qcovs',
    'mismatch', 'gapopen', 'evalue', 'bitscore', 'salltitles'
]

NUMERIC_COLUMNS = ['pident', 'slen', 'qlen', 'length', 'qcovs',
                   'mismatch', 'gapopen', 'evalue', 'bitscore']

def read_blast_tsv(blast_path: str) -> pd.DataFrame:
    """
    Reads a BLAST tabular file with the expected columns.
    Returns a DataFrame with correct dtypes.
    """
    if not os.path.exists(blast_path):
        raise FileNotFoundError(f"BLAST file not found: {blast_path}")

    df = pd.read_csv(blast_path, sep="\t", header=None, names=BLAST_COLUMNS, dtype=str)
    # Coerce numeric columns
    for col in NUMERIC_COLUMNS:
        # evalue can be in scientific notation; convert to float
        df[col] = pd.to_numeric(df[col], errors='coerce')
    # Drop rows with missing critical values
    df = df.dropna(subset=['qseqid', 'pident', 'slen', 'qlen', 'length', 'bitscore', 'evalue'])
    return df

# --- Reads counts parsing ---

def parse_read_counts(read_counts_csv: str) -> pd.DataFrame:
    """
    Parse a read count CSV that may contain bracketed values and no header.
    Produces columns: 'Barcode','Raw Reads','Filtered Reads'
    """
    # Read raw file without header
    df = pd.read_csv(read_counts_csv, header=None)
    # Strip square brackets if present
    df = df.applymap(lambda x: str(x).strip().strip('[]'))
    df.columns = ['Barcode', 'Raw Reads', 'Filtered Reads']
    # Coerce numeric columns where possible
    for col in ['Raw Reads', 'Filtered Reads']:
        df[col] = pd.to_numeric(df[col], errors='coerce')
    return df

def write_workbook_with_counts(unfiltered_df: pd.DataFrame,
                               filtered_df: pd.DataFrame,
                               read_counts_df: pd.DataFrame,
                               out_xlsx: str) -> None:
    """
    Write the 3-sheet workbook: 'unfiltered', 'filtered', 'read_counts'
    """
    with pd.ExcelWriter(out_xlsx, engine='openpyxl') as writer:
        unfiltered_df.to_excel(writer, sheet_name='unfiltered', index=False)
        filtered_df.to_excel(writer, sheet_name='filtered', index=False)
        read_counts_df.to_excel(writer, sheet_name='read_counts', index=False)

# --------------------------- Core logic --------------------------- #

def compute_subject_coverage(df: pd.DataFrame) -> pd.DataFrame:
    """
    Adds %_Ref_Cov column: percent of subject covered by the alignment (length / slen * 100).
    """
    # Avoid division by zero
    df = df.copy()
    df['%_Ref_Cov'] = (df['length'] / df['slen']) * 100.0
    # If any slen==0 slipped through, set coverage to 0
    df.loc[df['slen'] == 0, '%_Ref_Cov'] = 0.0
    return df

def best_hit_per_qseqid(filtered_df: pd.DataFrame) -> pd.DataFrame:
    """
    For each (Barcode, qseqid), select the subject with highest pident.
    Tie-breakers:
      - higher %_Ref_Cov
      - higher bitscore
      - lower evalue
      - longer alignment length
    """
    if filtered_df.empty:
        return filtered_df

    sort_cols = ['pident', '%_Ref_Cov', 'bitscore', 'evalue', 'length']
    ascending = [False, False, False, True, False]
    ranked = filtered_df.sort_values(sort_cols, ascending=ascending)
    best = ranked.drop_duplicates(subset=['Barcode', 'qseqid'], keep='first')
    return best

def dedup_same_subject_per_barcode(df: pd.DataFrame) -> pd.DataFrame:
    """
    If multiple query sequences hit the same subject within a barcode,
    keep the row with:
      - highest pident
      - qlen closest to slen (min abs difference)
      - higher %_Ref_Cov
      - higher bitscore
      - lower evalue
    """
    if df.empty:
        return df

    df = df.copy()
    df['abs_qlen_slen_diff'] = (df['qlen'] - df['slen']).abs()

    sort_cols = ['pident', 'abs_qlen_slen_diff', '%_Ref_Cov', 'bitscore', 'evalue']
    ascending = [False, True, False, False, True]

    ranked = df.sort_values(sort_cols, ascending=ascending)
    deduped = ranked.drop_duplicates(subset=['Barcode', 'salltitles'], keep='first')
    deduped = deduped.drop(columns=['abs_qlen_slen_diff'])
    return deduped

def ensure_output_columns(df: pd.DataFrame) -> pd.DataFrame:
    """
    Ensure columns and order in the output. Also rename 'Read Count' -> 'read_count'.
    """
    df = df.copy()
    if 'Read Count' in df.columns:
        df = df.rename(columns={'Read Count': 'read_count'})
    # Some sources may have 'read_count' already present
    # Final column order:
    final_cols = [
        'Barcode', 'qseqid', 'read_count', 'salltitles', 'pident',
        'length', 'qlen', 'slen', 'mismatch', 'gapopen', 'evalue',
        'bitscore', '%_Ref_Cov', 'Sequence'
    ]
    # Add missing columns with NA if needed
    for col in final_cols:
        if col not in df.columns:
            df[col] = pd.NA
    return df[final_cols]

def process_pipeline(
    input_csv: str,
    out_xlsx: str,
    min_ref_cov: float,
    min_pident: float,
    max_qlen: int,
    read_counts_csv: Optional[str] = None
) -> None:
    """
    Execute the full pipeline and write Excel output.
    """
    # Read input CSV
    required_cols = ['Barcode', 'qseqid', 'Read Count', 'query_fasta_file_path', 'blast_output_file_path']
    in_df = pd.read_csv(input_csv, dtype=str, names =required_cols )
    missing = [c for c in required_cols if c not in in_df.columns]
    if missing:
        raise ValueError(f"Input CSV is missing required columns: {missing}")

    # Normalize types for consistent downstream operations
    in_df['Read Count'] = in_df['Read Count'].astype(str)

    # Cache FASTA dicts to avoid rereading
    fasta_cache: Dict[str, Dict[str, str]] = {}

    all_hits = []  # list of DataFrames per row

    # Iterate rows
    for idx, row in in_df.iterrows():
        barcode = row['Barcode']
        qseqid = row['qseqid']
        read_count = row['Read Count']
        fasta_path = row['query_fasta_file_path']
        blast_path = row['blast_output_file_path']

        # Load BLAST
        dfb = read_blast_tsv(blast_path)
        # Restrict to the intended qseqid (safe even if file contains only one query)
        dfb = dfb[dfb['qseqid'] == read_count].copy()
        dfb['qseqid'] = barcode+'_'+qseqid
        if dfb.empty:
            # If no hits, still record a row with NaNs? We'll skip silently.
            continue

        # Compute % subject coverage
        dfb = compute_subject_coverage(dfb)

        # Add metadata
        dfb['Barcode'] = barcode
        dfb['Read Count'] = read_count

        # Attach Sequence from FASTA
        if fasta_path not in fasta_cache:
            fasta_cache[fasta_path] = read_fasta_to_dict(fasta_path)
        seq_map = fasta_cache[fasta_path]
        seq_val = seq_map.get(read_count)
        if seq_val is None:
            # Attempt secondary match: sometimes qseqid in BLAST may include full header;
            # we already used first token by default. If not found, leave empty.
            seq_val = pd.NA
        dfb['Sequence'] = seq_val

        all_hits.append(dfb)

    if not all_hits:
        raise RuntimeError("No BLAST hits found for any qseqid listed in the input CSV.")

    unfiltered_df = pd.concat(all_hits, ignore_index=True)

    # Prepare types before filtering
    for col in NUMERIC_COLUMNS + ['%_Ref_Cov']:
        unfiltered_df[col] = pd.to_numeric(unfiltered_df[col], errors='coerce')

    # Apply filters (subject coverage, identity, qlen)
    filt_mask = (
        (unfiltered_df['%_Ref_Cov'] >= float(min_ref_cov)) &
        (unfiltered_df['pident']    >= float(min_pident)) &
        (unfiltered_df['qlen']      <= float(max_qlen))
    )
    filtered_df0 = unfiltered_df.loc[filt_mask].copy()

    # Best subject per (Barcode, qseqid)
    filtered_best_per_q = best_hit_per_qseqid(filtered_df0)

    # Dedup: if multiple query sequences hit the same subject within a barcode
    filtered_final = dedup_same_subject_per_barcode(filtered_best_per_q)

    # Build outputs with required columns
    unfiltered_out = ensure_output_columns(unfiltered_df)
    filtered_out = ensure_output_columns(filtered_final)

    # Write Excel
    # Default to openpyxl; if not available, pandas will try xlsxwriter if installed
    with pd.ExcelWriter(out_xlsx, engine='openpyxl') as writer:
        unfiltered_out.to_excel(writer, sheet_name='unfiltered', index=False)
        filtered_out.to_excel(writer, sheet_name='filtered', index=False)


        # Optional read_counts sheet
        if read_counts_csv:
            read_counts_df = parse_read_counts(read_counts_csv)
            read_counts_df.to_excel(writer, sheet_name='read_counts', index=False)


    print(f"✅ Done. Excel written to: {out_xlsx}")
    print(f"   Unfiltered rows: {len(unfiltered_out)}")
    print(f"   Filtered rows:   {len(filtered_out)}")

# --------------------------- CLI --------------------------- #

def parse_args(argv=None):
    p = argparse.ArgumentParser(
        description="Filter BLAST results by subject coverage, identity, and query length, then export Excel."
    )
    p.add_argument("input_csv", help="CSV file with columns: Barcode,qseqid,Read Count,query_fasta_file_path,blast_output_file_path")
    p.add_argument("-o", "--out", dest="out_xlsx", default="blast_report.xlsx",
                   help="Output Excel workbook path (default: blast_report.xlsx)")
    p.add_argument("--min-ref-cov", type=float, default=80.0,
                   help="Minimum %% subject coverage (length/slen*100). Default: 80")
    p.add_argument("--min-pident", type=float, default=90.0,
                   help="Minimum percent identity. Default: 90")
    p.add_argument("--max-qlen", type=int, default=10000,
                   help="Maximum query length (qlen). Default: 10000")
    p.add_argument("--read-counts", dest="read_counts_csv", required=False,
               help="Path to read_count_results.csv (no header; may have bracketed values).")

    return p.parse_args(argv)

def main():
    args = parse_args()
    try:
        process_pipeline(
            input_csv=args.input_csv,
            out_xlsx=args.out_xlsx,
            min_ref_cov=args.min_ref_cov,
            min_pident=args.min_pident,
            max_qlen=args.max_qlen,
            read_counts_csv=args.read_counts_csv
        )
    except Exception as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
