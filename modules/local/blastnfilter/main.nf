process BLASTNFILTER {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/be/be62e5ef8d549f0b0d2a2c9f13e0f25063fb4f96fa880a5cbefc076bcc860dd7/data'
        : 'community.wave.seqera.io/library/openpyxl_pandas:cd21657f7b97bb0f'}"

    input:
    path(blast)
    path(meta2)

    output:
    path("*.xlsx")                     , emit: blastsummary
    path "versions.yml"                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''


    """
    filter_blastn_contigs.py \\
        ${blast} \\
        ${meta2} \\
        --outfile ${params.output}.xlsx \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        blastnfilter: \$(blastnfilter --version)
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    // TODO nf-core: A stub section should mimic the execution of the original module as best as possible
    //               Have a look at the following examples:
    //               Simple example: https://github.com/nf-core/modules/blob/818474a292b4860ae8ff88e149fbcda68814114d/modules/nf-core/bcftools/annotate/main.nf#L47-L63
    //               Complex example: https://github.com/nf-core/modules/blob/818474a292b4860ae8ff88e149fbcda68814114d/modules/nf-core/bedtools/split/main.nf#L38-L54
    // TODO nf-core: If the module doesn't use arguments ($args), you SHOULD remove:
    //               - The definition of args `def args = task.ext.args ?: ''` above.
    //               - The use of the variable in the script `echo $args ` below.
    """
    echo $args
    
    touch ${prefix}.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        blastnfilter: \$(blastnfilter --version)
    END_VERSIONS
    """
}
