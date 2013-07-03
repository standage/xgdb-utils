#!/usr/bin/env perl
use strict;

sub mrna_to_gff3
{
  my $mrna = shift(@_);
  my $OUT = shift(@_);
  
  my $strand = $mrna->{"strand"} eq "f" ? "+" : "-";
  my $mrnaid = $mrna->{"geneId"};
  
  my @gff3 = ($mrna->{"gseg_gi"}, "xGDBvm", "mRNA", $mrna->{"l_pos"},
              $mrna->{"r_pos"}, ".", $strand, ".", "ID=$mrnaid");
  print $OUT join("\t", @gff3), "\n";
  
  @gff3[2..4] = ("start_codon", $mrna->{"CDSstart"}, $mrna->{"CDSstart"} + 2);
  if($strand eq "-")
  {
    @gff3[3..4] = ($mrna->{"CDSstart"} - 2, $mrna->{"CDSstart"});
  }
  $gff3[8] = "Parent=$mrnaid";
  print $OUT join("\t", @gff3), "\n";
  
  @gff3[2..4] = ("stop_codon", $mrna->{"CDSstop"} - 2, $mrna->{"CDSstop"});
  if($strand eq "-")
  {
    @gff3[3..4] = ($mrna->{"CDSstop"}, $mrna->{"CDSstop"} + 2);
  }
  print $OUT join("\t", @gff3), "\n";
  
  my $exonstring = $mrna->{"gene_structure"};
  $exonstring =~ s/^complement\((.+)\)$/$1/;
  $exonstring =~ s/^join\((.+)\)$/$1/;
  $exonstring =~ s/&[gl];//g;
  my @exons = split(/\s*,\s*/, $exonstring);

  foreach my $exon(@exons)
  {
    @gff3[3..4] = split(/../, $exon);
    $gff3[2] = "exon";
    print $OUT join("\t", @gff3), "\n";
  }
}

sub gene_to_gff3
{
  my $mrnalist = shift(@_);
  my $OUT = shift(@_);
  
  my $seqid = "";
  my $geneid = "";
  my $strand = "+";
  my($start, $end) = (0, 0);
  foreach my $mrna(@$mrnalist)
  {
    if($seqid eq "")
    {
      $seqid = $mrna->{"gseg_gi"};
      $geneid = $mrna->{"locus_id"};
      $strand = "-" if($mrna->{"strand"} eq "r");
    }
    $start = $mrna->{"l_pos"} if($mrna->{"l_pos"} < $start or $start == 0);
    $end   = $mrna->{"r_pos"} if($mrna->{"r_pos"} > $end);
  }
  
  my @gff3 = ($seqid, "xGDBvm", "gene", $start, $end, ".", $strand, ".",
              "ID=$geneid");
  print $OUT join("\t", @gff3), "\n";
  foreach my $mrna(@$mrnalist)
  {
    mrna_to_gff3($mrna, $OUT);
  }
}