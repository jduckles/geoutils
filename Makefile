MODIS_TILES = /data/ddn/jduckles/modis_tiles
YEARS = 2007 2008 2009 2010
PALSAR_SOURCE = /data/ddn/PALSAR/PALSAR_2014/Rawdata_new
PALSAR_OUTPUT = /data/scratch/jduckles/PALSAR

lib/tilebounds.csv:
	bin/tilebounds $(MODIS_TILES) > tilebounds.csv

$(PALSAR_SOURCE)/output.vrt: 
 	
