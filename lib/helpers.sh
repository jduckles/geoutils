
tile_extract() { 
    # Generic function to extract bounding box from larger raster mosaic
    tilenum=$1
    ulx=$2
    uly=$3
    llx=$4
    lly=$5
    INPUT=$6
    OUTPUT=$7
    echo "Warping ----> ${tilenum} with extent $ulx $uly $llx $lly"
    GDALOPTS="-co COMPRESS=LZW -projwin $ulx $uly $llx $lly"
    if [ -f ${OUTPUT} ]; then
        echo "Skipping tile, we've already extracted it."
    else
        gdal_translate ${GDALOPTS} ${INPUT} ${OUTPUT};
    fi
}

rasterextent() {
    # Parse out gdalinfo's output to ulx uly llx and lly
    RASTER=$1
    gdalinfo ${RASTER} |grep 'Upper Left\|Lower Right' | sed 's/\(^Upper Left  \)(\(.*\),\(.*\))\( (.*)\)/ulx=\2;uly=\3/g;s/\(Lower Right \)(\(.*\),\(.*\))\( (.*)\)/llx=\2;lly=\3/g;s/ //g'
}

modistilenumber() {
    # Find the modis tile pattern from MODIS filenames (assumes leading and trailing . characters)
    fname=$1
    echo $fname | grep -o '\.\(h[0-9]\{2\}v[0-9]\{2\}\)\.' | sed 's/\.//g'    
}

