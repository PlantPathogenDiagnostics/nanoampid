// TODO nf-core: If in doubt look at other nf-core/subworkflows to see how we are doing things! :)
//               https://github.com/nf-core/modules/tree/master/subworkflows
//               You can also ask for help via your pull request or on the #subworkflows channel on the nf-core Slack workspace:
//               https://nf-co.re/join
// TODO nf-core: A subworkflow SHOULD import at least two modules

include { BLAST_BLASTN      } from '../../../modules/nf-core/blast/blastn/main'

workflow CLASSIFY_CONSENSUS {

    take:
    ch_consensus                 // channel: [ val(meta), [ fasta ] ]
    ch_blast_refdb               // channel: [ path(blast_db) ]

    main:

    ch_versions = Channel.empty()


    BLAST_BLASTN ( ch_consensus, ch_blast_refdb, [], [], [] )
    ch_versions = ch_versions.mix(BLAST_BLASTN.out.versions.first())


    emit:
    // TODO nf-core: edit emitted channels
    // summary      = SAMTOOLS_SORT.out.bam           // channel: [ val(meta), [ bam ] ]

    versions = ch_versions                     // channel: [ versions.yml ]
}
