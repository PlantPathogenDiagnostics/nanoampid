/*
CLASSIFY_CONSENSUS: Classifies contigs using blastn against a reference database and filters results based on user-defined thresholds.
*/


include { BLAST_BLASTN          }      from '../../../modules/nf-core/blast/blastn/main'
include { noBlastHitsToMultiQC  }      from '../utils_nfcore_metapathogen_pipeline'
include { BLASTNFILTER          }      from '../../../modules/local/blastnfilter/main'

workflow CLASSIFY_CONSENSUS {

    take:
    ch_consensus                 // channel: [ val(meta), [ fasta ] ]
    ch_blast_refdb               // channel: [ path(blast_db) ]
    ch_read_counts               // channel: [ val(meta) ]

    main:

    ch_versions = channel.empty()

    // Classify consensus sequences with blastn
    BLAST_BLASTN ( 
        ch_consensus, ch_blast_refdb, [], [], [] 
        )
    
    ch_versions = ch_versions.mix(BLAST_BLASTN.out.versions.first())

    ch_blast_txt = BLAST_BLASTN.out.txt.branch { _meta, txt ->
        no_hits: txt.countLines() == 0
        hits: txt.countLines() > 0
    }

    // Make a table of samples that did not have any blast hits
    ch_no_blast_hits = channel.empty()
    ch_no_blast_hits = ch_blast_txt.no_hits.join(ch_consensus)

    ch_no_blast_hits_mqc = noBlastHitsToMultiQC(ch_no_blast_hits).collectFile(name:'samples_no_blast_hits_mqc.tsv')

    ch_consensus = ch_consensus.combine(ch_blast_txt.hits, by:0).map { meta, consensus, blast ->
        tuple( meta, consensus, blast )}
    
    // Convert channel to file for python filtering and summary
    ch_consensus = ch_consensus
        .collectFile(
            name: 'blast_results.csv',
            newLine: true
        ) { meta, consensus, blast ->
            "${meta.id},${meta.cluster},${meta.read_count},${consensus},${blast}"
        }

    ch_read_counts = ch_read_counts
        .collectFile(
            name: 'read_count_results.csv',
            newLine: true
        ) { meta ->
            "${meta.id},${meta.raw},${meta.filtered}"
        }

    BLASTNFILTER(
        ch_consensus,
        ch_read_counts
    )

    emit:
    no_blast_hits     = ch_no_blast_hits_mqc      // channel: [ val(meta), [ mqc ] ]
    versions = ch_versions                     // channel: [ versions.yml ]
}
