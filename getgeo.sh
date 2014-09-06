#!/bin/bash
#===============================================================================
#
# FILE: getgeo.sh
#
# USAGE: ./getgeo.sh
#
# DESCRIPTION: run the script so that the geodata will be downloaded and inserted into your
# database
#
# OPTIONS: ---
# REQUIREMENTS: ---
# BUGS: ---
# NOTES: ---
# AUTHOR: Andreas (aka Harpagophyt )
# COMPANY: <a href="http://forum.geonames.org/gforum/posts/list/926.page" target="_blank" rel="nofollow">http://forum.geonames.org/gforum/posts/list/926.page</a>
# VERSION: 1.4
# CREATED: 07/06/2008
# REVISION: 1.1 2008-06-07 replace COPY continentCodes through INSERT statements.
# 1.2 2008-11-25 Adjusted by Bastiaan Wakkie in order to not unnessisarily
# download.
# 1.3 2011-08-07 Updated script with tree changes. Removes 2 obsolete records from "countryinfo" dump image,
#                updated timeZones table with raw_offset and updated postalcode to varchar(20).
# 1.4 2012-03-31 Don Drake  - Add FKs after data is loaded, also vacuum analyze tables to ensure FK lookups use PK
#			- Don't unzip text files
#			- added DROP TABLE IF EXISTS
# 1.5 2012-06-30 Furdui Marian - added CountryCode to TimeZones and updated geonames.alternatenames to varchar(8000)
#===============================================================================

/bin/date
WORKPATH="${HOME}/geonames/geodata"
TMPPATH="tmp"
PCPATH="pc"
PREFIX="_"
DBHOST="localhost"
DBPORT="5432"
DBUSER="jeck"
FILES="allCountries.zip alternateNames.zip userTags.zip admin1CodesASCII.txt admin2Codes.txt countryInfo.txt featureCodes_en.txt iso-languagecodes.txt timeZones.txt"
psql -U $DBUSER -h $DBHOST -p $DBPORT -c "CREATE DATABASE geonames WITH TEMPLATE = template0 ENCODING = 'UTF8';"
psql -U $DBUSER -h $DBHOST -p $DBPORT geonames <<EOT
DROP TABLE IF EXISTS geoname CASCADE;
CREATE TABLE geoname (
geonameid int,
name varchar(200),
asciiname varchar(200),
alternatenames varchar(18000),
latitude float,
longitude float,
fclass char(1),
fcode varchar(10),
country varchar(2),
cc2 varchar(160),
admin1 varchar(20),
admin2 varchar(80),
admin3 varchar(20),
admin4 varchar(20),
population bigint,
elevation int,
gtopo30 int,
timezone varchar(40),
moddate date
);

DROP TABLE IF EXISTS alternatename;
CREATE TABLE alternatename (
alternatenameId int,
geonameid int,
isoLanguage varchar(7),
alternateName varchar(300),
isPreferredName boolean,
isShortName boolean,
isColloquial boolean,
isHistoric boolean
);

DROP TABLE IF EXISTS countryinfo;
CREATE TABLE "countryinfo" (
iso_alpha2 char(2),
iso_alpha3 char(3),
iso_numeric integer,
fips_code character varying(3),
country character varying(200),
capital character varying(200),
areainsqkm double precision,
population integer,
continent char(2),
tld CHAR(10),
currency_code char(3),
currency_name CHAR(15),
phone character varying(20),
postal character varying(60),
postalRegex character varying(200),
languages character varying(200),
geonameId int,
neighbours character varying(50),
equivalent_fips_code character varying(3)
);



DROP TABLE IF EXISTS iso_languagecodes;
CREATE TABLE iso_languagecodes(
iso_639_3 CHAR(4),
iso_639_2 VARCHAR(50),
iso_639_1 VARCHAR(50),
language_name VARCHAR(200)
);


DROP TABLE IF EXISTS admin1CodesAscii;
CREATE TABLE admin1CodesAscii (
code CHAR(20),
name TEXT,
nameAscii TEXT,
geonameid int
);

DROP TABLE IF EXISTS admin2CodesAscii;
CREATE TABLE admin2CodesAscii (
code CHAR(80),
name TEXT,
nameAscii TEXT,
geonameid int
);

DROP TABLE IF EXISTS featureCodes;
CREATE TABLE featureCodes (
code CHAR(7),
name VARCHAR(200),
description TEXT
);

DROP TABLE IF EXISTS timeZones;
CREATE TABLE timeZones (
countrycode char(2),
timeZoneId VARCHAR(200),
GMT_offset numeric(3,1),
DST_offset numeric(3,1),
raw_offset numeric(3,1)
);

DROP TABLE IF EXISTS continentCodes;
CREATE TABLE continentCodes (
code CHAR(2),
name VARCHAR(20),
geonameid INT
);

DROP TABLE IF EXISTS postalcodes;
CREATE TABLE postalcodes (
countrycode char(2),
postalcode varchar(20),
placename varchar(180),
admin1name varchar(100),
admin1code varchar(20),
admin2name varchar(100),
admin2code varchar(20),
admin3name varchar(100),
admin3code varchar(20),
latitude float,
longitude float,
accuracy smallint
);

ALTER TABLE ONLY countryinfo
ADD CONSTRAINT pk_iso_alpha2 PRIMARY KEY (iso_alpha2);
EOT

