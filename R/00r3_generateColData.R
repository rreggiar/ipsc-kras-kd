#!/user/bin/env Rscript

## rreggiar@ucsc.edu

## generate 'colData' for tximeta aggregation of data using the naming conventions established 
##+ for organizing RNAseq data

# data/
## input_data
### experiment_name/
#### sample_name -- condition.rep.input_vol* *(if needed)

#[tximeta vignette](https://bioconductor.org/packages/devel/bioc/vignettes/tximeta/inst/doc/tximeta.html#Analysis_starts_with_sample_table)
#[alevin process aware](https://combine-lab.github.io/alevin-tutorial/2020/alevin-velocity/)

suppressPackageStartupMessages({
library(tidyverse)
library(tximeta)
library(SummarizedExperiment)
library(HDF5Array)
})

parse.input <- function(data_path, output_name, gencode_ver) {

	output_files <- list.files(data_path, full.names = TRUE)
    	names(output_files) <- output_files

    	print('target dirs:')
    	print(output_files)

	imap(output_files, function(path, path_name) {

		     list.files(path, full.names = T) -> quant_paths

		     names(quant_paths) <- quant_paths

		     lapply(quant_paths, function(this_path) {

				    quant_path <- Sys.glob(file.path(this_path,paste0("*v", gencode_ver, ".",output_name,"*"), "quant.sf"))[1]

				    quant_name <- basename(this_path)

				    quant_name_split <- str_split(quant_name, '[.]', n = 3)[[1]]

				    if(quant_name_split[length(quant_name_split)] %in% c('intra', 'exo')) {
					    
					    name_list <- lst('files' = quant_path,
							     'names' = quant_name,
							     'condition' = quant_name_split[1], 
							     'rep' = quant_name_split[2],
							     'context' = quant_name_split[3],
							     'input_vol' = NA)


				    } else {
					    
					    name_list <- lst('files' = quant_path, 
							     'names' = quant_name,
							     'condition' = quant_name_split[1], 
							     'rep' = quant_name_split[2],
							     'context' = 'exo',
							     'input_vol' = quant_name_split[3])
				    }

		     }) %>% bind_rows()
	}) %>% bind_rows(.id = 'project') %>% mutate(project = basename(project))  -> sample_df

	sample_df
}



build.tximeta.obj <- function(output_name, sample_df, tx2gene, txome_tsv, project, outpath) {

	outpath <- paste0(outpath, output_name, '_quant')

	print('sending output to: ')
	print(outpath)

	if(!dir.exists(outpath)) {dir.create(outpath)}
		
	print(paste0('tsv:', txome_tsv))

	print('example out: ')

	print(file.path(outpath,paste0(project, '_',output_name, '_h5_se')))

	print('import data with tximeta')
	txi <- tximeta::tximeta(coldata = sample_df, type = 'salmon', skipMeta=FALSE)

	print('save tx h5')
	saveHDF5SummarizedExperiment(txi, dir=file.path(outpath,paste0(project, '_',output_name, '_h5_se')) , replace=TRUE)

	# TE genes will appear on multiple strands, tximeta has an argument to allow this
	singleStrand = T
	if(output_name == 'ucsc.rmsk.salmon') {singleStrand = F}

	import::from(.from = helper_s2gene_RER.R, 
		    .directory = '/public/groups/kimlab/exRNA_disease_biomarkers/R/',
		    .all = T)

	gxi <- summarizeToGene_RER(txi) #, single.strand.genes.only = singleStrand)

	print('save gene h5: ')
	print(file.path(outpath,paste0(project, '_', output_name, '_gene_h5_se')))

	saveHDF5SummarizedExperiment(gxi, dir=file.path(outpath,paste0(project, '_', output_name, '_gene_h5_se')), replace=TRUE)


	if (txome_tsv != 'NULL'){

		print('intron aware')
		cg <- read.delim(txome_tsv, header = TRUE, as.is = TRUE)
	
		colnames(cg)[colnames(cg) == 'intron'] <- 'unspliced'
		split.gxi <- tximeta::splitSE(gxi, cg, assayName = 'counts')
	
		saveHDF5SummarizedExperiment(split.gxi, 
			dir=file.path(outpath,paste0(project, '_', output_name, '_gene_split_h5_se')), 
			replace=TRUE)
	}

	print('all done')
}



main <- function() {

	paths.in <- scan(file=file("stdin", "r"), what="character", n=6)

	data_path <- paths.in[1] 
	txome_path <- paths.in[2]
	output_name <- paths.in[3]
	txome_tsv <- paths.in[4]
	outpath <- paths.in[5]
	gencode_ver <- paths.in[6]

	print('parse input dir')
	sample_df <- parse.input(data_path, output_name, gencode_ver)
	print('head')
	print(head(sample_df))
	print('tail')
	print(tail(sample_df))

	print('load tximeta')
	tximeta::loadLinkedTxome(txome_path)

	print(paste0('load tx2gene for gencode v ', gencode_ver))
	tx2gene_path <- file.path(paste0('/public/groups/kimlab/genomes.annotations/gencode.', gencode_ver),
				  paste0('gencode.v', gencode_ver, '.ucsc.rmsk.tx.to.gene.csv'))
	tx2gene <- read_csv(tx2gene_path, col_names=c('tx', 'gene'))
	print(head(tx2gene))
	
	print('build tximeta object')
	
	map(unique(sample_df$project), function(this_project) {

		this_df <- sample_df %>% filter(project == this_project) %>% dplyr::select(-project)

		print(this_project)
		print(this_df)
		
		build.tximeta.obj(output_name, this_df, tx2gene, txome_tsv, this_project, outpath)

	}) 
	
	#build.tximeta.obj(output_name, sample_df, tx2gene)

}

main()
