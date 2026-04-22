process REFPERCLUSTER {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    'https://depot.galaxyproject.org/singularity/mulled-v2-e25d1fa2bb6cbacd47a4f8b2308bd01ba38c5dd7:75310f02364a762e6ba5206fcd11d7529534ed6e-0' :
    'biocontainers/mulled-v2-e25d1fa2bb6cbacd47a4f8b2308bd01ba38c5dd7:75310f02364a762e6ba5206fcd11d7529534ed6e-0' }"


    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.fasta")                 , emit: consensus
    tuple val(meta), path("*read_count.txt")         , emit: read_count


    when:
    task.ext.when == null || task.ext.when

    script:

    def args     = task.ext.args ?: ''
    def prefix   = task.ext.prefix ?: "${meta.id}_${meta.cluster}_ref"
    def raw      = "${reads[0]}"


    """
    ref_per_cluster.py \\
        $raw \\
        -o ${prefix}.fasta \\
        $args

    # Add number of reads used for consensus to fasta header
    zcat ${reads} | wc -l | awk '{print \$1 / 4}' > ${meta.id}_${meta.cluster}_read_count.txt
    read_count=\$(zcat ${reads} | wc -l | awk '{print \$1 / 4}') 
    awk -v read_count="\$read_count" 'BEGIN {i=0}  /^>/{i++; print ">"read_count; next} {print}' ${prefix}.fasta > ${prefix}_temp.fasta
    mv ${prefix}_temp.fasta ${prefix}.fasta

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
