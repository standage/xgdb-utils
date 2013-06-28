#!/usr/bin/env bash

# Copyright (c) 2013, Daniel S. Standage <daniel.standage@gmail.com>
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
Usage: xgdbvm-add-alignment-track.sh [options] sequences.fa alignments.gsq
  Options:
    -d    MySQL database corresponding to the GDB; default is 'GDB001'
    -h    print this help message and exit
    -l    label for naming the MySQL tables to which sequence and alignments
          will be loaded; default is 'tsa', which creates tables 'tsa',
          'gseg_tsa_good_pgs', 'gseg_tsa_good_pgs_exons', and
          'gseg_tsa_good_pgs_introns'
    -o    output directory to which intermediate .sql files will be written;
          default is current directory
    -p    MySQL password, if different from system default
    -s    directory containing xGDBvm scripts; default is '/xGDBvm/scripts'
    -t    sequence type; valid values are 'est', 'cdna' (for full-length cDNAs),
          'tsa' (for assembled transcripts), and 'prot' (for proteins); default
          is 'tsa'; transcript alignments are assumed to be in GeneSeqer format,
          and protein alignments are assumed to be in GenomeThreader format
    -u    MySQL username; default is 'gdbuser'
EOF
}

# Parse options
DB="GDB001"
LABEL="tsa"
OUTPATH="."
PASSWORD="xgdb"
SCRIPTDIR="/xGDBvm/scripts"
TYPE="TSA"
USERNAME="gdbuser"
while getopts "d:hl:o:p:s:t:u:" OPTION
do
  case $OPTION in
    d)
      DB=$OPTARG
      ;;
    h)
      print_usage
      exit 0
      ;;
    l)
      LABEL=$OPTARG
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
      TYPE=$OPTARG
      if [ $TYPE != "cdna" ] && [ $TYPE != "est" ] && [ $TYPE != "tsa" ] && \
         [ $TYPE != "prot" ];
      then
        echo "Unsupported type '$TYPE'"
        exit 1
      fi
      ;;
    u)
      USERNAME=$OPTARG
      ;;
  esac
done
shift $((OPTIND-1))
if [[ $# != 2 ]]; then
  echo -e "error: please provide 2 input files (sequence file in Fasta format\
           and alignment file in GeneSeqer/GenomeThreader format)\n"
  print_usage
  exit 1
fi
FASTA=$1
ALGN=$2
if [ ! -r $FASTA ]; then
  echo -e "error: sequence file $FASTA not readable\n"
  exit 1
fi

if [ ! -r $ALGN ]; then
  echo -e "error: alignment file $ALGN not readable\n"
  exit 1
fi

# SQL filenames
SEQSQL="$OUTPATH/${LABEL}.sql"
ALGNSQL="$OUTPATH/gseg_${LABEL}_good_pgs.sql"

# Parse sequences
$SCRIPTDIR/xGDBload_SeqFromFasta.pl $LABEL $FASTA > $SEQSQL
if [ ! -s $SEQSQL ]; then
  echo -e "error: error creating file '$SEQSQL'"
  exit 1
fi

# Parse alignments
SCRIPT=$SCRIPTDIR/xGDBload_PgsFromGSQ.pl
if [ $TYPE = "prot" ];
then
  SCRIPT=$SCRIPTDIR/xGDBload_PgsFromGTH.pl
fi
$SCRIPT -t "gseg_${LABEL}_good_pgs" $ALGN > $ALGNSQL
if [ ! -s $ALGNSQL ]; then
  echo -e "error: error creating file '$ALGNSQL'"
  exit 1
fi

# Create MySQL tables
cat sql/${TYPE}-template.sql | \
    sed -e "s/\${LABEL}/${LABEL}/g" -e "s/\$LABEL/${LABEL}/g" | \
    mysql -u $USERNAME -p$PASSWORD $DB

# Populate sequence table
mysql -u $USERNAME -p$PASSWORD $DB < $SEQSQL
TESTSQL="SELECT COUNT(*) AS 'Sequences uploaded:' from $LABEL"
SEQCOUNT=$(echo "$TESTSQL" | mysql -u $USERNAME -p$PASSWORD $DB)
echo $SEQCOUNT

# Populate alignment tables
mysql -u $USERNAME -p$PASSWORD $DB < $ALGNSQL
TESTSQL="SELECT COUNT(*) AS 'Alignments uploaded:' from gseg_${LABEL}_good_pgs"
ALGNCOUNT=$(echo "$TESTSQL" | mysql -u $USERNAME -p$PASSWORD $DB)
echo $ALGNCOUNT
