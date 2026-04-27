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
    path("*.xlsx")                           , emit: blastsummary
    // path "versions.yml"                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''


    """
    filter_blastn.py \\
        ${blast} \\
        --read-counts ${meta2} \\
        -o ${params.output}.xlsx \\
        ${args}


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        pandas: \$(pip show pandas | grep Version | sed 's/Version: //g')
    END_VERSIONS

    """

    stub:
    def args = task.ext.args ?: ''
    """
    touch ${params.output}.xlsx
 

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        pandas: \$(pip show pandas | grep Version | sed 's/Version: //g')
    END_VERSIONS
    """
}
