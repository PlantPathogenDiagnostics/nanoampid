#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
This script takes blast output from MetaLong pipeline and filters the best hit for each contig then reports the most complete and highest identity contig for each species identified in the sample.

@author: sonunziata
"""

import argparse
import sys
import pandas as pd
from pathlib import Path


parser = argparse.ArgumentParser(description="Provide a command line tool to filter blastn results",epilog="Example: python filter_blastn_contigs.py blast.txt reads.txt")

parser.add_argument(
    "blast",
    metavar="BLAST FILE",
    type=Path,
    help="Blast result file in specific out format.",
)

parser.add_argument(
    "read_counts",
    metavar="READS",
    type=Path,
    help="Read count file.",
)

parser.add_argument(
    "-o",
    "--outfile",
    metavar="OUTFILE",
    type=Path,
    help="Output file name",
    default="summary_out.xlsx"
)

parser.add_argument(
    "-a",
    "--min_ref_cov",
    metavar="alignment",
    type=float,
    help="percentage of query alignment length cutoff",
)

parser.add_argument(
    "-i",
    "--min_pident",
    metavar="identity",
    type=float,
    help="percentage identity to reference cutoff",
)

parser.add_argument(
    "-m",
    "--max_mismatch",
    metavar="mismatch",
    type=float,
    help="maximum number of nucleotide mismatches with the reference",
    default=11
)

parser.add_argument(
    "-c",
    "--max_con_len",
    metavar="conlength",
    type=float,
    help="maximum length of the consensus length cutoff",
)
args = parser.parse_args()


#Read in sample metadata and file locations of blast and consensus fasta
all_results = pd.read_csv(args.blast, header=None, names=['Barcode','Cluster','Read Count','consensus','blast'])

#Create a dataframe with metadata and blast information for all samples
summary_consensus = []

for r in all_results.itertuples(index=False):
    new_data = pd.read_csv(r[4],sep='\t', header=None,names=['qseqid', 'pident', 'Ref Length', 'Consensus Length', 'length', 'qcovs', 'mismatch', 'gapopen', 'evalue', 'bitscore', 'Ref Sequence'])
    with open (r[3]) as fh: 
        next(fh) 
        new_data['Sequence'] = next(fh) 
    new_data[['Barcode','Cluster','Read Count']] = r[:3]
    new_data['qseqid'] = new_data['Barcode'].astype(str)+'_'+new_data['Cluster'].astype(str)
    summary_consensus.append(new_data)

combined_df = pd.concat(summary_consensus, ignore_index=True)

#Calculate portion of reference covered by consensus sequence
combined_df['%_Ref_Cov'] = 100* (combined_df['length']/combined_df['Ref Length'])

#Calculate contig length difference from reference
#combined_df['len_dif'] = abs(combined_df['qlen'] - combined_df['slen'])

#Filter by parameters
combined_df= combined_df[combined_df['%_Ref_Cov'] > args.min_ref_cov]
combined_df = combined_df[combined_df['pident'] > args.min_pident]
combined_df = combined_df[combined_df['Consensus Length'] < args.max_con_len]
combined_df = combined_df.dropna()



#Get the hit with the highest %id for each contig
groups = combined_df.groupby(by=['qseqid'], as_index=False, sort=False)
summary_filtered = groups.apply(lambda g: g[g['pident'] == g['pident'].max()])


#If multiple contigs hit the same reference within a sample, retain the contig with the longest contig with the highest pident
groups = summary_filtered.groupby(by=['Barcode','Ref Sequence'], as_index=False, sort=False)
summary_filtered = groups.apply(lambda g: g[g['pident'] == g['pident'].max()])
#summary_filtered = groups.apply(lambda g: g[g['Consensus Length'] == g['Consensus Length'].max()])
#summary_filtered = groups.apply(lambda g: g[g['len_dif'] == g['len_dif'].min()])

#Organize columns for output
# Define the new order of columns
new_order = ['Barcode', 'Cluster', 'Read Count','Ref Sequence','pident', 'length', 'Ref Length', 'Consensus Length', 'mismatch', 'gapopen', 'evalue', 'bitscore', '%_Ref_Cov', 'Sequence']

# Reassign the DataFrame with the new column order
summary_filtered = summary_filtered[new_order]
combined_df = combined_df[new_order]

#Create read count table
read_columns=['Barcode', 'Raw Reads', 'Filtered Reads']
reads=pd.read_csv(args.read_counts, header=None, names=read_columns)
reads[read_columns]= reads[read_columns].apply(lambda x: x.astype(str).str.strip('[]'))



# create excel writer
writer = pd.ExcelWriter(args.outfile)
# write dataframe to excel sheet
reads.to_excel(writer, 'read_summary', index=False)
if summary_filtered is not None:
	summary_filtered.to_excel(writer, 'blastn_summary', index=False)
if combined_df is not None:
	combined_df.to_excel(writer, 'blastn_unfiltered', index=False)

writer.close()
