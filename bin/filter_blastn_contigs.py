#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
This script takes a list of blastn files for each contig assembled from a single sample. It filters the best hit for each contig, and takes the most complete and highest identity contig for each species identified in the sample.

@author: sonunziata
"""

import pandas as pd

ref_cov_cutoff = float(50)
pident_cutoff = float(95)
mismatch_cutoff = float(11)
con_len_cutoff = float(1000)

#blast_files = ['phytophthora_bar01_0.txt', 'phytophthora_bar01_1.txt', 'phytophthora_bar01_ITS_P_niederhauserii_ET_ST-BL45_MG865552.txt', 'phytophthora_bar01_ITS_P_ramorum_ET_ST_BL_55G_MG865581_1.txt']

blast_files = ['phytophthora_bar12_0.txt','phytophthora_bar12_1.txt','phytophthora_bar12_2.txt', 'phytophthora_bar12_4.txt','phytophthora_bar12_ITS_P_chilensis_ET_CBS148797_ON000726.txt','phytophthora_bar12_ITS_P_chlamydospora_ET_ST-BL156_MG865471.txt','phytophthora_bar12_ITS_P_kernoviae_ET_ST-BL91_MG865521.txt','phytophthora_bar12_ITS_P_pseudokernoviae_ET_CBS148796_ON000780.txt','phytophthora_bar12_ITS_P_syringae_ENT_ST-BL57G_MG865590.txt']

#Read each file into a df and combine them
df_list = [pd.read_csv(file, sep='\t', header=None, names=['qseqid', 'pident', 'slen', 'qlen', 'length', 'qcovs', 'mismatch', 'gapopen', 'evalue', 'bitscore', 'salltitles']) for file in blast_files]
combined_df = pd.concat(df_list, ignore_index=True)

combined_df['%_Ref_Cov'] = 100* (combined_df['length']/combined_df['slen'])

#Filter by parameters
combined_df= combined_df[combined_df['%_Ref_Cov'] > ref_cov_cutoff]
combined_df = combined_df[combined_df['pident'] > pident_cutoff]
combined_df = combined_df[combined_df['qlen'] < con_len_cutoff]
combined_df = combined_df.dropna()

#Get the hit with the highest %id for each contig
groups = combined_df.groupby(by=['qseqid'], as_index=False, sort=False)
summary_filtered = groups.apply(lambda g: g[g['pident'] == g['pident'].max()])

#If multiple contigs hit the same reference, retain the reference with the highest pident
groups = summary_filtered.groupby(by=['salltitles'], as_index=False, sort=False)
summary_filtered = groups.apply(lambda g: g[g['pident'] == g['pident'].max()])

summary_filtered.to_csv('filtered.csv', index=False)
combined_df.to_csv('all.csv', index=False)