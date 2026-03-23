

include { BLAST_MAKEBLASTDB             } from '../../../modules/nf-core/blast/makeblastdb/main'
include { FORMAT_DATABASE               } from '../../../modules/local/format_database/main'

workflow CREATE_DATABASE {

    take:
    ch_reference_with_meta // channel: [ val(meta), [ fasta ] ]

    main:

    ch_versions = channel.empty()

    FORMAT_DATABASE (
        ch_reference_with_meta
     )

    ch_versions = ch_versions.mix(FORMAT_DATABASE.out.versions.first())
    ch_reference_with_meta = FORMAT_DATABASE.out.fasta

    BLAST_MAKEBLASTDB (
        ch_reference_with_meta
     )

     ch_versions = ch_versions.mix(BLAST_MAKEBLASTDB.out.versions)
     ch_blast_refdb = BLAST_MAKEBLASTDB.out.db.collect{it[1]}.ifEmpty([]).map{it -> [[id: 'reference'], it]}

    emit:
    // TODO nf-core: edit emitted channels
    blast_refdb     = ch_blast_refdb        // channel: [ val(meta), [ fasta ] ]
    versions           = ch_versions           // channel: [ versions.yml ]
}
