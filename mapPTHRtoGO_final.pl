#!/usr/bin/perl
# use strict;

BEGIN { $ENV{LIST_MOREUTILS_PP}=1; }
use Carp;
use List::MoreUtils qw(uniq);

my %go_id_to_pthrid;
my %uniprot_id_to_pthrid;
my %alterid_to_pthrid;
my %gene_symbol_taxa_to_pthrid;
my %gene_symbol_db_to_pthrid;
my %pthrid_to_taxid;
my %taxon;
my %gomf;
my %gomfw;
my %gomf_exp;
my %gobp;
my %gobpw;
my %gobp_exp;
my %gocc;
my %goccw;
my %gocc_exp;
my %goempty;
my @all_pthrid;
my @matched_ptherid;
my @unmatched_ptherid;

use Getopt::Std;
getopts('h:f:t:i:g:p:m:o:x:b:c:y:a:u:e:v:w:M:B:C:V') || &usage();
&usage() if ($opt_h);          # -h for (h)elp
$fullgo = $opt_f if ($opt_f);   # -f for (f) full gene Ontology association complete File (GAF file)
$tax = $opt_t if ($opt_t);  # -t for (t)axon File
$ide = $opt_i if ($opt_i);   # -i for (i)dentifier File
$gen = $opt_g if ($opt_g);  # -g for (g)ene File
$xcode = $opt_x if ($opt_x);  # -x for e(x)perimental codes File
$pc = $opt_p if ($opt_p);  # -p for (p)arent child relation  File
$mf = $opt_M if ($opt_M);   # -M for (m)oleculer Function annotation (without 'not' annotation) output File
$bp = $opt_B if ($opt_B);  # -B for (b)iological process annotation (without 'not' annotation) output File
$cc = $opt_C if ($opt_C);  # -C for (c)ellular component annotation (without 'not' annotation) output File
$mfe = $opt_m if ($opt_m);   # -m for experimental (m)oleculer Function output File
$bpe = $opt_b if ($opt_b);  # -b for experimental (b)iological process output File
$cce = $opt_c if ($opt_c);  # -c for experimental (c)ellular component output File
$goannow = $opt_w if ($opt_w); # -w for complete go annotation mapped to pthr (with evidence) output file
$emty = $opt_y if ($opt_y); # -y for pantherid with empty go terms output File
$mat = $opt_a if ($opt_a);   # -a for total m(a)tch File
$umat = $opt_u if ($opt_u);  # -u for total (u)nmatch Data File
$go = $opt_o if ($opt_o); # -o for go.obo file
$errFile = $opt_e if ($opt_e); # -e for (e)rror file (redirect STDERR)
$verbose = 1 if ($opt_v);      # -v for (v)erbose (debug info to STDERR)
$verbose = 2 if ($opt_V);      # -V for (V)ery verbose (debug info to STDERR)

open(GEN, $gen) or die $!;
opendir(GO, $fullgo) or die $!;
open(TAX, $tax) or die $!;
open(EVI, $xcode) or die $!;
open(ID, $ide) or die $!;
open(GOT, $go) or die $!;
open(GOW, ">$goannow") or die $!;
open(MFE, ">$mfe") or die $!;
open(BPE, ">$bpe") or die $!;
open(CCE, ">$cce") or die $!;
open(EM, ">$emty") or die $!;
open(MAT, ">", "$mat") or die $!;
open(UMAT, ">", "$umat") or die $!;
open(STDERR, ">$errFile") or die $!;


while (<TAX>) 
{
	 chomp($_);
	my ($code,$taxid) = split('\t');
	chomp($code,$taxid);
	$taxid =~ s/^\s+|\s+$//g;
	$code =~ s/^\s+|\s+$//g;
	
	$taxon{$code}=$taxid;	
	
}
	
close(TAX);

