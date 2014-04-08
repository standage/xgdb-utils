#!/usr/bin/env perl

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

use strict;
use Getopt::Long;
use List::Util qw(min max);

sub print_usage
{
  my $outstream = ($_[0]) ? $_[0] : \*STDERR;
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

my %idfeats;

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

  # Handle features with IDs (potential multifeatures) later
  my ($id) = $fields[8] =~ m/ID=([^;]+)/;
  if($id)
  {
    $idfeats{ $id } = [] unless($idfeats{$id});
    push($idfeats{$id}, \@fields);
    next;
  }

  # Handle features without IDs (cannot be multifeatures)
  $id = sprintf("%s_%lu-%lu", $fields[0], $fields[3], $fields[4]);
  printf($MAIN "INSERT INTO %s (gi, acc, description) VALUES ('%s', '%s', '%s');\n", $table, $id, $id, $fields[8]);
  printf($GPGS "INSERT INTO %s_good_pgs (gi, gseg_gi, l_pos, r_pos, pgs, pgs_lpos, pgs_rpos) ".
               "VALUES ('%s', '%s', %lu, %lu, '%lu %lu', 1, %lu);\n", $table, $id, $fields[0], $fields[3], $fields[4], $fields[3], $fields[4], $fields[4] - $fields[3] + 1);
  printf($GPGS "INSERT INTO %s_good_pgs_exons (pgs_uid, num, pgs_start, pgs_stop, gseg_start, gseg_stop) ".
               "VALUES (LAST_INSERT_ID(), 1, 1, %lu, %lu, %lu);\n", $table, $fields[4] - $fields[3] + 1, $fields[3], $fields[4]);
}
close($GFF3);

while(my($id, $entries) = each(%idfeats))
{
  my @sorted_entries = sort { $a->[3] <=> $b->[3] or $a->[4] <=> $b->[4] } @$entries;
  
  my $nentries = scalar(@sorted_entries);
  my $structure = "";
  my $cumlength = 0;
  my @exons;
  my @introns;

  my ($start, $end) = (0, 0);
  for(my $i = 0; $i < $nentries; $i++)
  {
    my $entry = $sorted_entries[$i];
    if($i == 0)
    {
      $start = $entry->[3];
      $end = $entry->[4];
    }
    else
    {
      $start = min($start, $entry->[3]);
      $end = max($end, $entry->[4]);
    }

    $structure .= "," if($i > 0);
    $structure .= sprintf("%lu  %lu", $entry->[3], $entry->[4]);
    my $entrylength = $entry->[4] - $entry->[3] + 1;
    push(@exons, [$cumlength + 1, $cumlength + $entrylength, $entry->[3], $entry->[4]]);
    $cumlength += $entrylength;

    if($i + 1 < $nentries)
    {
      my $nextentry = $sorted_entries[$i+1];
      push(@introns, [$entry->[4] + 1, $nextentry->[3] - 1]);
    }
  }

  printf($MAIN "INSERT INTO %s (gi, acc, description) VALUES ('%s', '%s', '%s');\n", $table, $id, $id, $sorted_entries[0]->[8]);
  printf($GPGS "INSERT INTO %s_good_pgs (gi, gseg_gi, l_pos, r_pos, pgs, pgs_lpos, pgs_rpos) ".
               "VALUES ('%s', '%s', %lu, %lu, '%s', 1, %lu);\n", $table, $id, $sorted_entries[0]->[0], $start, $end, $structure, $cumlength);
  printf($GPGS "INSERT INTO %s_good_pgs_exons (pgs_uid, num, pgs_start, pgs_stop, gseg_start, gseg_stop) VALUES ", $table);
  for(my $i = 0; $i < scalar(@exons); $i++)
  {
    my $exon = $exons[$i];
    printf($GPGS ", ") if($i > 0);
    printf($GPGS "(LAST_INSERT_ID(), %d, %lu, %lu, %lu, %lu)", $i+1, $exon->[0], $exon->[1], $exon->[2], $exon->[3]);
  }
  printf($GPGS ";\n");

  next if(scalar(@introns) == 0);
  printf($GPGS "INSERT INTO %s_good_pgs_introns (pgs_uid, num, gseg_start, gseg_stop) VALUES ", $table);
  for(my $i = 0; $i < scalar(@introns); $i++)
  {
    my $intron = $introns[$i];
    printf($GPGS ", ") if($i > 0);
    printf($GPGS "(LAST_INSERT_ID(), %d, %lu, %lu)", $i+1, $intron->[0], $intron->[1]);
  }
  printf($GPGS ";\n");
}


printf($MAIN "COMMIT;\n");
printf($GPGS "COMMIT;\n");

close($MAIN);
close($GPGS);

