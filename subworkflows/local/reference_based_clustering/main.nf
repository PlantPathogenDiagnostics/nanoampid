/*
REFERENCE_BASED_CLUSTERING: Cluster reads against a reference database
*/
include { BBMAP_SEAL      }     from '../../../modules/local/bbmap/seal/main'
include { FILTLONG        }     from '../../../modules/nf-core/filtlong/main'
include { SPOA            }     from '../../../modules/local/spoa/main'
include { ISONCLUST       }     from '../../../modules/local/isonclust/main'
include { CDHIT_CDHITEST  }     from '../../../modules/nf-core/cdhit/cdhitest/main'

workflow REFERENCE_BASED_CLUSTERING {

    take:
    ch_long_reads // channel: [ val(meta), [ fastq ] ]
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

    ISONCLUST (
        ch_long_reads
    )
    ch_versions = ch_versions.mix(ISONCLUST.out.versions.first())
    ch_mapped_reads = ch_mapped_reads.mix(ISONCLUST.out.reads)


    // Flatten mapped reads channel for processing in FILTLONG
    ch_mapped_reads_flattened = ch_mapped_reads.flatMap { meta, file_list  ->
        file_list.collect { file ->
            [ meta, file ]
                def key = file.getSimpleName().replace("${meta.id}_", '')
                def mapped = [ref:key, file:file]
                [meta, mapped]
          }
        }


    FILTLONG (
        ch_mapped_reads_flattened.map { meta, mapped -> [ meta, [], mapped.file ] } 
    )

    ch_versions = ch_versions.mix(FILTLONG.out.versions.first())

    SPOA (
        FILTLONG.out.reads
    )

    ch_cluster_ref = SPOA.out.fasta
    ch_versions = ch_versions.mix(SPOA.out.versions.first())

    ch_cluster_ref
        .map { meta, data -> [meta.id, data] }
        .groupTuple(by: 0)
        .view()



/*
    CDHIT_CDHITEST (
        ch_cluster_ref
    )

    ch_cluster_ref = CDHIT_CDHITEST.out.fasta
    ch_versions = ch_versions.mix(CDHIT_CDHITEST.out.versions.first())  

*/
    emit:
    reads      = ch_mapped_reads                 // channel: [ val(meta), [ fastq ] ]
    versions   = ch_versions                     // channel: [ versions.yml ]
}
