#!/bin/bash

# this is a string of path and resource type delimited by ':::'
export INPUT_FILE_AND_FORMAT=$1
ORGANISM=$2
TARGET_FORMAT=$3

# convert the "human-readable" string into our "WebMeV-compatible" resource type
case $TARGET_FORMAT in
    "Wig")
        TARGET_FORMAT="WIG"
        ;;
    "BigWig")
        TARGET_FORMAT="BIGWIG"
        ;;
    "BedGraph")
        TARGET_FORMAT="BEDGRAPH"
        ;;
    *)
        echo "Not a valid choice for target format."
        exit 1;
esac

# split the input file and format. The WebMeV converter we use takes the WebMeV file and provides
# a string (path) and a resource type delimited by ":::"
INPUT_FILE=$(/usr/bin/python3 -c "import os; x=os.getenv('INPUT_FILE_AND_FORMAT'); print(x.split(':::')[0])")
INPUT_FORMAT=$(/usr/bin/python3 -c "import os; x=os.getenv('INPUT_FILE_AND_FORMAT'); print(x.split(':::')[1])")

if [ $INPUT_FORMAT == $TARGET_FORMAT ]; then
    echo "Input and output formats were the same. Try again."
    exit 1;
fi

# even though we don't need the organism for converting FROM bigwig,
# we get the info anyway.
case $ORGANISM in
    "Human(Ensembl)")
        CHR_SZ="/opt/software/resources/grch38_chr_sizes.txt"
        ;;
    "Mouse(Ensembl)")
        CHR_SZ="/opt/software/resources/grcm39_chr_sizes.txt"
        ;;
    "Human(UCSC)")
        CHR_SZ="/opt/software/resources/hg38_chr_sizes.txt"
        ;;
    "Mouse(UCSC)")
        CHR_SZ="/opt/software/resources/mm39_chr_sizes.txt"
        ;;
    *)
        echo "Not a valid choice for organism/genome."
        exit 1;
esac

# a flag to indicate whether the conversion requires two 'steps'.
# For instance, UCSC does not release a tool to go from wig to bedgraph.
# Hence, we do wig -> bigwig -> bedgraph, which requires running two
# executables.
DOUBLE_STEP=0

# Depending on which conversion we are doing, select the proper tool.
# Also define a canonical suffix for the target output file format:
if [[ $TARGET_FORMAT == "BIGWIG" && $INPUT_FORMAT == "WIG" ]]; then
    EXE="/opt/software/wigToBigWig"
    SUFFIX="bw"
elif [[ $TARGET_FORMAT == "BIGWIG" && $INPUT_FORMAT == "BEDGRAPH" ]]; then
    EXE="/opt/software/bedGraphToBigWig"
    SUFFIX="bw"
elif [[ $TARGET_FORMAT == "WIG" && $INPUT_FORMAT == "BIGWIG" ]]; then
    EXE="/opt/software/bigWigToWig"
    SUFFIX="wig"
    CHR_SZ=""
elif [[ $TARGET_FORMAT == "BEDGRAPH" && $INPUT_FORMAT == "BIGWIG" ]]; then
    EXE="/opt/software/bigWigToBedGraph"
    SUFFIX="bg"
    CHR_SZ=""
elif [[ $TARGET_FORMAT == "BEDGRAPH" && $INPUT_FORMAT == "WIG" ]]; then
    EXE1="/opt/software/wigToBigWig"
    EXE2="/opt/software/bigWigToBedGraph"
    SUFFIX="bg"
    DOUBLE_STEP=1
elif [[ $TARGET_FORMAT == "WIG" && $INPUT_FORMAT == "BEDGRAPH" ]]; then
    EXE1="/opt/software/bedGraphToBigWig"
    EXE2="/opt/software/bigWigToWig"
    SUFFIX="wig"
    DOUBLE_STEP=1
else
    echo "Something went wrong."
    exit 1
fi

# The output file with a canonical suffix
OUTPUT_PREFIX="${INPUT_FILE%.*}"
OUTPUT=$OUTPUT_PREFIX.$SUFFIX

if [ $DOUBLE_STEP == 0 ]; then
    # If making a direct conversion. CHR_SZ has already been set to an empty string if not 
    # part of the command
    $EXE $INPUT_FILE $CHR_SZ $OUTPUT
else
    # In the conversion where we convert to bigwig as an intermediate, we always need
    # the chrom sizes file. 
    $EXE1 $INPUT_FILE $CHR_SZ intermediate.tmp && $EXE2 intermediate.tmp $OUTPUT
fi

if [ $? == 0 ]
then
    BN=$(dirname $INPUT_FILE)
    echo "{\"output_file\": {\"path\":\"$OUTPUT\", \"resource_type\": \"$TARGET_FORMAT\"}}" > $BN/outputs.json
else
    exit 1
fi
