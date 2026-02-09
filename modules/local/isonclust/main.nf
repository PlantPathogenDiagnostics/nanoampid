process ISONCLUST {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/isonclust:0.0.6.1--py_0':
        'biocontainers/isonclust:0.0.6.1--py_0' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.fastq.gz", arity: '1..*')    , emit: reads
    path "versions.yml"                                   , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def raw      = "${reads[0]}"

    """
    gunzip -c ${raw} > ${prefix}_temp.fastq
    isONclust \\
        $args \\
        --fastq ${prefix}_temp.fastq \\
        --outfolder ${prefix}
    mv ${prefix}/final_clusters.tsv ${prefix}.tsv
    isONclust \\
        write_fastq \\
        --clusters ${prefix}.tsv \\
        --fastq ${prefix}_temp.fastq \\
        --outfolder . \\
        --N 5
    rm ${prefix}_temp.fastq
    gzip *.fastq
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        isonclust: \$(isonclust --version)
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    echo $args
    
    touch ${prefix}.fastq
    gzip ${prefix}.fastq

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        isonclust: \$(isonclust --version)
    END_VERSIONS
    """
}