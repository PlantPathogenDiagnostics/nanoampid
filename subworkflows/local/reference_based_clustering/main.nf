/*
REFERENCE_BASED_CLUSTERING: Cluster reads against a reference database
*/
include { BBMAP_SEAL      }     from '../../../modules/local/bbmap/seal/main'
include { FILTLONG        }     from '../../../modules/nf-core/filtlong/main'
include { SPOA            }     from '../../../modules/local/spoa/main'
include { ISONCLUST       }     from '../../../modules/local/isonclust/main'
include { CDHIT_CDHITEST  }     from '../../../modules/nf-core/cdhit/cdhitest/main'
include { CONCAT_FILES    }     from '../../../modules/local/concat_files/main'
include { MINIMAP2_ALIGN  }     from '../../../modules/nf-core/minimap2/align/main'
include { RACON           }     from '../../../modules/nf-core/racon/main'
include { MEDAKA          }     from '../../../modules/local/medaka/main' 

workflow REFERENCE_BASED_CLUSTERING {

    take:
    ch_long_reads // channel: [ val(meta), [ fastq ] ]
    ch_reference  // channel: [ path(reference_fasta)]

    main:

    ch_versions = channel.empty()
    ch_mapped_reads = channel.empty()

    // Cluster by reference mapping with BBMap Seal
    BBMAP_SEAL ( 
        ch_long_reads,
        ch_reference
    )
    ch_versions = ch_versions.mix(BBMAP_SEAL.out.versions.first())
    ch_seal_reads = BBMAP_SEAL.out.reads.map{meta, reads -> tuple(meta, reads.findAll{ it -> it.countFastq() > 5 })} // Filter for references with at least 5 mapped reads

    // Cluster by reference-free clustering with ISONCLUST
    ISONCLUST (
        ch_long_reads
    )
    ch_versions = ch_versions.mix(ISONCLUST.out.versions.first())
    ch_isonclust_reads = ISONCLUST.out.reads.view()

    // Merge reads belonging to
    ch_mapped_reads = ch_seal_reads.combine(ch_isonclust_reads, by: 0)
        .map { meta, mapped_reads, isonclust_reads ->
            def all_reads = mapped_reads + isonclust_reads
            tuple( meta, all_reads )
        }

    // Flatten mapped reads channel for processing in FILTLONG
    ch_mapped_reads_flattened = ch_mapped_reads.flatMap { meta, file_list  ->
        file_list.collect { file ->
            [ meta, file ]
                def key = file.getSimpleName().replace("${meta.id}_", '')
                def mapped = [ref:key, file:file]
                [meta, mapped]
          }
        }

    // Filter mapped reads with FILTLONG
    FILTLONG (
        ch_mapped_reads_flattened.map { meta, mapped -> [ meta, [], mapped.file ] } 
    )

    ch_mapped_reads_flattened = FILTLONG.out.reads.map { meta, filtered_read -> 
        def key = filtered_read.getSimpleName().replace("${meta.id}_", '')
        def mapped = filtered_read
        def meta_updated = meta + [ cluster: key ]
        [meta_updated, mapped]
    }
    ch_versions = ch_versions.mix(FILTLONG.out.versions.first())

    // Generate consensus sequences with SPOA
    SPOA (
        ch_mapped_reads_flattened
    )

    ch_mapped_reads_flattened = ch_mapped_reads_flattened
        .combine(SPOA.out.consensus, by:0)
        .combine(SPOA.out.read_count, by:0)
        .map { meta, mapped_reads, consensus, read_count_file ->
        def read_count = read_count_file.text.trim().toInteger()
        [meta + [ read_count: read_count ], mapped_reads, consensus ]
        }

    ch_versions = ch_versions.mix(SPOA.out.versions.first())
  
    // Align reads to consensus sequences with MINIMAP2
    MINIMAP2_ALIGN (
        ch_mapped_reads_flattened.map { meta, mapped_reads, _consensus -> tuple( meta, mapped_reads ) },
        ch_mapped_reads_flattened.map { meta, _mapped_reads, consensus -> tuple( meta, consensus ) },
        false,
        false,
        true,
        false
    )
    ch_versions = ch_versions.mix(MINIMAP2_ALIGN.out.versions.first())



    // Only continue with clusters that have aligned sequences
    MINIMAP2_ALIGN.out.paf
        .filter{ _meta, paf -> paf.countLines() > 0 }
        .set{ ch_minimap }

    ch_mapped_reads_flattened = ch_mapped_reads_flattened
        .combine(ch_minimap, by:0)

    // Polish consensus sequences with RACON and MEDAKA
    RACON (
        ch_mapped_reads_flattened
    )

    ch_versions = ch_versions.mix(RACON.out.versions.first())

    // Only continue with clusters that have aligned sequences
    RACON.out.improved_assembly
        .filter{ _meta, fasta -> fasta.countLines() > 0 }
        .set{ ch_racon }

    ch_mapped_reads_flattened = ch_mapped_reads_flattened
        .combine(ch_racon, by:0)

    MEDAKA (
        ch_mapped_reads_flattened
            .map { meta, reads, _ref, _paf, racon -> tuple( meta, reads, racon ) }
    )

    ch_versions = ch_versions.mix(MEDAKA.out.versions.first())
    ch_mapped_reads_flattened = MEDAKA.out.assembly
        .combine(ch_mapped_reads_flattened, by:0)

    // Combine consensus sequences from same sample
    ch_mapped_reads = ch_mapped_reads_flattened
        .map { meta, medaka, _reads, _ref, _paf, _racon 
        -> tuple (meta.id, medaka) }
        .groupTuple()
        .map { id, fasta_list
        -> tuple( [ id: id ], fasta_list ) }
    
    CONCAT_FILES (
        ch_mapped_reads
    )
    ch_versions = ch_versions.mix(CONCAT_FILES.out.versions.first())
    ch_mapped_reads = CONCAT_FILES.out.fasta


    CDHIT_CDHITEST (
        ch_mapped_reads
    )
    ch_versions = ch_versions.mix(CDHIT_CDHITEST.out.versions.first())
    //ch_mapped_reads = CDHIT_CDHITEST.out.fasta

    ch_consensus = CDHIT_CDHITEST.out.fasta.map { _meta, file ->
        def consensus = file.splitFasta( record: [id: true, sequence: false])
        ( consensus.id )
        }.flatten()

    ch_mapped_reads_flattened_final = ch_mapped_reads_flattened.map { meta, consensus, _reads, _ref, _paf, _racon -> 
        tuple(meta.id+'_'+meta.cluster, meta, consensus)}

    ch_consensus = ch_consensus.combine(ch_mapped_reads_flattened_final, by:0).map { _id, meta, consensus ->
        tuple( meta, consensus )}
        .view()

    emit:
    consensus      = ch_consensus                 // channel: [ val(meta), [ fasta ] ]
    versions       = ch_versions                  // channel: [ versions.yml ]
}