# check if needed directories do already exsist
if [ -d "$WORKPATH" ]; then
echo "$WORKPATH exists..."
sleep 0
else
echo "$WORKPATH and subdirectories will be created..."
mkdir -p $WORKPATH
mkdir -p $WORKPATH/$TMPPATH
mkdir -p $WORKPATH/$PCPATH
echo "created $WORKPATH"
fi
echo
echo ",---- STARTING (downloading, unpacking and preparing)"
cd $WORKPATH/$TMPPATH
for i in $FILES
do
wget -N -q "http://download.geonames.org/export/dump/$i" # get newer files
if [ $i -nt $PREFIX$i ] || [ ! -e $PREFIX$i ] ; then
	cp -p $i $PREFIX$i
	if [ `expr index zip $i` -eq 1 ]; then
		unzip -o -u -q $i
	fi
	case "$i" in
		iso-languagecodes.txt)
			tail -n +2 iso-languagecodes.txt > iso-languagecodes.txt.tmp;
		;;
		countryInfo.txt)
			grep -v '^#' countryInfo.txt | head -n -2 > countryInfo.txt.tmp;
		;;
		timeZones.txt)
			tail -n +2 timeZones.txt > timeZones.txt.tmp;
		;;
	esac
	echo "| $i has been downloaded";
else
	echo "| $i is already the latest version"
fi
done
# download the postalcodes. You must know yourself the url
cd $WORKPATH/$PCPATH
wget -q -N "http://download.geonames.org/export/zip/allCountries.zip"
if [ $WORKPATH/$PCPATH/allCountries.zip -nt $WORKPATH/$PCPATH/allCountries$PREFIX.zip ] || [ ! -e $WORKPATH/$PCPATH/allCountries.zip ]; then
echo "Attempt to unzip $WORKPATH/$PCPATH/allCountries.zip file..."
unzip -o -u -q $WORKPATH/$PCPATH/allCountries.zip
cp -p $WORKPATH/$PCPATH/allCountries.zip $WORKPATH/$PCPATH/allCountries$PREFIX.zip
echo "| ....zip has been downloaded"
else
echo "| ....zip is already the latest version"
fi

echo "+---- FILL DATABASE ( this takes 2 days on my machine )"

psql -e -U $DBUSER -h $DBHOST -p $DBPORT geonames <<EOT
copy geoname (geonameid,name,asciiname,alternatenames,latitude,longitude,fclass,fcode,country,cc2,admin1,admin2,admin3,admin4,population,elevation,gtopo30,timezone,moddate) from '${WORKPATH}/${TMPPATH}/allCountries.txt' null as '';
ALTER TABLE ONLY geoname
ADD CONSTRAINT pk_geonameid PRIMARY KEY (geonameid);
vacuum analyze verbose geoname;

copy postalcodes (countrycode,postalcode,placename,admin1name,admin1code,admin2name,admin2code,admin3name,admin3code,latitude,longitude,accuracy) from '${WORKPATH}/${PCPATH}/allCountries.txt' null as '';
vacuum analyze verbose postalcodes;

copy timeZones (countrycode,timeZoneId,GMT_offset,DST_offset,raw_offset) from '${WORKPATH}/${TMPPATH}/timeZones.txt.tmp' null as '';
vacuum analyze verbose timeZones;

copy featureCodes (code,name,description) from '${WORKPATH}/${TMPPATH}/featureCodes_en.txt' null as '';
vacuum analyze verbose featureCodes;

copy admin1CodesAscii (code,name,nameAscii,geonameid) from '${WORKPATH}/${TMPPATH}/admin1CodesASCII.txt' null as '';
vacuum analyze verbose admin1CodesAscii;

copy admin2CodesAscii (code,name,nameAscii,geonameid) from '${WORKPATH}/${TMPPATH}/admin2Codes.txt' null as '';
vacuum analyze verbose admin2CodesAscii;

copy iso_languagecodes (iso_639_3,iso_639_2,iso_639_1,language_name) from '${WORKPATH}/${TMPPATH}/iso-languagecodes.txt.tmp' null as '';
vacuum analyze verbose iso_languagecodes;

copy countryInfo (iso_alpha2,iso_alpha3,iso_numeric,fips_code,country,capital,areainsqkm,population,continent,tld,currency_code,currency_name,phone,postal,postalRegex,languages,geonameid,neighbours,equivalent_fips_code) from '${WORKPATH}/${TMPPATH}/countryInfo.txt.tmp' null as '';
ALTER TABLE ONLY countryinfo
ADD CONSTRAINT fk_geonameid FOREIGN KEY (geonameid) REFERENCES geoname(geonameid);
vacuum analyze verbose countryInfo;

copy alternatename (alternatenameid,geonameid,isoLanguage,alternateName,isPreferredName,isShortName,isColloquial,isHistoric) from '${WORKPATH}/${TMPPATH}/alternateNames.txt' null as '';
ALTER TABLE ONLY alternatename
ADD CONSTRAINT pk_alternatenameid PRIMARY KEY (alternatenameid);
ALTER TABLE ONLY alternatename
ADD CONSTRAINT fk_geonameid FOREIGN KEY (geonameid) REFERENCES geoname(geonameid);
vacuum analyze verbose alternatename;

INSERT INTO continentCodes VALUES ('AF', 'Africa', 6255146);
INSERT INTO continentCodes VALUES ('AS', 'Asia', 6255147);
INSERT INTO continentCodes VALUES ('EU', 'Europe', 6255148);
INSERT INTO continentCodes VALUES ('NA', 'North America', 6255149);
INSERT INTO continentCodes VALUES ('OC', 'Oceania', 6255150);
INSERT INTO continentCodes VALUES ('SA', 'South America', 6255151);
INSERT INTO continentCodes VALUES ('AN', 'Antarctica', 6255152);
vacuum analyze verbose continentCodes;

CREATE INDEX index_countryinfo_geonameid ON countryinfo USING hash (geonameid);
CREATE INDEX index_alternatename_geonameid ON alternatename USING hash (geonameid);
EOT
echo "'----- DONE ( have fun... )"
/bin/date
