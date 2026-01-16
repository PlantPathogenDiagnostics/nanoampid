/*
LONGREAD_PREPROCESSING: Preprocessing and QC for long reads
*/

include { PORECHOP_PORECHOP                } from '../../../modules/nf-core/porechop/porechop/main'
include { PORECHOP_ABI                     } from '../../../modules/nf-core/porechop/abi/main'
include { NANOQ as NANOQ_RAW               } from '../../../modules/nf-core/nanoq'
include { NANOQ as NANOQ_FILTERED          } from '../../../modules/nf-core/nanoq'
include { CHOPPER                          } from '../../../modules/nf-core/chopper'
include { VSEARCH_ORIENT                   } from '../../../modules/local/vsearch/orient/main'


workflow LONGREAD_PREPROCESSING {
    take:
    ch_samplesheet // [ [meta] , fastq] (mandatory)
    ch_reference  // channel: [ path(reference_fasta)]

    main:
    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    NANOQ_RAW(
        ch_samplesheet
    )
    ch_versions = ch_versions.mix(NANOQ_RAW.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(NANOQ_RAW.out.stats)

	// Get number of raw reads for each sample
    ch_read_counts = ch_samplesheet
        .map { meta, files ->
            // Update the meta map to include the count
            // files[0] or files[1] can be used to get one of the files for counting
            def count = files[0].countFastq()
            // raw = count // Add a new 'count' key to the meta map
            return tuple(meta, count)
        }

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
            ch_samplesheet,
        )
        ch_versions = ch_versions.mix(PORECHOP_PORECHOP.out.versions)
        ch_long_reads = PORECHOP_PORECHOP.out.reads
        ch_multiqc_files = ch_multiqc_files.mix(PORECHOP_PORECHOP.out.log)
    }

    CHOPPER(
        ch_long_reads,
        []
    )
    ch_versions = ch_versions.mix(CHOPPER.out.versions)


    VSEARCH_ORIENT (
        CHOPPER.out.fastq,
        ch_reference
    )
    ch_versions = ch_versions.mix(VSEARCH_ORIENT.out.versions)
    ch_long_reads = VSEARCH_ORIENT.out.reads

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
    }.view()



    emit:
    long_reads    = ch_long_reads
    versions      = ch_versions
    multiqc_files = ch_multiqc_files
    read_counts   = ch_read_counts
}