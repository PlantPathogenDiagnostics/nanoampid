process SPOA {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/spoa:4.1.5--8096d8f407f3177c' :
        'community.wave.seqera.io/library/spoa:4.1.5--8096d8f407f3177c' }"

    input:  
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.fasta") , emit: fasta
    path "versions.yml"              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args     = task.ext.args ?: ''
    def key      = reads.getSimpleName().replace("${meta.id}_", '')
    def prefix   = task.ext.prefix ?: "${meta.id}_${key}_ref"
    def raw      = "${reads[0]}"
    """
    spoa \\
        $raw \\
        $args \\
        > ${prefix}.fasta \\


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        spoa: \$(spoa --version)
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def key      = reads.getSimpleName().replace("${meta.id}_", '')
    def prefix   = task.ext.prefix ?: "${meta.id}_${key}_ref"

    """
    echo $args
    
    touch ${prefix}.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        spoa: \$(spoa --version)
    END_VERSIONS
    """
}
