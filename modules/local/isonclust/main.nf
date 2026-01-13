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
    path "versions.yml"                    , emit: versions

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
        isonclust: \$(isonclust --version)
    END_VERSIONS
    """
}
