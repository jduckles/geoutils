#!/bin/bash
# Jonah Duckles (c) 2014

# This will not run cleanly as a script right at the moment.
# Mosaic all FNF PALSAR images into one virtual mosiac'd image.

YEAR=2008
YEAR_short=${YEAR:2:4}

for i in *.tar.gz; do tar -xzvf $i; done
gdalbuildvrt MOSAIC_${YEAR_short}.vrt *${YEAR_short}_C
gdal_translate -co COMPRESS=LZW MOSAIC_${YEAR_short}.vrt FNF_${YEAR_short}.tif

~/git/geoutils/MCD12C12tiff.sh MCD12C1.A${YEAR}*.hdf

# Enter grass session and import all 
for i in *A${YEAR}*.tif; do 
    r.in.gdal $i out=${i/.tif}
done

# Select forest areas from MCD12C1 categories 1-5
g.region align=MCD12C1.A${YEAR}_Majority_Land_Cover_Type_1
r.mapcalc forest_${YEAR}="if(MCD12C1.A${YEAR}_Majority_Land_Cover_Type_1 >=1 && MCD12C1.A${YEAR}_Majority_Land_Cover_Type_1 <=5, 1, null())"

# Sum all forest categories and convert to floating point representation
r.mapcalc pct_forest_${YEAR}="float( (float(MCD12C1.A${YEAR}_Land_Cover_Type_1_Percent.1) + float(MCD12C1.A${YEAR}_Land_Cover_Type_1_Percent.2) + float(MCD12C1.A${YEAR}_Land_Cover_Type_1_Percent.3) + float(MCD12C1.A${YEAR}_Land_Cover_Type_1_Percent.4) + float(MCD12C1.A${YEAR}_Land_Cover_Type_1_Percent.5)) / float(100) )"

# Warp FNF map to MCD12C1 projection
gdalwarp -t_srs modis.prj FNF_${YEAR}.tif FNF_${YEAR}_warped.tif

# Create bin map for FNF
g.region align=FNF_${YEAR}
r.mapcalc FNF_${YEAR}_bin="if(FNF_${YEAR} == 1, 1, null())"

# Create palsar pct forest map

#   1. resample stats from fine resolution raster to coarse
g.region align=MCD12C1.A${YEAR}_Majority_Land_Cover_Type_1
r.resamp.stats --o input=FNF_${YEAR}_bin output=cnt_forest_palsar_to_MODIS method=sum

#   2. divide by max sum to get pct
g.region align=forest_YEAR
eval $(r.univar -g cnt_forest_palsar_to_MODIS)
r.mapcalc fnf_palsar_pct_forest="float(cnt_forest_palsar_to_MODIS/$max)"

#   3. difference the two maps
r.mapcalc diff_forest="pct_forest_${YEAR} - fnf_palsar_pct_forest"

r.colors diff_forest color=differences
d.rast diff_forest 
d.vect countries fcolor=none type=boundary
d.legend diff_forest

