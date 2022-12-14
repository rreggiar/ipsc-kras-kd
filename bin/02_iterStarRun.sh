#!/bin/bash

# rreggiar@ucsc.edu


scriptName=$(basename $0)
if [ $# -lt 4 ]; then
    echo "error: usage $scriptName sampleDir starGenome 2pass={T/F} edit={T/F}"
    echo "example $scriptName /scratch/kimlab/projects/exoRNA-biomarkers-panc/data/a549_0.2MOI_24hr \
    intra /public/groups/kimlab/indexes/sel.aln.gen.34.ucsc.rmsk.index.salmon.1.2.1"
    exit 1
fi

sampleDir="$1"
starGenome="$2"
twoPass="$3"
edit="$4"
projectDir=$5 # "/public/groups/kimlab/exRNA_disease_biomarkers"

dateStamp="$(bash helper_dateStamp.sh)"

echo "cmd: "$@""

for inputDir in "$sampleDir"/*; do

	set -x 

	./02a_starRun.sh "$inputDir" "$twoPass" "$edit" "$starGenome" "$dateStamp"

	#nohup ./02b_starQualityCheck.sh "${inputDir}" "/public/groups/kimlab/exRNA_disease_biomarkers/data/output_data/rna_qc/star/" \
	#	2>&1 > $projectDir/tmp/logs/$(basename $inputDir)_star_qc_log.txt &

	exitStatus=$?
	if [ $? -ne 0 ]; then

	    echo ERROR "$scriptName" "$inputDir" returned exit status "$exitStatus"
	    continue

	fi

	set +x

done
