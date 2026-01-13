process SPOA {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/spoa%3A4.1.5--h077b44d_0' :
        'community.wave.seqera.io/library/spoa:4.1.5--8096d8f407f3177c' }"

    input:  
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.fasta")                 , emit: consensus
    path "versions.yml"                              , emit: versions
    tuple val(meta), path("*read_count.txt")         , emit: read_count

    when:
    task.ext.when == null || task.ext.when

    script:
    def args     = task.ext.args ?: ''
    def prefix   = task.ext.prefix ?: "${meta.id}_${meta.cluster}_ref"
    def raw      = "${reads[0]}"
    """
    spoa \\
        $raw \\
        $args \\
        > ${prefix}.fasta \\

    # Add number of reads used for consensus to fasta header
    zcat ${reads} | wc -l | awk '{print \$1 / 4}' > ${meta.id}_${meta.cluster}_read_count.txt
    read_count=\$(zcat ${reads} | wc -l | awk '{print \$1 / 4}') 
    awk -v read_count="\$read_count" 'BEGIN {i=0}  /^>/{i++; print ">"read_count; next} {print}' ${prefix}.fasta > ${prefix}_temp.fasta
    mv ${prefix}_temp.fasta ${prefix}.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        spoa: \$(spoa --version)
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix   = task.ext.prefix ?: "${meta.id}_${meta.cluster}_ref"

    """
    echo $args
    
    touch ${prefix}.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        spoa: \$(spoa --version)
    END_VERSIONS
    """
}
