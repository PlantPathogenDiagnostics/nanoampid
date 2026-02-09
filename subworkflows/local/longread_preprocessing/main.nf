/*
LONGREAD_PREPROCESSING: Preprocessing and QC for long reads
*/

include { SEQKIT_RMDUP                     } from '../../../modules/nf-core/seqkit/rmdup/main'
include { PORECHOP_PORECHOP                } from '../../../modules/nf-core/porechop/porechop/main'
include { PORECHOP_ABI                     } from '../../../modules/nf-core/porechop/abi/main'
include { NANOQ as NANOQ_RAW               } from '../../../modules/nf-core/nanoq'
include { NANOQ as NANOQ_FILTERED          } from '../../../modules/nf-core/nanoq'
include { CHOPPER                          } from '../../../modules/nf-core/chopper'
include { BBMAP_REFORMAT                   } from '../../../modules/local/bbmap/reformat'
include { VSEARCH_ORIENT                   } from '../../../modules/local/vsearch/orient'


workflow LONGREAD_PREPROCESSING {
    take:
    ch_samplesheet // [ [meta] , fastq ] (mandatory)
    ch_reference   // [ path(reference_fasta) ] (mandatory)

    main:
    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    // QC of raw reads
    NANOQ_RAW(
        ch_samplesheet
    )
    ch_versions = ch_versions.mix(NANOQ_RAW.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(NANOQ_RAW.out.stats)

	// Get number of raw reads for each sample
    ch_read_counts = ch_samplesheet
        .map { meta, files ->
            def count = files[0].countFastq()
            return tuple(meta, count)
        }

    // Remove duplicate reads
    SEQKIT_RMDUP(
        ch_samplesheet,
    )
    ch_versions = ch_versions.mix(SEQKIT_RMDUP.out.versions)
    ch_long_reads = SEQKIT_RMDUP.out.fastx

    // Adapter trimming with porechop or porechop_abi
    if (params.adaptertrimming_tool == 'porechop_abi') {
        PORECHOP_ABI(
            ch_samplesheet,
            [],
        )
        ch_versions = ch_versions.mix(PORECHOP_ABI.out.versions)
        ch_long_reads = PORECHOP_ABI.out.reads
        ch_multiqc_files = ch_multiqc_files.mix(PORECHOP_ABI.out.log)
    }
    else if (params.adaptertrimming_tool == 'porechop') {
        PORECHOP_PORECHOP(
            ch_long_reads,
        )
        ch_versions = ch_versions.mix(PORECHOP_PORECHOP.out.versions)
        ch_long_reads = PORECHOP_PORECHOP.out.reads
        ch_multiqc_files = ch_multiqc_files.mix(PORECHOP_PORECHOP.out.log)
    }


    // Filter reads by quality and length
    CHOPPER(
        ch_long_reads,
        []
    )
    ch_versions = ch_versions.mix(CHOPPER.out.versions)
    ch_long_reads = CHOPPER.out.fastq

    //Orient Reads with database
    VSEARCH_ORIENT(
        ch_long_reads,
        ch_reference
    )

    //Truncate read names to comply with down-stream processing
    BBMAP_REFORMAT (
        VSEARCH_ORIENT.out.reads,
    )
    ch_versions = ch_versions.mix(BBMAP_REFORMAT.out.versions)
    ch_long_reads = BBMAP_REFORMAT.out.reads

    // QC of filtered reads
    NANOQ_FILTERED(
        ch_long_reads
    )
    ch_versions = ch_versions.mix(NANOQ_FILTERED.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(NANOQ_FILTERED.out.stats)

    // Get number of filtered reads for each sample
    ch_read_counts = ch_long_reads.combine(ch_read_counts, by:0).map{
        meta, files, raw ->
        def filtered = files.countFastq()
        meta.raw=raw
        meta.filtered=filtered
        return tuple(meta)
    }

    emit:
    long_reads    = ch_long_reads
    versions      = ch_versions
    multiqc_files = ch_multiqc_files
    read_counts   = ch_read_counts
}