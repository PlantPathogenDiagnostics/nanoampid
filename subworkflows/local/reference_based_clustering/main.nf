/*
REFERENCE_BASED_CLUSTERING: Cluster reads against a reference database
*/
include { BBMAP_SEAL      }     from '../../../modules/local/bbmap/seal/main'
include { FILTLONG        }     from '../../../modules/nf-core/filtlong/main'

workflow REFERENCE_BASED_CLUSTERING {

    take:
    ch_long_reads // channel: [ val(meta), [ bam ] ]
    ch_reference  // channel: [ path(reference_fasta)]

    main:

    ch_versions = channel.empty()
    ch_mapped_reads = channel.empty()

    BBMAP_SEAL ( 
        ch_long_reads,
        ch_reference
    )
    ch_versions = ch_versions.mix(BBMAP_SEAL.out.versions.first())
    ch_mapped_reads = BBMAP_SEAL.out.reads.map{meta, reads -> tuple(meta, reads.findAll{ it -> it.countFastq() > 5 })} // Filter for references with at least 5 mapped reads

    

    // Flatten mapped reads channel for processing in FILTLONG
    ch_mapped_reads_flattened = ch_mapped_reads.flatMap { meta, file_list  ->
        file_list.collect { file ->
            [ meta, file ]
                def key = file.getSimpleName().replace("${meta.id}_", '')
                def mapped = [ref:key, file:file]
                [meta, mapped]
          }
        }

    //  ch_mapped_reads_flattened.view()

    FILTLONG (
        ch_mapped_reads_flattened.map { meta, mapped -> [ meta, [], mapped.file ] }  // No short reads provided
    )

    ch_versions = ch_versions.mix(FILTLONG.out.versions.first())
    FILTLONG.out.reads.view()

    emit:
    reads      = ch_mapped_reads                 // channel: [ val(meta), [ fastq ] ]
    versions   = ch_versions                     // channel: [ versions.yml ]
}
