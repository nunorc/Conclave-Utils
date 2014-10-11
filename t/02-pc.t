#!perl -T
use Test::More tests => 2;

use warnings;
use strict;

use Conclave::Utils;
use Conclave::Utils::PC;
use File::Slurp qw/write_file/;
use File::Temp qw/tempfile tempdir/;

my %data;
my $key = 'clang';
while (my $line = <DATA>) {
  if ($line =~ m/_(\w+)_/) {
    $key = $1;
    next;
  }
  $data{$key} .= $line;
}

my %files;
foreach (keys %data) {
  my $tmp = File::Temp->new('onto_test_XXXXXXXX',
                              TMPDIR => 1,
                              SUFFIX => ".$_",
                              OPEN   => 0,
                              UNLINK => 1,
                            );
  write_file($tmp->filename, {binmode => ':utf8'}, $data{$_});
  $files{$_} = $tmp;
}

my $base_uri = 'http://local/testing';
my $rdfxml = conc_base_ontologies($base_uri, 'program');
my (undef, $filename) = tempfile('onto_test_XXXXXXXX',
                            TMPDIR => 1,
                            SUFFIX => ".triples",
                            OPEN   => 0,
                          );
my $onto = Conclave::OTK->new($base_uri,
               provider => 'File',
               filename => $filename
             );
$onto->init($rdfxml);

Conclave::Utils::PC::program_load_clang($onto, $files{clang}, silent=>1 );
my @instances = $onto->get_instances('GlobalVariable');
ok( scalar(@instances) == 5, 'number of global variables loaded' );

Conclave::Utils::PC::program_load_antlr($onto, $files{antlr}, silent=>1 );
my @params = $onto->get_instances('Parameter');
ok( scalar(@params) == 2, 'number of parameters loaded' );

$onto->delete;

__DATA__
_clang_
GlobalVariable,tree.c::version::65,version,,tree.c,65,65
GlobalVariable,tree.c::hversion::66,hversion,,tree.c,66,68
GlobalVariable,tree.c::gtable::101,gtable,,tree.c,101,105
GlobalVariable,tree.c::utable::101,utable,,tree.c,101,105
GlobalVariable,tree.c::itable::109,itable,,tree.c,109,113
_antlr_
Parameter,indent/BracketIndentRule.java::openBracket::38,openBracket,indent/BracketIndentRule.java::BracketIndentRule::38,indent/BracketIndentRule.java,38,38
Parameter,indent/BracketIndentRule.java::closeBracket::38,closeBracket,indent/BracketIndentRule.java::BracketIndentRule::38,indent/BracketIndentRule.java,38,38
Class,indent/BracketIndentRule.java::Brackets::45,Brackets,,indent/BracketIndentRule.java,45,49
