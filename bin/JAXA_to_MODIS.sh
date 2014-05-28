### Convert JAXA FNF to MODIS 500m grid
### Copyright 2014 Jonah Duckles (jduckles@ou.edu)
### 
### This script is used to process JAXA Forest-non-Forest maps 
###   at 50m into the MODIS MOD09A1 grid at 500m using GRASS to
###   resample the fine resolution (FNF) maps and compute a percentage
###   forest cover at 500m.
########################################################################


# Find directory we're running script from 
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

. ${DIR}/../lib/helpers.sh

# A set of reference tiles from MOD09A1 to extract tile extents from
MODIS_TILES=/data/ddn/jduckles/modis_tiles
PALSAR_SOURCE=/data/ddn/PALSAR/PALSAR_2014/
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

stage_years() {
    YEARS=$1
    for year in ${YEARS}; do
        if [ -d ${OUTPUT}/${year} ]; then
            echo "Found directory..."
        else
            mkdir -p ${OUTPUT}/${year}
            echo "Staging tiles for ${year}"
            stage_PALSAR ${PALSAR_SOURCE}/${year} ${OUTPUT}/${year}
        fi
        echo "Mosaicing to VRT file"
        mosaic_year ${year}
    done
}

stage_years {2007..2010}

mosaic_year() {
    YEAR=$1
    # Combine all PALSAR data into vrt logical mosaic
    echo "Building vrt from all PALSAR data"
    gdalbuildvrt ${OUTPUT}/FNF_${YEAR}.vrt ${OUTPUT}${YEAR}/*_C
    # Warp the vrt
    gdalwarp -t_srs ~/modis_sinusoidal.prj -of VRT FNF_${YEAR}.vrt FNF_${YEAR}_warp.vrt

    # Loop over all MODIS tiles and extract from VRT mosiaic
    cat ${DIR}/../lib/tilebounds.csv | parallel --bar -j 15 --env tile_extract --colsep " " "tile_extract {1} {2} {3} {4} {5} ${OUTPUT}/FNF_${YEAR}_warp.vrt FNF_MODIS_{1}_50m.tif"

}

## Enable GRASS Session

# Enter GRASS location with MODIS sinusoidal projection
for i in *.tif; do r.external $i out=${i/.tif/}; done

fnf2modis() { 
    input=$1
    output=$2
    g.region rast=${input}
# Reclass FNF to binary map
    r.reclass input=${input} output=${input}_rc << EOF
1 = 1
2 3 = 0
0 = NULL
EOF
    r.mapcalc ${input}_tmp="if(${input}_rc == 1, float(1), float(0))"
    g.region nsres=463.31271653 ewres=463.31271653
    r.resamp.stats --o input=${input}_tmp output=${output} method=average
    g.remove rast=${input}_rc,${input}_tmp
    r.out.gdal create=COMPRESS=LZW input=${output} output=/data/scratch/FNF_MODIS/output/${output}.tif
}


$GISBASE/etc/clean_temp


