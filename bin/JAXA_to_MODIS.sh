### Convert JAXA FNF to MODIS 


# Find extent of raster tile:
rasterextent() {
    # Parse out gdalinfo's output to ulx uly llx and lly
    RASTER=$1
    gdalinfo ${RASTER} |grep 'Upper Left\|Lower Right' | sed 's/\(^Upper Left  \)(\(.*\),\(.*\))\( (.*)\)/ulx=\2;uly=\3/g;s/\(Lower Right \)(\(.*\),\(.*\))\( (.*)\)/llx=\2;lly=\3/g;s/ //g'
}

modistilenumber() {
    fname=$1
    echo $fname | grep -o '\.\(h[0-9]\{2\}v[0-9]\{2\}\)\.' | sed 's/\.//g'    
}

TILES=$(find /data/ddn/modis/products/mod09a1/geotiff/ndvi/2011 -name "*A2011001*"| sort)

for tile in $TILES; do eval $(rasterextent $tile); echo $(modistilenumber $tile) $ulx $uly $llx $lly; done > tilebounds.csv


for tile in $TILES; do

    tilenum=$(modistilenumber ${tile})
    eval $(rasterextent ${tile})
    echo "Warping ----> ${tilenum} with extent $ulx $uly $llx $lly"
    GDALOPTS="-co COMPRESS=LZW -projwin $ulx $uly $llx $lly"
    if [ -f /data/scratch/FNF_MODIS/FNF_2010_modis/FNF_2010_${tilenum}_50m_modisgrid.tif ]; then
        echo "Skipping tile, we've already extracted it."
    else
        gdal_translate ${GDALOPTS} /data/scratch/FNF_MODIS/FNF_2010_warp.vrt /data/scratch/FNF_MODIS/FNF_2010_modis/FNF_2010_${tilenum}_50m_modisgrid.tif
    fi

done



