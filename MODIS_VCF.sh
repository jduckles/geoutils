

cd /data/ddn/Congo
find $(pwd) -name "*TRE*.tif.gz" | parallel -j 24 --bar "gzip -dc {} > TRE_uncompressed/{/.}"


### Congo Mosaic

# Rough bounding rectangle around Congo
mbrminx=6.4875074606426
mbrmaxy=5.82675640853353
mbrmaxx=33.3019150169375
mbrminy=-12.239581581588
bbox="$mbrminx $mbrmaxy $mbrmaxx $mbrminy"

# Annual mosaics
## Mosaic global 166 tiles for each of 13 years

# Make years data driven by what is in the directory.
YEARS=$(ls *_TRE.*.tif | sort | cut -d "." -f 2 | uniq)
for YEAR in ${YEARS}; do
    if [[ -f  VCF_global_${YEAR}.vrt ]] 
        then
            echo "Skipping VCF_global_${YEAR}.vrt, we already made it."
        else
            gdalbuildvrt VCF_global_${YEAR}.vrt *_TRE.${YEAR}*.tif;
    fi
    #gdal_translate -co COMPRESS=LZW -projwin $bbox VCF_global_${YEAR}.vrt VCF_congo_${YEAR}.tif
    gdal_translate -co COMPRESS=LZW -projwin $bbox VCF_global_${YEAR}.vrt VCF_congo_${YEAR}.tif

done


for i in *congo*.tif; do r.in.gdal $i out=${i/.tif/}; done

r.series input=$(g.mlist rast pat=VCF* sep=,) output=VCF_slope_2000_2010 method=slope
r.series input=$(g.mlist rast pat=VCF* sep=,) output=VCF_R2_2000_2010 method=detcoeff
