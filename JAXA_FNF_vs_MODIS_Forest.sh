#!/bin/bash
# Jonah Duckles (c) 2014

# This will not run cleanly as a script right at the moment.
# Mosaic all FNF PALSAR images into one virtual mosiac'd image.

YEAR=2008
YEAR_short=${YEAR:2:4}


#### Prep JAXA FNF Data set
for i in *.tar.gz; do tar -xzvf $i; done
# Create a vrt of all tiles
gdalbuildvrt MOSAIC_${YEAR_short}.vrt *${YEAR_short}_C
# Build real mosaic'd tif from vrt
gdal_translate -co COMPRESS=LZW MOSAIC_${YEAR_short}.vrt FNF_${YEAR_short}.tif
# Warp FNF map to MCD12C1 projection
gdalwarp -t_srs modis.prj FNF_${YEAR}.tif FNF_${YEAR}_warped.tif


#### Prep MODIS MCD12C1 product
### Generate Geotiffs from HDFs
~/git/geoutils/MCD12C12tiff.sh MCD12C1.A${YEAR}*.hdf

# Enter grass session and import all MCD12C1 tifs
for i in *A${YEAR}*.tif; do 
    r.in.gdal $i out=${i/.tif}
done

# Select forest areas from MCD12C1 categories 1-5
## Metadata: https://lpdaac.usgs.gov/products/modis_products_table/mcd12c1
#Class	IGBP (Type 1)	                    UMD (Type 2)	        LAI/fPAR (Type 3)
#0	 Water	                            Water	                Water
#1	 Evergreen Needleleaf forest	    Evergreen Needleleaf forest	Grasses/Cereal crops
#2	 Evergreen Broadleaf forest	    Evergreen Broadleaf forest	Shrubs
#3	 Deciduous Needleleaf forest	    Deciduous Needleleaf forest	Broad-leaf crops
#4	 Deciduous Broadleaf forest	    Deciduous Broadleaf forest	Savanna
#5	 Mixed forest	                    Mixed forest	        Evergreen Broadleaf forest
#6	 Closed shrublands	            Closed shrublands	        Deciduous Broadleaf forest
#7	 Open shrublands	            Open shrublands	        Evergreen Needleleaf forest
#8	 Woody savannas	                    Woody savannas	        Deciduous Needleleaf forest
#9	 Savannas	                    Savannas	                Non-vegetated
#10	 Grasslands	                    Grasslands	                Urban
#11	 Permanent wetlands	  	  
#12	 Croplands	                    Croplands	  
#13	 Urban and built-up	            Urban and built-up	  
#14	 Cropland/Natural vegetation mosaic	  	  
#15	 Snow and ice	  	  
#16	 Barren or sparsely vegetated	    Barren or sparsely vegetated	  
#255	 Fill Value/Unclassified	    Fill Value/Unclassified	 Fill Value/Unclassified

### Create binary forest map
g.region align=MCD12C1.A${YEAR}_Majority_Land_Cover_Type_1
r.mapcalc forest_${YEAR}="if(MCD12C1.A${YEAR}_Majority_Land_Cover_Type_1 >=1 && MCD12C1.A${YEAR}_Majority_Land_Cover_Type_1 <=5, 1, null())"


### Compute total forest percent for year 2001-2012
g.region rast=MCD12C1.A${YEAR}_Majority_Land_Cover_Type_1
for YEAR in $(seq 2001 2012); do 
# Sum all forest categories and convert to floating point representation
r.mapcalc pct_forest_${YEAR}="float( (float(MCD12C1.A${YEAR}_Land_Cover_Type_1_Percent.1) + float(MCD12C1.A${YEAR}_Land_Cover_Type_1_Percent.2) + float(MCD12C1.A${YEAR}_Land_Cover_Type_1_Percent.3) + float(MCD12C1.A${YEAR}_Land_Cover_Type_1_Percent.4) + float(MCD12C1.A${YEAR}_Land_Cover_Type_1_Percent.5)) / float(100) )"
done

# Put together string of raster names from previous step
forest_pct=$(echo pct_forest_{2001..2012} | sed 's/ /,/g')
# Compute slope and stdev
r.series input=${forest_pct} output=forest_slope_2001_2012 method=slope

r.out.gdal forest_slope_2001_2012 out=forest_slope_2001_2012.tif create="COMPRESS=LZW"

## Build display output
d.erase
d.rast forest_slope_2001_2012
d.vect countries fcolor=none type=boundary color=gray width=0.01
d.legend forest_slope_2001_2012
d.out.file -c out=forest_slope_2001_2012 format=jpg

# Create bin map for FNF
g.region align=FNF_${YEAR}
# Reclass FNF_2008
# - FNF_reclass.txt
# 1 = 1
# 2 3 = 0
# 0 = NULL
r.reclass --o input=FNF_2008 output=FNF_2008_bin rules=FNF_reclass.txt 

# Create palsar pct forest map

#   1. resample stats from fine resolution raster to coarse
g.region align=MCD12C1.A${YEAR}_Majority_Land_Cover_Type_1
r.resamp.stats --o input=FNF_${YEAR}_bin output=fnf_palsar_pct_forest method=average

#   2. divide by max sum to get pct

#   3. difference the two maps
r.mapcalc diff_forest="pct_forest_${YEAR} - fnf_palsar_pct_forest"

r.colors diff_forest color=differences
d.rast diff_forest 
d.vect countries fcolor=none type=boundary
d.vect forest_2008v fcolor=none color=yellow
d.legend diff_forest
d.out.file --o -c out=diff_forest type=jpg
d.out.rast --o diff_forest out=diff_forest.tif create="COMPRESS=LZW"

