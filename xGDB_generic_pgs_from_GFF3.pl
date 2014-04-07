#!/usr/bin/env perl
use strict;
use Getopt::Long;

sub print_usage
{
  my $outstream = shift(@_) or sub { return \*STDERR };
  printf($outstream "
Given a GFF3 file, create SQL for populating MySQL tables for a generic xGDBvm
feature track.

Usage: perl $0 [options] annot.gff3
  Options:
    h|help:          print this help message and exit
    p|prefix=STRING: prefix for output files; default is 'track'
    T|table=STRING:  prefix for MySQL tables to be populated; default is
                     'region'
    t|type=STRING:   feature type of interest; default is 'region'

");
}

my $prefix = "track";
my $table = "region";
my $type = "region";
GetOptions
(
  "h|help"     => sub{ print_usage(\*STDOUT); exit(0); },
  "p|prefix=s" => \$prefix,
  "T|table=s"  => \$table,
  "t|type=s"   => \$type,
);

my $mainout = "$prefix.main.sql";
my $gpgsout = "$prefix.gpgs.sql";
open(my $MAIN, ">", $mainout) or die("unable to open file $mainout");
open(my $GPGS, ">", $gpgsout) or die("unable to open file $gpgsout");

printf($MAIN "BEGIN;\n");
printf($GPGS "BEGIN;\n");

my $gff3in = shift(@ARGV) or do
{
  printf(STDERR "Error: please provide GFF3 input file\n");
  print_usage();
  exit(1);
};
open(my $GFF3, "<", $gff3in) or die("unable to open GFF3 file '$gff3in'");
while(my $line = <$GFF3>)
{
  next if($line =~ m/^#/ or $line =~ m/^\s*$/);

  chomp($line);
  my @fields = split(/\t/, $line);
  next unless($fields[2] eq $type);

  my $id = sprintf("%s_%lu-%lu", $fields[0], $fields[3], $fields[4]);
  printf($MAIN "INSERT INTO %s (gi, acc, description) VALUES ('%s', '%s', '%s');\n", $table, $id, $id, $fields[8]);
  printf($GPGS "INSERT INTO %s_good_pgs (gi, gseg_gi, l_pos, r_pos, pgs, pgs_lpos, pgs_rpos) ".
               "VALUES ('%s', '%s', %lu, %lu, '%lu %lu', 1, %lu);\n", $table, $id, $fields[0], $fields[3], $fields[4], $fields[3], 
$fields[4], $fields[4] - $fields[3] + 1);
  printf($GPGS "INSERT INTO %s_good_pgs_exons (pgs_uid, num, pgs_start, pgs_stop, gseg_start, gseg_stop) ".
               "VALUES (LAST_INSERT_ID(), 1, 1, %lu, %lu, %lu);\n", $table, $fields[4] - $fields[3] + 1, $fields[3], $fields[4]);
}
close($GFF3);

printf($MAIN "COMMIT;\n");
printf($GPGS "COMMIT;\n");

close($MAIN);
close($GPGS);

