#!/usr/bin/env nextflow

// shebang is strictly not necessary if run with nextflow

// this will be the call 
// nextflow run main.nf --in hepatitis/* --out out --accession  M21012

// There is an nextflow.config file which sets conda as default for envs and provides an cachedir

// setting params with accession M21012 as default
params {
    accession = "M21012"
    in = null
    // hepatitis/seq?.fasta to catch all files
    out = "out"
    
}

process fetch_reference_NCBI {
    publishDir "$params.out/reference"

    conda "bioconda::entrez-direct=24.0"
    //container "https://depot.galaxyproject.org/singularity/entrez-direct:24.0--he881be0_0" not used here

    input:
        val accession
    output:
        path "${accession}.fasta"
    script:
        """
        esearch -db nucleotide -query "$accession" | efetch -format fasta > "${accession}.fasta"
        """
}

process fetch_data_files_and_cat {
    publishDir "$params.out/aln"
    input:
        path reference
        path samples
    output:
        path "merged.fasta"
    script:
    
    """
    cat $samples $reference > merged.fasta
    """
}

process mafft {
    publishDir "$params.out/aln"

    conda "bioconda::mafft=7.525"
    input:
        path samples_merged        
    output:
        path "output.aln"
    script:
        """
        mafft --auto $samples_merged > output.aln
        """

}

process trimal {
    publishDir "$params.out/report"

    conda "bioconda::trimal=1.5.0"

    input:
        path aln
    output:
        path "output.clean.aln"
        path "output.clean.html"        
    script:
        """
        trimal \\
        -in $aln \\
        -out "output.clean.aln" \\
        -htmlout "output.clean.html" \\
        -automated1
        """
}

workflow {
    def ch_ref = fetch_reference_NCBI(params.accession)
    def ch_samples = channel.fromPath("${params.in}/*.fasta").collect()
    def ch_seq = fetch_data_files_and_cat(ch_ref, ch_samples).view()
    def ch_maf = mafft(ch_seq)
    def ch_tri = trimal(ch_maf)
}

