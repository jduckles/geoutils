#!/bin/bash
#################################################################
# (c) 2014 Jonah Duckles - jonah@duckles.org 
# 
# Clip a raster - to the extent of an ogr vector dataset
#
#   Usage:
#       cutregion input.tif input.shp layername outfile.tif
# 
#   Can be used to cut raster data down to policical boundaries
#       in vector files.
################################################################ 

INPUT=$1
OGRFILE=$2
LAYER=$3
OUTFILE=$4

# Use ogrinfo to convert underlying dataset to sqlite in-memory, 
#   then query that dataset for bounding box, converting to shell variable
#   assignments that are evaled.
eval $(ogrinfo -dialect sqlite -sql "select mbrminx(geometry), mbrmaxy(geometry), 
    mbrmaxx(geometry), mbrminy(geometry) from ${LAYER}" ${OGRFILE} | \
     grep \=  | sed 's/(geometry) (Real)//g;s/ //g')

# Put together mbr as a string for gdal_translate
bbox="$mbrminx $mbrmaxy $mbrmaxx $mbrminy"

# Reduce original raster to extent of vector minimum bounding rectangle
gdal_translate -projwin $bbox ${INPUT} ${INPUT/.*/_tmpclip.tif}

# Apply cutline (vector cut) 
gdalwarp -cutline "$2" "${INPUT/.*/_tmpclip.tif}" "${OUTFILE}"

# cleanup
rm  ${INPUT/.*/_tmpclip.tif}