my %obso_go;
while (my $record=<GOT>){
    my $def;
    my @alt_id;
	my @lines=split(/\n/, $record);
	my $goid=(split(/id:/, $lines[1]))[1];
	#print "$gid\n";
	$goid=~ s/^\s+|\s+$//g;
	#print "$gid\n";
	my $name=(split(/name:/, $lines[2]))[1];
	my $ttype=(split(/namespace:/, $lines[3]))[1];
	my $obsolete_date;
	my $obsolete_term;
	my $replace_term;
	for my $line (@lines) {
		if ($line =~ /^def:/) {
		   $def=(split(/def:/, $line))[1];
		}
		if ($line =~ /^alt_id:/) {
			push (@alt_id, (split(/alt_id:/, $line))[1]);
		}
		if ($line =~ /^is_obsolete/i){
			$obsolete_term = $goid if $line =~ /true/i;
			$obsolete_date = $release_date;
		}
		if ($line =~ /^replaced_by/i){
		    chomp $line;
			($replace_term) = $line =~ /(GO\:\d+)/;
		}
    }

	if ($obsolete_term){
	   $obso_go{$obsolete_term}=$replace_term;
	}
	
}
close(GOT);

my %expevi;
while (<EVI>) 
	 {
	 chomp($_);	
	$expevi{$_}++;
	}
	
close(EVI);


while (<GEN>) 
	 {
	 chomp($_);
	 my ($pthrid,$geneDesc,$geneSym) = split('\t');
	 chomp($geneDesc,$pthrid,$geneSym);
	 $geneSym =~ s/^\s+|\s+$//g;
	 
	 $pthrid =~ s/^\s+|\s+$//g;
	 
	 push (@all_pthrid, $pthrid);
	 my ($org,$gene,$protein) = split('\|',$pthrid);
	 chomp($org, $gene, $protein);
	 $org =~ s/^\s+|\s+$//g;
	 my $tax = $taxon{$org};
	 
	 my ($unitpro,$unitpro_id)=split('=',$protein);
	 chomp($unitpro,$unitpro_id);
	 $unitpro_id =~ s/^\s+|\s+$//g;
	 
	 $uniprot_id_to_pthrid{$unitpro_id} = $pthrid;
	 $go_id_to_pthrid{$unitpro_id}{'UniProtKB'} = $pthrid;
	 $go_id_to_pthrid{$unitpro_id}{$tax} = $pthrid;
	 if ($gene =~ /'MGI=MGI'/){
	    my $mgiid=(split('=', $gene))[-1];
		$mgiid = 'MGI:'.$mgiid;
		
		$go_id_to_pthrid{$mgiid}{'MGI'} = $pthrid;
		$go_id_to_pthrid{$mgiid}{$tax} = $pthrid;
	 }
	 else {
	    my ($dbname, $gene_id1, $gene_id2) = split('=', $gene);
		
	    $go_id_to_pthrid{$gene_id1}{$dbname} = $pthrid;
		$go_id_to_pthrid{$gene_id1}{$tax} = $pthrid;
		if (defined $gene_id2){
		    $go_id_to_pthrid{$gene_id2}{$dbname} = $pthrid;
			$go_id_to_pthrid{$gene_id2}{$tax} = $pthrid;
		}
	 
	 }
	 
	 $pthrid_to_taxid{$pthrid} = $tax;
	 $gene_symbol_taxa_to_pthr{$geneSym}{$tax} = $pthrid;
	 $gene_symbol_db_to_pthr{$geneSym}{$dbname} = $pthrid;
	 }	
close(GEN);

while (<ID>){
	chomp($_);
	my ($unipro_id,$db,$alter_id) = split('\t');
	chomp($unipro_id,$db,$alter_id);
	$alter_id =~ s/^\s+|\s+$//g;
	$unipro_id =~ s/^\s+|\s+$//g;
	my $pthrid = $uniprot_id_to_pthrid{$unipro_id};
	my ($org,$gene,$protein) = split('\|',$pthrid);
	 chomp($org, $gene, $protein);
	 $org =~ s/^\s+|\s+$//g;
	 my $tax = $pthrid_to_taxid{$pthrid};
	$alterid_to_pthrid{$alter_id}{$db} = $pthrid;
	$alterid_to_pthrid{$alter_id}{$tax} = $pthrid;
}
	
close(ID);


