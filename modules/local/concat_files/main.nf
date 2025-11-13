    process CONCAT_FILES {
        tag "$meta.id"
        label 'process_low'

        container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:22.04' :
        'nf-core/ubuntu:22.04' }"

        input:
        tuple val(meta), path(input_files)

        output:
        tuple val(meta), path("${meta.id}_ref_consensus.fasta") ,   emit: fasta
        path "versions.yml"                                     ,   emit: versions

        when:
        task.ext.when == null || task.ext.when

        script:
        prefix = task.ext.prefix ?: "${meta.id}"

        """
        # Rename headers by filename
        for file in ${input_files}; do
            filename_no_ext="\${file%%_medaka.*}"
            sed -i "s/^>.*/>\${filename_no_ext}/" "\$file"
        done

        cat ${input_files} > ${meta.id}_ref_consensus.fasta

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            cat: \$( cat --version | grep "cat" | sed 's/cat (GNU coreutils) //')
        END_VERSIONS
        """

        stub:
        prefix = task.ext.prefix ?: "${meta.id}"
        """
        touch ${prefix}_ref_consensus.fasta

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            cat: \$( cat --version | grep "cat" | sed 's/cat (GNU coreutils) //')
        END_VERSIONS
        """
    }