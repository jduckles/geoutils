### Convert JAXA FNF to MODIS 

. ../lib/helpers.sh

# Find extent of raster tile:


# Build a file containing MODIS tile extents
TILES=$(for item in $(find /data/ddn/jduckles/modis_tiles/); do echo HDF4_EOS:EOS_GRID:\"${item}\":MOD_Grid_500m_Surface_Reflectance:sur_refl_b01; done)
for tile in $TILES; do eval $(rasterextent $tile); echo $(modistilenumber $tile) $ulx $uly $llx $lly; done > tilebounds_hdf.csv

# Combine all PALSAR data into vrt logical mosaic
gdalbuildvrt FNF_2010.vrt *_C
# Warp the vrt
gdalwarp -t_srs ~/modis_sinusoidal.prj -of VRT FNF_2010.vrt FNF_2010_warp.vrt

# Loop over all MODIS tiles and extract 



cat ~/tilebounds_hdf.csv | parallel --bar -j 15 --env tile_extract --colsep " " "tile_extract {1} {2} {3} {4} {5} ../FNF_2010_warp.vrt FNF_MODIS_{1}_50m.tif"

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


