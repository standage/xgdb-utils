#!/usr/bin/env bash

# Copyright (c) 2014, Daniel S. Standage <daniel.standage@gmail.com>
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

# Usage statement
print_usage()
{
  cat << EOF
Usage: xgdbvm-add-generic-track.sh [options] annot.gff3
  Options:
    -d    MySQL database corresponding to the GDB; default is 'GDB001'
    -h    print this help message and exit
    -o    output directory to which intermediate .sql files will be written;
          default is current directory
    -p    MySQL password, if different from system default
    -r    specify length of random ID to autogen for each feature
    -s    directory containing xGDBvm scripts; default is current directory
    -t    name of the MySQL table to be created to contain these annotations;
          default is 'generic';
    -u    MySQL username; default is 'gdbuser'
    -y    data type to parse from input; default is 'region'
EOF
}

# Parse options
DB="GDB001"
OUTPATH="."
PASSWORD="xgdb"
RAND=0
SCRIPTDIR="."
TABLE="generic"
USERNAME="gdbuser"
DATATYPE="region"
while getopts "d:ho:p:r:s:t:u:y:" OPTION
do
  case $OPTION in
    d)
      DB=$OPTARG
      ;;
    h)
      print_usage
      exit 0
      ;;
    o)
      OUTPATH=$OPTARG
      ;;
    p)
      PASSWORD=$OPTARG
      ;;
    r)
      RAND=$OPTARG
      ;;
    s)
      SCRIPTDIR=$OPTARG
      ;;
    t)
      TABLE=$OPTARG
      ;;
    u)
      USERNAME=$OPTARG
      ;;
    y)
      DATATYPE=$OPTARG
      ;;
  esac
done
shift $((OPTIND-1))
if [[ $# != 1 ]]; then
  echo "error: please provide an input file (annotations in GFF3 format)"
  print_usage
  exit 1
fi
GFF3=$1
if [ ! -r $GFF3 ]; then
  echo -e "error: annotation file $GFF3 not readable\n"
  exit 1
fi

# Create data to populate MySQL table
$SCRIPTDIR/xGDB_generic_pgs_from_GFF3.pl -f $DATATYPE -p $TABLE -t $TABLE -o $OUTPATH -r $RAND $GFF3 
if [ ! -s $ALGNSQL ]; then
  echo -e "error: error creating file '$ANNOTSQL'"
  exit 1
fi

# Create MySQL table
cat sql/generic-template.sql | \
    sed -e "s/\${LABEL}/${TABLE}/g" -e "s/\$LABEL/${TABLE}/g" | \
    mysql -u $USERNAME -p$PASSWORD $DB

# Populate table
mysql -u $USERNAME -p$PASSWORD $DB < $OUTPATH/$TABLE.main.sql
mysql -u $USERNAME -p$PASSWORD $DB < $OUTPATH/$TABLE.gpgs.sql
TESTSQL="SELECT COUNT(*) AS 'Annotations uploaded:' from $TABLE"
ANNOTCOUNT=$(echo "$TESTSQL" | mysql -u $USERNAME -p$PASSWORD $DB)
echo $ANNOTCOUNT