print STDERR "pthr_id\tmap_go_gid\tmap_by\t\tmap_by_comb\tgo_term\tgo_type\n";
for my $gaf (readdir GO) {
    next if $file =~ /^\.\.?$/;
	print "working on $gaf\n";
	open (GAF, "$fullgo/$gaf");
    while (<GAF>) {
	      next if ($_ =~ /^!/);
		  chomp($_);
		  my ($dbname,$go_gid,$gsym,$qualifier,$goacc,$ref,$ev_code,$with,$gotype,$a,$b,$c,$tax1,@else) = split('\t');
	      chomp($dbname,$go_gid,$gsym,$qualifier,$goacc,$ref,$ev_code,$with,$gotype,$a,$b,$c,$tax1);
	      $go_gid =~ s/^\s+|\s+$//g;
	      $dbname =~ s/^\s+|\s+$//g;
	      $gotype =~ s/^\s+|\s+$//g;
		  $gotype = 'molecular_function' if $gotype eq 'F';
		  $gotype = 'biological_process' if $gotype eq 'P';
		  $gotype = 'cellular_component' if $gotype eq 'C';
	      $gsym =~ s/^\s+|\s+$//g;
		  $goacc =~ s/^\s+|\s+$//g;
		  if (defined $obso_go{$goacc}){
		     my $repl_term = $obso_go{$goacc};
			 $goacc=$repl_term;
		  }
		  next if ($goacc eq '');
		  if ($gsym =~ /\|/g){
		    print "$gsym\t";
			$gsym =~ s/\|/\\/g;
		  }
		  
		  $tax1 =~ s/^\s+|\s+$//g;
		  my ($taxon, $tax) = split(':', $tax1);
		  $tax =~ s/^\s+|\s+$//g;
		  my %mapped_pthrid;
		  if(($dbname eq 'UniProtKB') && (exists $uniprot_id_to_pthrid{$go_gid} && defined $uniprot_id_to_pthrid{$go_gid})){
		      print MAT "$_\n";
			  my $pthrid = $uniprot_id_to_pthrid{$go_gid};
			  print STDERR "$pthrid\t$go_gid\tUniProtKB_ID plus dbname\t$go_gid\|$dbname\t$goacc\t$gotype\n";
			  $mapped_pthrid{$pthrid}++;
			  push(@matched_ptherid, $pthrid);
			  &goToPthr($pthrid,$gotype,$goacc,$qualifier, $ev_code, $with, $ref);
		  }
		  elsif(((exists $go_id_to_pthrid{$go_gid}{$dbname}) && (defined $go_id_to_pthrid{$go_gid}{$dbname}))){
		      print MAT "$_\n";
			  my $pthrid = $go_id_to_pthrid{$go_gid}{$dbname};
			  print STDERR "$pthrid\t$go_gid\tPanther_Middle_ID plus dbname\t$go_gid\|$dbname\t$goacc\t$gotype\n";
			  $mapped_pthrid{$pthrid}++;
			  push(@matched_ptherid, $pthrid);
			  &goToPthr($pthrid,$gotype,$goacc,$qualifier, $ev_code, $with, $ref);
		  }
		  elsif(((exists $go_id_to_pthrid{$go_gid}{$tax}) && (defined $go_id_to_pthrid{$go_gid}{$tax}))){
		      print MAT "$_\n";
			  my $pthrid = $go_id_to_pthrid{$go_gid}{$tax};
			  print STDERR "$pthrid\t$go_gid\tPanther_Middle_ID plus taxon_id\t$go_gid\|$tax\t$goacc\t$gotype\n";
			  
			  
			  $mapped_pthrid{$pthrid}++;
			  push(@matched_ptherid, $pthrid);
			  &goToPthr($pthrid,$gotype,$goacc,$qualifier, $ev_code, $with, $ref);
		  }
		  
		  elsif (((exists $alterid_to_pthrid{$go_gid}{$dbname}) && (defined $alterid_to_pthrid{$go_gid}{$dbname}))){
		      print MAT "$_\n";
			  my $pthrid = $alterid_to_pthrid{$go_gid}{$dbname};
			  print STDERR "$pthrid\t$go_gid\tPanther_Alternative_ID plus dbname\t$go_gid\|$dbname\t$goacc\t$gotype\n";
			  $mapped_pthrid{$pthrid}++;
			  push(@matched_ptherid, $pthrid);
			  &goToPthr($pthrid,$gotype,$goacc,$qualifier, $ev_code, $with, $ref);
		  }
		  
		  elsif (((exists $alterid_to_pthrid{$go_gid}{$tax}) && (defined $alterid_to_pthrid{$go_gid}{$tax}))){
		      print MAT "$_\n";
			  my $pthrid = $alterid_to_pthrid{$go_gid}{$tax};
			  print STDERR "$pthrid\t$go_gid\tPanther_Alternative_ID plus taxon_id\t$go_gid\|$tax\t$goacc\t$gotype\n";
			  $mapped_pthrid{$pthrid}++;
			  push(@matched_ptherid, $pthrid);
			  &goToPthr($pthrid,$gotype,$goacc,$qualifier, $ev_code, $with, $ref);
		  }
		  
		  elsif(((exists $go_id_to_pthrid{$gsym}{$dbname}) && (defined $go_id_to_pthrid{$gsym}{$dbname}))){
		      print MAT "$_\n";
			  my $pthrid = $go_id_to_pthrid{$gsym}{$dbname};
			  print STDERR "$pthrid\t$go_gid\tPanther_Middle_ID(match to gene symbol in fullgo) plus dbname\t$gsym\|$dbname\t$goacc\t$gotype\n";
			  
			  $mapped_pthrid{$pthrid}++;
			  push(@matched_ptherid, $pthrid);
			  &goToPthr($pthrid,$gotype,$goacc,$qualifier, $ev_code, $with, $ref);
		  }
		  
		  elsif(((exists $go_id_to_pthrid{$gsym}{$tax}) && (defined $go_id_to_pthrid{$gsym}{$tax}))){
		      print MAT "$_\n";
			  my $pthrid = $go_id_to_pthrid{$gsym}{$tax};
			  print STDERR "$pthrid\t$go_gid\tPanther_Middle_ID(match to gene symbol in fullgo) plus taxon_id\t$gsym\|$tax\t$goacc\t$gotype\n";
			  
			  $mapped_pthrid{$pthrid}++;
			  push(@matched_ptherid, $pthrid);
			  &goToPthr($pthrid,$gotype,$goacc,$qualifier, $ev_code, $with, $ref);
		  }
		  
		  elsif (((exists $alterid_to_pthrid{$gsym}{$dbname}) && (defined $alterid_to_pthrid{$gsym}{$dbname}))){
		      print MAT "$_\n";
			  my $pthrid = $alterid_to_pthrid{$gsym}{$dbname};
			  print STDERR "$pthrid\t$go_gid\tPanther_Alternative_ID(match to gene symbol in fullgo) plus dbname\t$gsym\|$dbname\t$goacc\t$gotype\n";
			  $mapped_pthrid{$pthrid}++;
			  push(@matched_ptherid, $pthrid);
			  &goToPthr($pthrid,$gotype,$goacc,$qualifier, $ev_code, $with, $ref);&goToPthr($pthrid,$gotype,$goacc,$qualifier, $ev_code, $with, $ref);
		  }
		  
		  elsif (((exists $alterid_to_pthrid{$gsym}{$tax}) && (defined $alterid_to_pthrid{$gsym}{$tax}))){
		      print MAT "$_\n";
			  my $pthrid = $alterid_to_pthrid{$gsym}{$tax};
			  print STDERR "$pthrid\t$go_gid\tPanther_Alternative_ID(match to gene symbol in fullgo) plus taxon_id\t$gsym\|$tax\t$goacc\t$gotype\n";
			  $mapped_pthrid{$pthrid}++;
			  push(@matched_ptherid, $pthrid);
			  &goToPthr($pthrid,$gotype,$goacc,$qualifier, $ev_code, $with, $ref);
		  }
		  
		  
		  elsif (exists $gene_symbol_taxa_to_pthr{$gsym}{$tax} && defined $gene_symbol_taxa_to_pthr{$gsym}{$tax} ){
		      print MAT "$_\n";
			  my $pthrid = $gene_symbol_taxa_to_pthr{$gsym}{$tax};
			  print STDERR "$pthrid\t$go_gid\tPanther_Gene_Symbol(match to gene symbol in fullgo) plus taxon_id\t$gsym\|$tax\t$goacc\t$gotype\n";
			  $mapped_pthrid{$pthrid}++;
			  push(@matched_ptherid, $pthrid);
			  &goToPthr($pthrid,$gotype,$goacc,$qualifier, $ev_code, $with, $ref);
		  }
		  else {
		      print STDERR "$go_gid did not map to any PANTHER ID\n";
		      print UMAT "$_\n";
			  
		   }
	}
    close(GAF);

}

