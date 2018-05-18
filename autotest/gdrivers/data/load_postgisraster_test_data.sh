#!/bin/bash
# If you are working in a Linux/Mac enviroment, execute this script with "sh load_postgisraster_test_data"
# 
# TODO: a Python version of this script, to have a system-independent script
# 
# Load test data in PostGIS
#
# NOTE 1: raster2pgsql doesn't allow WKT Raster tables (raster_columns, 
# raster_overviews) and data tables in different schemas. If you want to store
# your data in a different schema from the schema where WKT Raster tables are, 
# you'll have to change the sql files generated by raster2pgsql by hand.
#
# NOTE 2: The execution of psql calls will ask you for the password of the user
# USER_NAME. If you want to avoid this, you'll have to modify the PostgreSQL
# configuration file (pg_hba.conf) to allow the user "trust" authentication
# method. See http://www.postgresql.org/docs/8.4/interactive/auth-pg-hba-conf.html

# CHANGE THIS TO MATCH YOUR ENVIROMENT

SQL_OUTPUT_FILES_PATH=/tmp/gdal-autotest-pgraster

if test "$DATABASE_NAME" = ""; then
    DATABASE_NAME=autotest
fi

if test "$DATABASE_SCHEMA" = ""; then
    DATABASE_SCHEMA=gis_schema
fi

SCRIPT_DIR=$(dirname "$0")
case $SCRIPT_DIR in
    "/"*)
        ;;
    ".")
        SCRIPT_DIR=$(pwd)
        ;;
    *)
        SCRIPT_DIR=$(pwd)/$(dirname "$0")
        ;;
esac

echo psql  -d $DATABASE_NAME -c "DROP SCHEMA $DATABASE_SCHEMA CASCADE"
psql  -d $DATABASE_NAME -c "DROP SCHEMA $DATABASE_SCHEMA CASCADE"
psql  -d $DATABASE_NAME -c "CREATE SCHEMA $DATABASE_SCHEMA"

mkdir -p "$SQL_OUTPUT_FILES_PATH"
raster2pgsql -l 2,4,8 -t 100x100 -s 26711 -I -M $SCRIPT_DIR/utm.tif $DATABASE_SCHEMA.utm > "$SQL_OUTPUT_FILES_PATH/utm_level2-8.sql"

psql  -d $DATABASE_NAME -f "$SQL_OUTPUT_FILES_PATH/utm_level2-8.sql"

# Out-db support is not working in WKT Raster right now (August 17th 2009). To allow out-db rasters in AddRasterColumns function, you must change
# the $WKTRASTER_SRC/rt_pg/rtpostgis.sql code, comment lines 532 - 535 (verify out_db), and execute rtpostgis.sql again in the same database
#psql  -d $DATABASE_NAME -f $SQL_OUTPUT_FILES_PATH/utm_outdb_level1.sql

raster2pgsql -l 2,4,8 -t 40x20 -s 4326 -I -M $SCRIPT_DIR/small_world.tif $DATABASE_SCHEMA.small_world > "$SQL_OUTPUT_FILES_PATH/small_world_level2-8.sql"

psql  -d $DATABASE_NAME -f "$SQL_OUTPUT_FILES_PATH/small_world_level2-8.sql"

raster2pgsql -l 2 -t 40x40 -s 4326 -I -M $SCRIPT_DIR/small_world.tif $DATABASE_SCHEMA.small_world_noid > "$SQL_OUTPUT_FILES_PATH/small_world_level2_noid.sql"
raster2pgsql -l 2 -t 40x40 -s 4326 -I -M $SCRIPT_DIR/small_world.tif $DATABASE_SCHEMA.small_world_serial > "$SQL_OUTPUT_FILES_PATH/small_world_level2_serial.sql"
raster2pgsql -l 2 -t 40x40 -s 4326 -I -M $SCRIPT_DIR/small_world.tif $DATABASE_SCHEMA.small_world_unique > "$SQL_OUTPUT_FILES_PATH/small_world_level2_unique.sql"
raster2pgsql -C -l 2 -t 40x40 -s 4326 -M $SCRIPT_DIR/small_world.tif $DATABASE_SCHEMA.small_world_constraint > "$SQL_OUTPUT_FILES_PATH/small_world_level2_constraint.sql"
raster2pgsql -C -l 2 -t 40x40 -s 4326 -I -M $SCRIPT_DIR/small_world.tif $DATABASE_SCHEMA.small_world_constraint_with_spi > "$SQL_OUTPUT_FILES_PATH/small_world_level2_constraint_with_spi.sql"
raster2pgsql -C -l 2 -R -t 40x40 -s 4326 -I -M $SCRIPT_DIR/small_world.tif $DATABASE_SCHEMA.small_world_outdb_constraint > "$SQL_OUTPUT_FILES_PATH/small_world_outdb_constraint.sql"

psql  -d $DATABASE_NAME -f "$SQL_OUTPUT_FILES_PATH/small_world_level2_noid.sql"
psql  -d $DATABASE_NAME -c "ALTER TABLE $DATABASE_SCHEMA.small_world_noid DROP COLUMN rid"

psql  -d $DATABASE_NAME -f "$SQL_OUTPUT_FILES_PATH/small_world_level2_serial.sql"
psql  -d $DATABASE_NAME -c "DROP SEQUENCE small_world_serial_serialid_sequence"
psql  -d $DATABASE_NAME -c "\
ALTER TABLE $DATABASE_SCHEMA.small_world_serial ADD COLUMN serialid integer; \
UPDATE $DATABASE_SCHEMA.small_world_serial SET serialid = rid; \
ALTER TABLE $DATABASE_SCHEMA.small_world_serial DROP COLUMN rid; \
CREATE SEQUENCE small_world_serial_serialid_sequence INCREMENT 1 START 51; \
ALTER TABLE $DATABASE_SCHEMA.small_world_serial ALTER COLUMN serialid SET DEFAULT nextval('small_world_serial_serialid_sequence'::regclass);"

psql  -d $DATABASE_NAME -f "$SQL_OUTPUT_FILES_PATH/small_world_level2_unique.sql"
psql  -d $DATABASE_NAME -c "\
ALTER TABLE $DATABASE_SCHEMA.small_world_unique ADD COLUMN uniq integer; \
UPDATE $DATABASE_SCHEMA.small_world_unique SET uniq = rid; \
ALTER TABLE $DATABASE_SCHEMA.small_world_unique DROP COLUMN rid; \
ALTER TABLE $DATABASE_SCHEMA.small_world_unique ADD UNIQUE (uniq);"

psql  -d $DATABASE_NAME -f "$SQL_OUTPUT_FILES_PATH/small_world_level2_constraint.sql"

psql  -d $DATABASE_NAME -f "$SQL_OUTPUT_FILES_PATH/small_world_level2_constraint_with_spi.sql"

psql  -d $DATABASE_NAME -f "$SQL_OUTPUT_FILES_PATH/small_world_outdb_constraint.sql"

rm -rf "$SQL_OUTPUT_FILES_PATH"
