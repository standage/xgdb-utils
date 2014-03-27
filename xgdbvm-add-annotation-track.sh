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
Usage: xgdbvm-add-annotation-track.sh [options] sequences.fa alignments.gsq
  Options:
    -d    MySQL database corresponding to the GDB; default is 'GDB001'
    -h    print this help message and exit
    -o    output directory to which intermediate .sql files will be written;
          default is current directory
    -p    MySQL password, if different from system default
    -s    directory containing xGDBvm scripts; default is '/xGDBvm/scripts'
    -t    name of the MySQL table to be created to contain these annotations;
          default is 'annot';
    -u    MySQL username; default is 'gdbuser'
EOF
}

# Parse options
DB="GDB001"
OUTPATH="."
PASSWORD="xgdb"
SCRIPTDIR="/xGDBvm/scripts"
TABLE="gseg_annot"
USERNAME="gdbuser"
while getopts "d:ho:p:s:t:u:" OPTION
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
    s)
      SCRIPTDIR=$OPTARG
      ;;
    t)
      TABLE=gseg_$OPTARG
      ;;
    u)
      USERNAME=$OPTARG
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
ANNOTSQL="$OUTPATH/${TABLE}.sql"
$SCRIPTDIR/GFF_to_XGDB_Standard.pl -t $TABLE $GFF3 > $ANNOTSQL
if [ ! -s $ALGNSQL ]; then
  echo -e "error: error creating file '$ANNOTSQL'"
  exit 1
fi

# Create MySQL table
cat sql/annot-template.sql | \
    sed -e "s/\${TABLE}/${TABLE}/g" -e "s/\$TABLE/${TABLE}/g" | \
    mysql -u $USERNAME -p$PASSWORD $DB

# Populate table
mysql -u $USERNAME -p$PASSWORD $DB < $ANNOTSQL
TESTSQL="SELECT COUNT(*) AS 'Annotations uploaded:' from $TABLE"
ANNOTCOUNT=$(echo "$TESTSQL" | mysql -u $USERNAME -p$PASSWORD $DB)
echo $ANNOTCOUNT

