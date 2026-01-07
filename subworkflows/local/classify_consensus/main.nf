/*
CLASSIFY_CONSENSUS: Classifies contigs using blastn against a reference database and filters results based on user-defined thresholds.
*/


include { BLAST_BLASTN      }      from '../../../modules/nf-core/blast/blastn/main'
include { noBlastHitsToMultiQC  }  from '../utils_nfcore_metapathogen_pipeline'

workflow CLASSIFY_CONSENSUS {

    take:
    ch_consensus                 // channel: [ val(meta), [ fasta ] ]
    ch_blast_refdb               // channel: [ path(blast_db) ]

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




    emit:
    no_blast_hits     = ch_no_blast_hits_mqc      // channel: [ val(meta), [ mqc ] ]
    versions = ch_versions                     // channel: [ versions.yml ]
}
