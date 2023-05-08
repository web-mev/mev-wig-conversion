#!/bin/bash

# this is a string of path and resource type delimited by ':::'
INPUT_FILE_AND_FORMAT=$1
ORGANISM=$2
TARGET_FORMAT=$3

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
        echo "Not a valid choice"
        exit 1;
esac

# if we are converting FROM bigwig, just set CHR_SZ
# to an empty string so it will be ignored
if [ $TARGET_FORMAT != "BIGWIG" ]; then
    CHR_SZ=""
fi

if [[ $TARGET_FORMAT == "BIGWIG" && $INPUT_FORMAT == "WIG"]]; then
    EXE="/opt/software/wigToBigWig"
    SUFFIX="wig"
elif [[ $TARGET_FORMAT == "BIGWIG" && $INPUT_FORMAT == "BEDGRAPH"]]; then
    EXE=/opt/software/bedGraphToBigWig
    SUFFIX="bg"
elif [[ $TARGET_FORMAT == "WIG" && $INPUT_FORMAT == "BIGWIG"]]; then
    EXE=/opt/software/wigToBigWig
    SUFFIX="bw"
elif [[ $TARGET_FORMAT == "BEDGRAPH" && $INPUT_FORMAT == "BIGWIG"]]; then
    EXE=/opt/software/bedGraphToBigWig
    SUFFIX="bw"
fi

OUTPUT_PREFIX="${INPUT_FILE%.*}"
OUTPUT=$OUTPUT_PREFIX.$SUFFIX
$EXE $INPUT_FILE $CHR_SZ $OUTPUT

if [ $? == 0 ]
then
    BN=$(dirname $INPUT_FILE)
    echo "{\"output_file\": \"$OUTPUT\"}" > $BN/outputs.json
else
    exit 1
fi
