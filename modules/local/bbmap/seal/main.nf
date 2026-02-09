process BBMAP_SEAL {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/5a/5aae5977ff9de3e01ff962dc495bfa23f4304c676446b5fdf2de5c7edfa2dc4e/data' :
        'community.wave.seqera.io/library/bbmap_pigz:07416fe99b090fa9' }"

    input:
    tuple val(meta), path(reads)
    path reference

    output:
    tuple val(meta), path("*.fastq.gz", arity: '1..*')        , emit: reads
    tuple val(meta), path('*.log')                            , emit: log
    path "versions.yml"                                       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def raw      = "in=${reads[0]}"
    def reference_fa = reference ? "ref=$reference" : ''

    """
    seal.sh \\
        -Xmx${task.memory.toGiga()}g \\
        $raw \\
        $args \\
        $reference_fa \\
        &> ${prefix}.seal.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bbmap: \$(bbversion.sh | grep -v "]")
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def output_command  = "echo '' | ${meta.id}_reference_name.fq"
    """
    echo $args
    touch ${prefix}.bbduk.log
    $output_command

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bbmap: \$(bbversion.sh | grep -v "]")
    END_VERSIONS
    """
}
