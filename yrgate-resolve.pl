#!/usr/bin/env perl
use strict;
use DBI;
use Getopt::Long;

sub mrna_to_gff3
{
  my $mrna = shift(@_);
  my $OUT = shift(@_);

  my $strand = $mrna->{"strand"} eq "f" ? "+" : "-";
  my $mrnaid = $mrna->{"gff3_mrna_id"};
  my $geneid = $mrna->{"gff3_gene_id"};

  my @gff3 = ($mrna->{"gff3_seq"}, "xGDBvm", "mRNA", $mrna->{"l_pos"},
              $mrna->{"r_pos"}, ".", $strand, ".", "ID=$mrnaid;Parent=$geneid");
  $gff3[8] .= $mrna->{"proteinAliases"} eq ""
              ? "" : ";Name=". $mrna->{"proteinAliases"};
  $gff3[8] .= $mrna->{"proteinId"} eq ""
              ? "" : ";description=\"". $mrna->{"proteinId"} ."\"";
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
  $exonstring =~ s/&[gl]t;//g;
  my @exons = split(/\s*,\s*/, $exonstring);

  foreach my $exon(@exons)
  {
    @gff3[3..4] = split(/\.{2}/, $exon);
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
      $seqid = $mrna->{"gff3_seq"};
      $geneid = $mrna->{"gff3_gene_id"};
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
  print $OUT "###\n";
}

sub dbi_error
{
  my $message = shift(@_);
  $message = "database error" unless($message);
  printf(STDERR "%s: %s\n", $message, $DBI::errstr);
  exit(1);
}

sub print_usage
{
  my $OUT = shift(@_);
  print "Usage: perl $0 [options] repopath
  Options:
    --allyg              process all yrGATE submissions; default is to process
                         only accepted submissions
    --annotable=STRING   MySQL table containing original annotations; default is
                         'gseg_gene_annotation'
    --db=STRING          MySQL database containing yrGATE annotations; default
                         is 'GDB001'
    --help               print this help message and exit
    --host=STRING        MySQL host; default is 'localhost'
    --passwd=STRING      MySQL password; default is the xGDBvm default
    --region=STRING      only print annotations for the given region; specify
                         region using the format 'seqid:start-end'; for example,
                         'chr2:150001-200000'; default is to print all
                         annotations
    --user=STRING        MySQL username; default is xGDBvm default
    --ygtable=STRING     MySQL table containing yrGATE annotations; default is
                         'user_gene_annotation'
";
}



my $mycnf =
{
  "allyg"     => 0,
  "annotable" => "gseg_gene_annotation",
  "db"        => "GDB001",
  "host"      => "localhost",
  "password"  => "xgdb",
  "region"    => "",
  "user"      => "gdbuser",
  "ygtable"   => "user_gene_annotation",
};
GetOptions
(
  "allyg"       => \$mycnf->{"allyg"},
  "annotable=s" => \$mycnf->{"annotable"},
  "db=s"        => \$mycnf->{"db"},
  "help"        => sub { print_usage(\*STDOUT); exit(0); },
  "host=s"      => \$mycnf->{"host"},
  "passwd=s"    => \$mycnf->{"password"},
  "region=s"    => \$mycnf->{"region"},
  "user=s"      => \$mycnf->{"user"},
  "ygtable=s"   => \$mycnf->{"ygtable"},
);

my %models;
my %annot_models_to_delete;

my $dbistr = sprintf("dbi:mysql:%s;host=%s", $mycnf->{"db"}, $mycnf->{"host"});
my $db = DBI->connect($dbistr, $mycnf->{"user"}, $mycnf->{"password"}) or
         dbi_error("error connecting to the database");

# Load yrGATE annotations into memory
my $sql = "SELECT * FROM ". $mycnf->{"ygtable"};
if($mycnf->{"region"} ne "")
{
  my($seqid, $start, $end) = $mycnf->{"region"} =~ m/^(.+):(\d+)-(\d+)$/;
  unless($seqid and $start and $end)
  {
    printf(STDERR "error parsing region from '%s'\n", $mycnf->{"region"});
    print_usage(\*STDERR);
    exit(1);
  }
  $sql .= sprintf(" WHERE chr = '%s' AND l_pos >= %d AND r_pos <= %d", $seqid,
                  $start, $end);
  $sql .= " AND status='ACCEPTED'" unless($mycnf->{"allyg"});
}
else
{
  $sql .= " WHERE status='ACCEPTED'" unless($mycnf->{"allyg"});
}
my $query = $db->prepare($sql) or dbi_error("error preparing MySQL statement");
$query->execute() or dbi_error("error executing MySQL statement");
while(my $annot = $query->fetchrow_hashref())
{
  my $geneid = $annot->{"locusId"};
  my $mrnaid = $annot->{"transcriptId"};

  my $class = $annot->{"annotation_class"};
  if($class eq "Improve" or $class eq "Extend or Trim" or $class eq "Variant" or
     $class eq "New Locus")
  {
    $annot->{"gff3_gene_id"} = $geneid;
    $annot->{"gff3_mrna_id"} = $annot->{"geneId"};
    $annot->{"gff3_seq"} = $annot->{"chr"};
    $models{$geneid}->{$mrnaid} = $annot;
  }

  if($class eq "Improve" or $class eq "Extend or Trim" or $class eq "Delete")
  {
    if($mrnaid eq "")
    {
      printf(STDERR "delete fail: %s entry uid=%d has no transcriptId value",
             $mycnf->{"ygtable"}, $annot->{"uid"});
      exit(1);
    }
    if( my $otherannot = $annot_models_to_delete{$mrnaid} )
    {
      printf(STDERR "warning: transcript '%s' already being replaced by '%s'\n",
             $mrnaid, $otherannot->{"geneId"});
    }
    $annot_models_to_delete{ $mrnaid } = $annot;
  }
}
$query->finish();

# Load original annotations into memory
$sql = "SELECT * FROM ". $mycnf->{"annotable"};
if($mycnf->{"region"} ne "")
{
  my($seqid, $start, $end) = $mycnf->{"region"} =~ m/^(.+):(\d+)-(\d+)$/;
  unless($seqid and $start and $end)
  {
    printf(STDERR "error parsing region from '%s'\n", $mycnf->{"region"});
    print_usage(\*STDERR);
    exit(1);
  }
  $sql .= sprintf(" WHERE gseg_gi = '%s' AND l_pos >= %d AND r_pos <= %d",
                  $seqid, $start, $end);
}
$query = $db->prepare($sql) or dbi_error("error preparing MySQL statement");
$query->execute() or dbi_error("error executing MySQL statement");
while(my $annot = $query->fetchrow_hashref())
{
  my $geneid = $annot->{"locus_id"};
  my $mrnaid = $annot->{"geneId"};
  $annot->{"gff3_gene_id"} = $geneid;
  $annot->{"gff3_mrna_id"} = $mrnaid;
  $annot->{"gff3_seq"} = $annot->{"gseg_gi"};
  $models{$geneid}->{$mrnaid} = $annot;
}
$query->finish();

foreach my $geneid(keys(%models))
{
  my @mrnaids = keys(%{$models{$geneid}});
  my @mrnas_to_print;
  foreach my $mrnaid(@mrnaids)
  {
    if($annot_models_to_delete{$mrnaid})
    {
      delete($models{$geneid}->{$mrnaid});
    }
    else
    {
      push(@mrnas_to_print, $models{$geneid}->{$mrnaid});
    }
  }

  if(scalar(@mrnas_to_print) > 0)
  {
    gene_to_gff3(\@mrnas_to_print, \*STDOUT);
  }
}

$db->disconnect();