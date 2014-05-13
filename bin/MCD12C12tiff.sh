#!/bin/bash
#
# Extract Land Cover Type 1 to tif files from MCD12C1


FNAME=$1

LABEL=${FNAME:0:13}

CREATEOPTS="-co COMPRESS=LZW"

gdal_translate ${CREATEOPTS} HDF4_EOS:EOS_GRID:"${FNAME}":MOD12C1:Land_Cover_Type_1_Percent ${LABEL}_Land_Cover_Type_1_Percent.tif
gdal_translate ${CREATEOPTS} HDF4_EOS:EOS_GRID:"${FNAME}":MOD12C1:Majority_Land_Cover_Type_1_Assessment ${LABEL}_Majority_Land_Cover_Type_1_Assessment.tif
gdal_translate ${CREATEOPTS} HDF4_EOS:EOS_GRID:"${FNAME}":MOD12C1:Majority_Land_Cover_Type_1 ${LABEL}_Majority_Land_Cover_Type_1.tif



