#!/bin/bash
set -e
set -u
## args are the following:
# $1 = projectDir
# $2 = sample
# $3 = fwd_reads (.fastq.gz)
# $4 = rev_reads (.fastq.gz)
# $5 = 
# $6 = 
# $7 = 
# $8 = 

module load BBMap/38.98-GCC-11.2.0

# # repair reads that might be broken
# repair.sh \
#     in1=$3 \
#     in2=$4 \
#     out1=fixed1.fastq.gz \
#     out2=fixed2.fastq.gz \
#     outs=singletons.fastq.gz \
#     repair

# discover adapters (BBMerge)
bbmerge.sh \
    in=$3 \
    in2=$4 \
    outa=${2}_adapters.fa

# adapter trimming (BBDuk)
bbduk.sh \
    in=$3 \
    in2=$4 \
    out=${2}_at_R1.fastq.gz \
    out2=${2}_at_R2.fastq.gz \
    ref=${2}_adapters.fa \
    ktrim=r \
    k=23 \
    mink=11 \
    hdist=1 \
    tpe \
    tbo

# contaminant filtering
bbduk.sh \
    in=${2}_at_R1.fastq.gz \
    in2=${2}_at_R2.fastq.gz \
    out=${2}_cf_R1.fastq.gz \
    out2=${2}_cf_R2.fastq.gz \
    outm=phiX_match.fastq.gz \
    ref=${1}/assets/phiX.fasta \
    k=31 \
    hdist=1

# paired-read merging
bbmerge.sh \
    in=${2}_cf_R1.fastq.gz \
    in2=${2}_cf_R2.fastq.gz \
    out=${2}_merged.fastq.gz \
    outu=${2}_unmerged_R1.fastq.gz \
    outu2=${2}_unmerged_R2.fastq.gz \
    vstrict