my %matched_pid = map {$_ => 1 } @matched_ptherid;
@unmatched_ptherid = grep {not $matched_pid{$_}} @all_pthrid;


for my $k (sort keys %gomfw) {
 
	 @{ $gomfw{$k} }=uniq(@{ $gomfw{$k} });
	 if(@{ $gomfw{$k} }){
		 for my $go_term (@{ $gomfw{$k} }){
		    printf GOW "%s\t%s\n", $k, join "\t", @{ $go_term }
		 };
	 }
}
for my $j (sort keys %gobpw) {
	 @{ $gobpw{$j} }=uniq(@{ $gobpw{$j} });
	 if(@{ $gobpw{$j} }){
		 for my $go_term (@{ $gobpw{$j} }){
			printf GOW "%s\t%s\n", $j, join "\t", @{ $go_term }
		 };
	 }
}
for my $l (sort keys %goccw) {
	@{ $goccw{$l} }=uniq(@{ $goccw{$l} });
	 if(@{ $goccw{$l} }){
		 for my $go_term (@{ $goccw{$l} }){
			printf GOW "%s\t%s\n", $l, join "\t", @{ $go_term }
		 };
	 }
}
 
for my $k (sort keys %gomf_exp) {
	@{ $gomf_exp{$k} }=uniq(@{ $gomf_exp{$k} });
	if(@{ $gomf_exp{$k} }){
		printf MFE "%s\t%s\n", $k, join ',', @{ $gomf_exp{$k} };
	}
}
for my $j (sort keys %gobp_exp) {
	@{ $gobp_exp{$j} }=uniq(@{ $gobp_exp{$j} });
	if(@{ $gobp_exp{$j} }){
		printf BPE "%s\t%s\n", $j, join ',', @{ $gobp_exp{$j} };
	}
}
for my $l (sort keys %gocc_exp) {
	@{ $gocc_exp{$l} }=uniq(@{ $gocc_exp{$l} });
	if(@{ $gocc_exp{$l} }){
		printf CCE "%s\t%s\n", $l, join ',', @{ $gocc_exp{$l} };
	}
}

 
print EM "$_\n" for @unmatched_ptherid;

