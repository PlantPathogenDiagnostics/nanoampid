/*
LONGREAD_PREPROCESSING: Preprocessing and QC for long reads
*/

include { PORECHOP_PORECHOP                } from '../../../modules/nf-core/porechop/porechop/main'
include { PORECHOP_ABI                     } from '../../../modules/nf-core/porechop/abi/main'
include { NANOQ as NANOQ_RAW               } from '../../../modules/nf-core/nanoq'
include { NANOQ as NANOQ_FILTERED          } from '../../../modules/nf-core/nanoq'
include { CHOPPER                          } from '../../../modules/nf-core/chopper'


workflow LONGREAD_PREPROCESSING {
    take:
    ch_samplesheet // [ [meta] , fastq] (mandatory)

    main:
    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    NANOQ_RAW(
        ch_samplesheet
    )
    ch_versions = ch_versions.mix(NANOQ_RAW.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(NANOQ_RAW.out.stats)

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
    ch_long_reads = CHOPPER.out.fastq

    NANOQ_FILTERED(
        ch_long_reads
    )
    ch_versions = ch_versions.mix(NANOQ_FILTERED.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(NANOQ_FILTERED.out.stats)

    emit:
    long_reads    = ch_long_reads
    versions      = ch_versions
    multiqc_files = ch_multiqc_files
}