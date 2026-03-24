process FORMAT_DATABASE {
    tag "$meta.id"
    label 'process_low'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    'https://depot.galaxyproject.org/singularity/ubuntu:22.04' :
    'nf-core/ubuntu:22.04' }"

    input:
    tuple val(meta), path(input_file)

    output:
    tuple val(meta), path("formatted_${input_file}")        ,   emit: fasta
    path "versions.yml"                                     ,   emit: versions
    path"formatted_${input_file}"                           ,   emit: fasta_file

    when:
    task.ext.when == null || task.ext.when

    script:
    prefix = task.ext.prefix ?: "${meta.id}"

    """
    # Rename headers by filename
    
    sed  '/^>/s/\\W/_/2g' ${input_file} > formatted_${input_file}
    sed -i 's/\\r\$//' formatted_${input_file}
   

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sed: \$( sed --version | grep -m 1 "sed" | sed 's/sed (GNU sed) //')
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch formatted_${input_file}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sed: \$( sed --version | grep -m 1 "sed" | sed 's/sed (GNU sed) //')
    END_VERSIONS
    """
}