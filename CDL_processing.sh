# Bring in CDL data to grass with a pointer to it.

# bring in MODIS
gdalwarp -t_srs aea.prj -ts 500 500 band1.tif band1_warp.tif
r.in.gdal band1_warp.tif out=MOD09A1_band1

# bring in CDL 
r.external 2013.tif out=2013_cdl


gdalwarp -t_srs aea.prj -tr 2400 2400 band1.tif band1_warp.tif
r.in.gdal --o band1_warp.tif out=MOD09A1_band1
g.region align=MOD09A1_band1
r.resamp.stats --o input=2013_cdl output=2013_cdl_mode_500m method=mode


r.out.gdal 2013_cdl_mode_500m out=2013_cdl_mode.tif createopt="COMPRESS=LZW"
gdalwarp -t_srs modis.prj -tr 2400 2400 2013_cdl_mode.tif 2013_mode_modis.tif

