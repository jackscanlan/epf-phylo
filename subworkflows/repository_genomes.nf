/*
 *  Retrieve and process existing genomes from the NCBI database 
 */


//// modules to import
include { CHANNEL_TO_FILE                                           } from '../modules/channel_to_file'
include { FIND_ASSEMBLIES_SINGLE                                } from '../modules/find_assemblies_single'
include { FIND_ASSEMBLIES_GROUP                                 } from '../modules/find_assemblies_group'
include { QUAST as QUAST_REPOSITORY                             } from '../modules/quast'


workflow REPOSITORY_GENOMES {

    take:
    
    ncbi_taxid
    limit_repository
    samples

    main:

    //// define channels as empty
    ch_genomes_found_single     = Channel.empty()
    ch_genomes_found_group      = Channel.empty()
    ch_assemblies_single_tsvs    = Channel.empty()
    ch_assemblies_group_tsvs    = Channel.empty()
    ch_assemblies_meta                     = Channel.empty()

    //// get all genome assemblies specified in samplesheet
    if ( samples ) {
        FIND_ASSEMBLIES_SINGLE ( samples )
        
        ch_genomes_found_single
            .concat ( FIND_ASSEMBLIES_SINGLE.out.genome )
            .flatten()
            .map { file ->
                // get file basename
                def base = file.name.lastIndexOf('.').with {it != -1 ? file.name[0..<it] : file.name}
                // get accession from basename
                def accession = ( base =~ /^(.*?\.\d+)_.*?$/ )[0][1]
                // channel output format
                [ accession, file ]
            }
            .set { ch_genomes_found_single }

        //// rename output .tsvs from FIND_ASSEMBLIES_SINGLE
        FIND_ASSEMBLIES_SINGLE.out.tsv
            .splitCsv ( header: ['label','accession','taxon_name','taxid'], skip: 1, sep: "\t" )
            .map { row ->
                [ row.accession, row.label, row.taxon_name, row.taxid ] }
            .join ( ch_genomes_found_single, by: 0 )
            .set { ch_assemblies_single_meta }
        
    }

    //// get all genomes assemblies from a specific taxid, if specified using params.ncbi_taxid
    if ( ncbi_taxid ) {
        FIND_ASSEMBLIES_GROUP ( ncbi_taxid, limit_repository )

        ch_genomes_found_group
            .concat ( FIND_ASSEMBLIES_GROUP.out.genome )
            .flatten()
            .map { file ->
                // get file basename
                def base = file.name.lastIndexOf('.').with {it != -1 ? file.name[0..<it] : file.name}
                // get accession from basename
                def accession = ( base =~ /^(.*?\.\d+)_.*?$/ )[0][1]
                // channel output format
                [ accession, file ]
            }
            .set { ch_genomes_found_group }

        //// rename output .tsvs from FIND_ASSEMBLIES_GROUP
        FIND_ASSEMBLIES_GROUP.out.tsv
            .splitCsv ( header: ['label','accession','taxon_name','taxid'], skip: 1, sep: "\t" )
            .map { row ->
                [ row.accession, row.label, row.taxon_name, row.taxid ] }
            .join ( ch_genomes_found_group, by: 0 )
            .set { ch_assemblies_group_meta }
    }

    //// combine group and single assemblies with metadata, removing duplicates
    ch_assemblies_meta
        .concat ( ch_assemblies_single_meta )
        .concat ( ch_assemblies_group_meta )
        .groupTuple ( by: 0 )
        .map { accession, label, taxon_name, taxid, genome ->
            [ accession, label[0], taxon_name[0], taxid[0], genome[0] ] }
        .set { ch_assemblies_meta }
    
    //// save meta channel as file
    ch_assemblies_meta
        .collect ( flat: false )
        .set { ch_assemblies_meta_fileinput }

    CHANNEL_TO_FILE ( 
        ch_assemblies_meta_fileinput, 
        "tsv", 
        "accession,label,taxon_name,taxid,genome" 
    )
    

    //// combine ch_genomes_found_single and ch_genomes_found_group, removing duplicates
    ch_genomes_found_single
        .concat ( ch_genomes_found_group )
        .set { ch_genomes_found }

    // ch_genomes_found.count().view { "$it total genomes before deduplication" }

    //// format output channel as [ accession, scaffolds ]
    ch_assemblies_meta
        .map { accession, label, taxon_name, taxid, genome -> [ accession, genome ] }
        .tap { out_assemblies }
        .map { accession, genome ->
            [ accession, "$projectDir/assets/NO_FILE1", "$projectDir/assets/NO_FILE2", "$projectDir/assets/NO_FILE3", genome ]
        }
        .set { ch_genomes_repository }

    // assembly_seq_genomes_repository.count().view { "$it total genomes after deduplication" }

    //// run quast on repository assemblies
    QUAST_REPOSITORY ( ch_genomes_repository, "old" )


    emit:
    
    out_assemblies
    // assembly_report_genomes_repository = FIND_ASSEMBLIES_GROUP.out.tsv
    quast_report_genomes_repository = QUAST_REPOSITORY.out.report_tsv
    quast_plot_genomes_repository = QUAST_REPOSITORY.out.nx_plot

}