/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { MULTIQC                       } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap              } from 'plugin/nf-schema'
include { paramsSummaryMultiqc          } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML        } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText        } from '../subworkflows/local/utils_nfcore_metapathogen_pipeline'

include { createFileChannel             } from '../subworkflows/local/utils_nfcore_metapathogen_pipeline'

// Preprocessing
include { LONGREAD_PREPROCESSING        } from '../subworkflows/local/longread_preprocessing/main'

// Reference-based clustering and consensus generation
include { REFERENCE_BASED_CLUSTERING    } from '../subworkflows/local/reference_based_clustering/main'

// Consensus classification
include { BLAST_MAKEBLASTDB             } from '../modules/nf-core/blast/makeblastdb/main'
include { CLASSIFY_CONSENSUS            } from '../subworkflows/local/classify_consensus/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow METAPATHOGEN {

    take:
    ch_samplesheet // channel: samplesheet read in from --input


    main:

    ch_versions      = channel.empty()
    ch_multiqc_files = channel.empty()
    ch_long_reads    = channel.empty()

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        PARAMETER INITIALIZATION
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

    ch_reference     = createFileChannel(params.reference)

    // Preprocessing reads
    LONGREAD_PREPROCESSING(
        ch_samplesheet,
        ch_reference
    )
    ch_versions = ch_versions.mix(LONGREAD_PREPROCESSING.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(LONGREAD_PREPROCESSING.out.multiqc_files.collect { it[1] }.ifEmpty([]))
    ch_long_reads = ch_long_reads.mix(LONGREAD_PREPROCESSING.out.long_reads)
    ch_read_counts = LONGREAD_PREPROCESSING.out.read_counts

    // Cluster and consensus generations
    REFERENCE_BASED_CLUSTERING(
        ch_long_reads,
        ch_reference
    )

    ch_consensus = REFERENCE_BASED_CLUSTERING.out.consensus
    ch_versions = ch_versions.mix(REFERENCE_BASED_CLUSTERING.out.versions)

    // Create BLAST database from reference sequences
    ch_reference_with_meta = ch_reference.map {
        item -> [['id': "id-fasta-for-makeblastdb"], item]
        }


    BLAST_MAKEBLASTDB (
        ch_reference_with_meta
     )
     ch_versions = ch_versions.mix(BLAST_MAKEBLASTDB.out.versions)
     ch_blast_refdb = BLAST_MAKEBLASTDB.out.db.collect{it[1]}.ifEmpty([]).map{it -> [[id: 'reference'], it]}

    // Classify consensus sequences
    CLASSIFY_CONSENSUS (
        ch_consensus,
        ch_blast_refdb,
        ch_read_counts
     )
     ch_versions = ch_versions.mix(CLASSIFY_CONSENSUS.out.versions.first())

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name:  'metapathogen_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }


    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        channel.fromPath(params.multiqc_config, checkIfExists: true) :
        channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        channel.empty()

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )
    ch_multiqc_files       =  ch_multiqc_files.mix(CLASSIFY_CONSENSUS.out.no_blast_hits.ifEmpty([]))

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        []
    )

    emit: multiqc_report = MULTIQC.out.report.toList()        // channel: /path/to/multiqc_report.html
    versions             = ch_versions                        // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
