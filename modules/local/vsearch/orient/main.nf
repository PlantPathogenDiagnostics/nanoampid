
process VSEARCH_ORIENT {
    tag "$meta.id"
    label 'process_low'


    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/vsearch:2.28.1--h6a68c12_1':
        'biocontainers/vsearch:2.28.1--h6a68c12_1' }"

    input:
    tuple val(meta), path(reads)
    path reference

    output:
    tuple val(meta), path("*.fastq.gz") , emit: reads
    path "versions.yml"              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def raw      = "${reads[0]}"
    def reference_fa = reference ? "$reference" : ''

    """
    vsearch \\
        --orient ${raw} \\
        --db $reference_fa \\
        --fastqout ${prefix}.fastq \\
        $args
    gzip -c ${prefix}.fastq > ${prefix}.fastq.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        vsearch: \$(vsearch --version 2>&1 | head -n1 | cut -d"_" -f1 | cut -d"v" -f3)
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    echo $args
    
    touch ${prefix}.fastq

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        vsearch: \$(vsearch --version 2>&1 | head -n1 | cut -d"_" -f1 | cut -d"v" -f3)
    END_VERSIONS
    """
}