sub goToPthr{
    my ($pthrid,$gotype,$goacc,$qualifier, $ev_code, $with, $ref)=@_;
	if($gotype eq 'molecular_function'){	
		   push( @{$gomf_exp{$pthrid}}, $goacc."\|".$ev_code) if (exists $expevi{$ev_code});
           push( @{$gomfw{$pthrid}}, [$goacc, $qualifier, $ev_code, $with, $ref]);	   
		}
	  elsif($gotype eq 'biological_process'){
		
		   push( @{$gobp_exp{$pthrid}}, $goacc."\|".$ev_code) if (exists $expevi{$ev_code});
		
		   push( @{$gobpw{$pthrid}}, [$goacc, $qualifier, $ev_code, $with, $ref] );
		}
	  elsif($gotype eq 'cellular_component'){
		
		   push( @{$gocc_exp{$pthrid}}, $goacc."\|".$ev_code) if (exists $expevi{$ev_code});
		
		   push( @{$goccw{$pthrid}}, [$goacc, $qualifier, $ev_code, $with, $ref] );
		}
	  else {
		print STDERR "Could not assign go type to a matched go term\n";
	  }
}
 
 sub usage {
    my $error = shift;

    print <<__EOT;

 

Usage:
example:    
perl ../scripts/mapPTHRtoGO_final.pl -f $ph/external/fullgo/gaf_files_041317/ -t ../scripts/pthr12_code_taxId.txt -i /export/uec-gs1/pdthomas/panther/famlib/dev/UPL/PANTHER12.0/DBLoad/identifier.dat -g /export/uec-gs1/pdthomas/panther/famlib/dev/UPL/PANTHER12.0/DBLoad/gene.dat -m Pthr_GO_MF.tsv -b Pthr_GO_BP.tsv -c Pthr_GO_CC.tsv -y Pthr_GO_EM.tsv -a Pthr_GO_MATCH -u Pthr_GO_UNMATCH -o ../fullgo_paint_april_13_lib11/obsolete_go_terms.txt -x ../scripts/Paint_Evidence_Codes -e log042417.txt -M Pthr_GO_MFW.tsv -B Pthr_GO_BPW.tsv -C Pthr_GO_CCW.tsv -F Pthr_GO_MFE.tsv -P Pthr_GO_BPE.tsv -D Pthr_GO_CCE.tsv




__EOT

  print "Error: $error\n\n" if ($error);

  exit(-1);
}
