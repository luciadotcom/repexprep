##MetaCentrum baseline execution

#Login node
skirit.ics.muni.cz 

#Working directory:
```test
/storage/brno2/home/laynez-21/repexprep
 
#Input samplesheet:
samplesheets/local_test_subsample_metacentrum.csv

#Exact command
nextflow run . \
    -profile metacentrum \
    --input samplesheets/local_test_subsample_metacentrum.csv \
    --outdir results/metacentrum_organelle_filter_test \
  
#Resume command: 
nextflow run . \
    -profile metacentrum \
    --input samplesheets/local_test_subsample_metacentrum.csv \
    --outdir results/metacentrum_organelle_filter_test \
    -resume


