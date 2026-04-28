process RACON {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'community.wave.seqera.io/library/racon:1.5.0--eb0a17215e005d19' :
        'oras://community.wave.seqera.io/library/racon:1.5.0--0f7d7e0fa284c5c6' }"

    input:
    tuple val(meta), path(reads), path(assembly), path(paf)

    output:
    tuple val(meta), path('*_assembly_consensus.fasta.gz') , emit: improved_assembly
    path "versions.yml"          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    racon -t "$task.cpus" \\
        "${reads}" \\
        "${paf}" \\
        $args \\
        "${assembly}" > \\
        ${prefix}_assembly_consensus.fasta

    gzip -n ${prefix}_assembly_consensus.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        racon: \$( racon --version 2>&1 | sed 's/^.*v//' )
    END_VERSIONS
    """
}
