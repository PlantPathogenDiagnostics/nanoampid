/*
CLASSIFY_CONSENSUS: Classifies contigs using blastn against a reference database and filters results based on user-defined thresholds.
*/


include { BLAST_BLASTN      } from '../../../modules/nf-core/blast/blastn/main'

workflow CLASSIFY_CONSENSUS {

    take:
    ch_consensus                 // channel: [ val(meta), [ fasta ] ]
    ch_blast_refdb               // channel: [ path(blast_db) ]

    main:

    ch_versions = Channel.empty()

    // Classify consensus sequences with blastn
    BLAST_BLASTN ( 
        ch_consensus, ch_blast_refdb, [], [], [] 
        )
    
    ch_versions = ch_versions.mix(BLAST_BLASTN.out.versions.first())



    emit:
    // TODO nf-core: edit emitted channels
    // summary      = SAMTOOLS_SORT.out.bam           // channel: [ val(meta), [ bam ] ]

    versions = ch_versions                     // channel: [ versions.yml ]
}
