#!/bin/bash
### Convert JAXA OU LandCover to various MODIS grids
### Copyright 2014 Jonah Duckles (jduckles@ou.edu)
###
### This script is used to process JAXA OU Landcover maps
###   at 50m into the MODIS grid at 250m, 500m and 1km using GRASS to
###   resample the fine resolution maps and compute a percentage
###   forest cover at each resolution.
########################################################################
#set -x

# Find directory we're running script from
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

. ${DIR}/../lib/helpers.sh

# A set of reference tiles from MOD09A1 to extract tile extents from
MODIS_TILES=/data/ddn/jduckles/modis_tiles
PALSAR_SOURCE=/data/ddn/PALSAR/PALSAR_Nov2014
OUTPUT=/data/scratch/jduckles/PALSAR


tilebounds() {
   # Generates tile bounds of MODIS tiles in
    # Input = Directory of MODIS HDFs
    MODIS_TILES=$1
    BOUNDS_FILE=../lib/tilebounds.csv
    # Find extent of raster tile:
    # Build a file containing MODIS tile extents
    if [ -f ${BOUNDS_FILE} ]; then
        echo "Found tile bounds"
    else
        TILES=$(for item in ${MODIS_TILES}/*.hdf; do echo HDF4_EOS:EOS_GRID:\"${item}\":MOD_Grid_500m_Surface_Reflectance:sur_refl_b01; done)
        echo -n "Computing tile bounds..."
        for tile in $TILES; do
            eval $(rasterextent $tile);
            echo $(modistilenumber $tile) $ulx $uly $llx $lly; done > ${BOUNDS_FILE}
        echo "Done"
    fi
}



tile_extract() {
  ### Extract tile with given bounds from base (global) VRT file.
  tilenum=$1;
  ulx=$2;
  uly=$3;
  llx=$4;
  lly=$5;
  INPUT=$6;
  OUTPUT=$7;
  echo "Warping ----> ${tilenum} with extent $ulx $uly $llx $lly";
  GDALOPTS="-co COMPRESS=LZW -projwin $ulx $uly $llx $lly";
  if [ -f ${OUTPUT} ]; then
    echo "Skipping tile, we've already extracted it.";
  else
    gdal_translate ${GDALOPTS} ${INPUT} ${OUTPUT};
fi;
}

mosaic() {
  ### This function operates on a directory full of tifs and a known list of
  ###   MODIS tile bounding coordinates and creates a set of output files which
  ###   represent the underlying dataset's pixels in a MODIS tile.
  IN=$1 # Input directory;
  OUT=$2 # Output directory;
  TAG=$3 # Prefix to name output [required];
  RES=$4 # Resolution of output;
  PROJ=~/modis_sinusoidal.prj # projection file
  echo "Building vrt from all data";
  if [ -f ${OUT}/${TAG}.vrt ]; then
    echo "Found ${OUT}/${TAG}.vrt, skipping";
  else
    gdalbuildvrt ${OUT}/${TAG}.vrt ${IN}/*${TAG};
  fi
  if [ -f  ${OUT}/${TAG}_warp.vrt ]; then
    echo "Found  ${OUT}/${TAG}_warp.vrt, skipping.";
  else
    gdalwarp -t_srs ${PROJ} -of VRT ${OUT}/${TAG}.vrt ${OUT}/${TAG}_warp.vrt;
  fi
  export -f tile_extract;
  cat ../lib/tilebounds.csv | parallel --bar -j 15 --env tile_extract --colsep " " "tile_extract {1} {2} {3} {4} {5} ${OUT}/${TAG}_warp.vrt ${OUT}/${TAG}_{1}_${RES}.tif"
}

mosaic /data/scratch/jduckles/PALSAR_Nov2014/IN/2010 /data/scratch/jduckles/PALSAR_Nov2014/OUT LandCover 50m

### THIS FUNCTION MUST RUN INSIDE OF A GRASS Session.
importtiles() {
    ## Enable GRASS Session
    # Enter GRASS location with MODIS sinusoidal projection
    DIR=$1
    for rast in ${DIR}/*.tif; do
        outname=$(basename ${rast/.tif/})
        if [ -n $(g.mlist rast pat=$outname) ]; then
            r.external $rast out=$outname;
        else
            echo "Skipping $outname"
        fi
    done
}

importtiles /data/scratch/jduckles/PALSAR_Nov2014/OUT

### THIS FUNCTION MUST RUN INSIDE OF A GRASS Session.
lc2modis() {
    ### This function uses grass's r.resamp.stats to compute the percentage
    ###   contribution of a MODIS-sized pixel area (250m,500m,1km) of underlying
    ###   50m PALSAR pixels.
    IN=$1
    OUT=$2
    if [ -f $OUT ]; then
        echo "Skipping, we already processed that one."
    else
    # Set to 50m grid for tile
    echo "processing $IN..."
    g.region rast=${IN}
# Reclass Landcover to binary map
    r.reclass input=${IN} output=${IN}_rc << EOF
1 = 0
2 = 1
3 4 = 0
0 = NULL
EOF
        time r.mapcalc ${IN}_tmp="if(${IN}_rc == 1, float(1), float(0))"
        # compute for 500m grid
        echo -n "aggregating at 500m..."
        grid=500m; g.region nsres=463.31271653 ewres=463.31271653
        time r.resamp.stats --o input=${IN}_tmp output=${OUT}_${grid} method=average
        r.out.gdal create=COMPRESS=LZW input=${OUT}_${grid} output=${OUT}_${grid}.tif
        # compute for 250m grid
        echo -n "aggregating at 250m..."
        grid=250m; g.region nsres=231.65285868 ewres=231.65285868;
        time r.resamp.stats --o input=${IN}_tmp output=${OUT}_${grid} method=average
        r.out.gdal create=COMPRESS=LZW input=${OUT}_${grid} output=${OUT}_${grid}.tif

        # compute for 1km grid
        echo -n "setting to 1km..."
        grid=1km; g.region nsres=926.6114347 ewres=926.6114347
        time r.resamp.stats --o input=${IN}_tmp output=${OUT}_${grid} method=average
        r.out.gdal create=COMPRESS=LZW input=${OUT}_${grid} output=${OUT}_${grid}.tif
    fi
    echo "Done with $IN"
}

# Run lc2modis over all imported tiles.
for i in $(g.mlist rast pat=Land*_50m); do lc2modis $i $i; done

mkdir ${PALSAR_SOURCE}/OUT/{50m,250m,500m,1km}
mv ${PALSAR_SOURCE}/OUT/*_50m.tif ${PALSAR_SOURCE}/OUT/50m
mv ${PALSAR_SOURCE}/OUT/*_250m.tif ${PALSAR_SOURCE}/OUT/250m
mv ${PALSAR_SOURCE}/OUT/*_500m.tif ${PALSAR_SOURCE}/OUT/500m
mv ${PALSAR_SOURCE}/OUT/*_1km.tif ${PALSAR_SOURCE}/OUT/1km


check_output() {
  DIR=$1
  SIZE=$2
  echo "Found $(ls $DIR/*.tif | wc -l ) tifs in ${DIR}"
  echo "Validataing that all tifs are appropriate size:"
  for item in ${DIR}/*.tif; do
    tsize=$(gdalinfo $item | grep "Size is" | sed 's/^Size is //g;s/, /,/g')
    if [ "$SIZE" == "$tsize" ]; then
      echo -n '.'
    else
      echo ""
      echo "$item is not the correct size"
    fi
  done

}
