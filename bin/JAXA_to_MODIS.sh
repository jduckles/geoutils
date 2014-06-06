#!/bin/bash
### Convert JAXA FNF to MODIS 500m grid
### Copyright 2014 Jonah Duckles (jduckles@ou.edu)
### 
### This script is used to process JAXA Forest-non-Forest maps 
###   at 50m into the MODIS MOD09A1 grid at 500m using GRASS to
###   resample the fine resolution (FNF) maps and compute a percentage
###   forest cover at 500m.
########################################################################
#set -x

# Find directory we're running script from 
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

. ${DIR}/../lib/helpers.sh

# A set of reference tiles from MOD09A1 to extract tile extents from
MODIS_TILES=/data/ddn/jduckles/modis_tiles
PALSAR_SOURCE=/data/ddn/PALSAR/PALSAR_2014/Rawdata_new
OUTPUT=/data/scratch/jduckles/PALSAR

# Find extent of raster tile:
# Build a file containing MODIS tile extents
if [ -f ../lib/tilebounds.csv ]; then
    echo "Found tile bounds"
else
    TILES=$(for item in $(find ${MODIS_TILES}); do echo HDF4_EOS:EOS_GRID:\"${item}\":MOD_Grid_500m_Surface_Reflectance:sur_refl_b01; done)
    echo -n "Computing tile bounds..."
    for tile in $TILES; do 
	eval $(rasterextent $tile); 
	echo $(modistilenumber $tile) $ulx $uly $llx $lly; done > ../lib/tilebounds.csv
    echo "Done"
fi


# Uncompress and stage tiles in a scratch directory
stage_PALSAR() {
    INPUT_DIR=$1
    OUTPUT_DIR=$2
    echo "Uncompress all tiles..."
    ls ${INPUT_DIR}/*.tar.gz | parallel -j 10 "tar -xvf {} -C ${OUTPUT_DIR}"
    echo "Uncompress subtiles..."
    find ${OUTPUT_DIR} -name *.gz | parallel -j 10 "tar -xzvf {} -C ${OUTPUT_DIR}"
    echo "Finished staging tiles"
}

mosaic_year() {
    YEAR=$1
    # Combine all PALSAR data into vrt logical mosaic
    echo "Building vrt from all PALSAR data"
    if [ -f ${OUTPUT}/FNF_${YEAR}.vrt ]; then
        echo "Found ${OUTPUT}/FNF_${YEAR}.vrt, skipping"
    else
        gdalbuildvrt ${OUTPUT}/FNF_${YEAR}.vrt ${OUTPUT}/${YEAR}/*_C
    fi
    # Warp the vrt
    if [ -f  ${OUTPUT}/FNF_${YEAR}_warp.vrt ]; then
        echo "Found  ${OUTPUT}/FNF_${YEAR}_warp.vrt, skipping."
    else 
        gdalwarp -t_srs ~/modis_sinusoidal.prj -of VRT ${OUTPUT}/FNF_${YEAR}.vrt ${OUTPUT}/FNF_${YEAR}_warp.vrt
    fi
    # Loop over all MODIS tiles and extract from VRT mosiaic
    numtiles=$(ls ${OUTPUT}/*${YEAR}.tif)
    if [ $numtiles -gte 280 ]; then
        echo "We already extracted all the tiles";
    else    
    export -f tile_extract
    cat ${DIR}/../lib/tilebounds.csv | parallel --bar -j 15 --env tile_extract --colsep " " "tile_extract {1} {2} {3} {4} {5} ${OUTPUT}/FNF_${YEAR}_warp.vrt ${OUTPUT}/FNF_MODIS_{1}_${YEAR}_50m.tif"
    fi

}

stage_years() {
    YEARS=$1
    for year in ${YEARS}; do
        if [ -d ${OUTPUT}/${year} ]; then
            echo "Found directory..."
        else
            mkdir -p ${OUTPUT}/${year}
            echo "Staging tiles for ${year}"
            stage_PALSAR ${PALSAR_SOURCE}/${year}/FNF ${OUTPUT}/${year}
        fi
        echo "Mosaicing to VRT file"
        mosaic_year ${year}
    done
}

stage_years {2007..2010}


## Enable GRASS Session

# Enter GRASS location with MODIS sinusoidal projection
for rast in ${OUTPUT}/*.tif; do 
    outname=$(basename ${rast/.tif/})
    if [ -n $(g.mlist rast pat=$outname) ]; then
        echo "Skipping $outname"
    else
        r.external $rast out=$outname; 
    fi
done

fnf2modis() { 
    input=$1
    g.region rast=${input}
# Reclass FNF to binary map
    r.reclass input=${input} output=${input}_rc << EOF
1 = 1
2 3 = 0
0 = NULL
EOF
    r.mapcalc ${input}_tmp="if(${input}_rc == 1, float(1), float(0))"
    g.region nsres=463.31271653 ewres=463.31271653
    r.resamp.stats --o input=${input}_tmp output=${input} method=average
    g.remove rast=${input}_rc,${input}_tmp
    r.out.gdal create=COMPRESS=LZW input=${input} output=${OUTPUT}/${input/50m/500m}.tif
}

for rast in $(g.mlist rast pattern=FNF_MODIS_*_50m); do
    fnf2modis ${rast};
done


