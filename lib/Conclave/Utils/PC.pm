use strict;
use warnings;
package Conclave::Utils::PC;
# ABSTRACT: OTK program comprehension specific tasks

use Text::WordGrams;
use Lingua::StopWords qw( getStopWords );
use Lingua::Jspell;
use DBI;
use DBD::SQLite;
use File::Basename;
use JSON;
use File::Slurp qw/write_file read_file/;

sub problem_load_terminology {
  my ($onto, $corpus, $pkgid) = @_;

  # compute word unigrams
  my $data = word_grams_from_files({size=>1}, $corpus);
  my $total = 0;
  $total += $data->{$_} foreach (keys %$data);

  my $stopwords = getStopWords('en');
  foreach (keys %$data) {
    # remove stop words
    delete $data->{$_} and next if ($stopwords->{$_} or $stopwords->{lc $_});

    # remove non words
    delete $data->{$_} and next unless $_ =~ m/^[\w\d\-]+$/;
    delete $data->{$_} and next if $_ =~ m/^[\-\_]+$/;

    # remove length < 3
    delete $data->{$_} and next if length($_) < 3;

    # remove if freq <= 2
    delete $data->{$_} and next if $data->{$_} <= 2;
  }

  my $final = {};
  my $lemmas = _build_lemmas($data);
  foreach (keys %$data) {
    my $lemma = $lemmas->{$_} or next;
    $final->{$lemma}->{$_} = $data->{$_};
  }

  foreach my $k (keys %$final) {
    my $sum = 0;
    foreach (keys %{$final->{$k}}) {
      $sum += $final->{$k}->{$_};
    }
    if ($sum/$total<0.005) {
      delete $final->{$k};
    }
  }

  # update ontolgoy
  if ($onto) {
    foreach my $c (keys %$final) {
      $onto->add_class($c, 'Concept');

      my @terms = keys %{ $final->{$c} };
      $onto->add_instance($_, $c) foreach @terms;
    }
  }
  # else return hash
  else {
    return $final;
  }
}

# build lemmas using jspell
sub _build_lemmas {
  my $h = shift;
  my $lemmas = {};

  my $dict = Lingua::Jspell->new("en"); # XXX
  foreach (keys %$h) {
    my @rads = $dict->rad($_);
    $lemmas->{$_} = shift @rads;
  }

  return $lemmas;
}

sub program_load_idtable {
  my ($onto, $dbfile, $pkgid) = @_;

  # collect idtable from dbfile
  my $ids;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile");
  my $sth = $dbh->prepare("SELECT * FROM idtable WHERE pkgid=?");
  $sth->execute($pkgid);
  while (my $row = $sth->fetchrow_hashref()) {
    $ids->{$row->{iduid}} = $row;
  }

  my %files;
  foreach (keys %$ids) {
    my $elem = lc $ids->{$_}->{idtype};
    my $idline = $ids->{$_}->{idline};
    my $idfile = basename $ids->{$_}->{idfile};
    my $idpath = dirname $ids->{$_}->{idfile};
    $files{$idfile} = $ids->{$_}->{idfile};
    my $idname = $ids->{$_}->{idname};

    # add procedures to ontology
    if ($elem eq 'proc') {
      $onto->add_instance($_, 'Identifier');
      $onto->add_data_prop($_, 'hasIdString', $idname);
      $onto->add_instance("$idfile:$idname", 'Function');
      $onto->add_obj_prop("$idfile:$idname", 'hasIdentifier', $_);
    }
    # add variables to ontology
    else {
      $onto->add_instance($_, 'Variable');
    }
  }

  # add files to ontology
  foreach (keys %files) {
    $onto->add_instance($_, 'File');
    $onto->add_data_prop($_, 'hasFullPath', $files{$_});
    $onto->add_data_prop($_, 'hasFileName', basename $files{$_});
  } 
}

sub program_load_clang {
  my ($onto, $datafile, $pkgid) = @_;

  my $r = `wc -l $datafile`;
  my $total = -1;
  my $c = 0;
  $total = $1 if ($r =~ m/(^\d+)\s*/);

  open my $fh, '<', $datafile or die "can't open datafile\n";
  my %files;
  while (my $line = <$fh>) {
    chomp $line;
    next if $line =~ m/^\s*#/;

    my @list = split /\s*,\s*/, $line;
    my $class = shift @list;
    my $uid = shift @list;
    my $idname = shift @list;
    next unless ($class and $uid and $idname and @list);

    $c++;
    print STDERR "[$c/$total] $uid\n";

    if ($class =~ m/^(Function|GlobalVariable|Macro|TypeDecl|LocalVariable|Parameter)$/) {

      # add identifier instance
      $onto->add_instance("I::$uid", 'Identifier');
      $onto->add_data_prop("I::$uid", 'hasIdString', $idname);
      $onto->add_data_prop("I::$uid", 'hasLineBegin', $list[2], 'int');
      $onto->add_data_prop("I::$uid", 'hasLineEnd', $list[3], 'int');
      $onto->add_obj_prop("I::$uid", 'inFile', $list[1]);

      # add class instance
      $onto->add_instance($uid, $class);
      $onto->add_data_prop($uid, 'hasLineBegin', $list[2], 'int');
      $onto->add_data_prop($uid, 'hasLineEnd', $list[3], 'int');
      $onto->add_obj_prop($uid, 'hasIdentifier', "I::$uid");
      $onto->add_obj_prop($uid, 'inFile', $list[1]);

      $files{$list[1]}++;
    }
    if ($class =~ m/^(LocalVariable|Parameter)$/) {
      $onto->add_obj_prop($uid, 'inFunction', $list[0]);
    }
    if ($class =~ m/^(hasFunctionCall)$/) {
      #$onto->add_obj_prop($uid, 'hasFunctionCall', $list[0]);
      $onto->add_obj_prop($list[0], 'hasFunctionCall', $uid);
    }
  }

  # add files to ontology
  foreach (keys %files) {
    $onto->add_instance($_, 'File');
    $onto->add_data_prop($_, 'hasFullPath', $_ );
    $onto->add_data_prop($_, 'hasFileName', basename $_ );
  } 
}

sub program_load_antlr {
  my ($onto, $datafile, $pkgid) = @_;

  my $r = `wc -l $datafile`;
  my $total = -1;
  my $c = 0;
  $total = $1 if ($r =~ m/(^\d+)\s*/);

  open my $fh, '<', $datafile or die "can't open datafile\n";
  my %files;
  while (my $line = <$fh>) {
    chomp $line;
    next if $line =~ m/^\s*#/;

    my @list = split /\s*,\s*/, $line;
    my $class = shift @list;
    my $uid = shift @list;
    my $idname = shift @list;
    next unless ($class and $uid and $idname and @list);

    $c++;
    print STDERR "[$c/$total] $uid\n";

    if ($class =~ m/^(Class|Method|Constructor|ClassVariable|LocalVariable|Parameter)$/) {

      # add identifier instance
      $onto->add_instance("I::$uid", 'Identifier');
      $onto->add_data_prop("I::$uid", 'hasIdString', $idname);
      $onto->add_data_prop("I::$uid", 'hasLineBegin', $list[2], 'int');
      $onto->add_data_prop("I::$uid", 'hasLineEnd', $list[3], 'int');
      $onto->add_obj_prop("I::$uid", 'inFile', $list[1]);

      # add class instance
      $onto->add_instance($uid, $class);
      $onto->add_data_prop($uid, 'hasLineBegin', $list[2], 'int');
      $onto->add_data_prop($uid, 'hasLineEnd', $list[3], 'int');
      $onto->add_obj_prop($uid, 'hasIdentifier', "I::$uid");
      $onto->add_obj_prop($uid, 'inFile', $list[1]);

      $files{$list[1]}++;
    }
    if ($class =~ m/^(LocalVariable|Parameter)$/) {
      $onto->add_obj_prop($uid, 'inMethod', $list[0]);
    }
    if ($class =~ m/^(Method)$/) {
      $onto->add_obj_prop($uid, 'inClass', $list[0]);
    }
    if ($class =~ m/^(Constructor)$/) {
      $onto->add_obj_prop($uid, 'inClass', $list[0]);
    }
    #if ($class =~ m/^(hasFunctionCall)$/) {
    #  #$onto->add_obj_prop($uid, 'hasFunctionCall', $list[0]);
    #  $onto->add_obj_prop($list[0], 'hasFunctionCall', $uid);
    #}
  }

  # add files to ontology
  foreach (keys %files) {
    $onto->add_instance($_, 'File');
    $onto->add_data_prop($_, 'hasFullPath', $_ );
    $onto->add_data_prop($_, 'hasFileName', basename $_ );
  } 
}

sub get_id_type {
  my ($o, $id) = @_;
  $id = "<$id>" unless $id =~ m/^</;

  my $sparql = <<"EOQ";
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX owl: <http://www.w3.org/2002/07/owl#>

SELECT ?y WHERE {
  $id rdf:type ?y
}
EOQ
  my $r = $o->_query($sparql);

  my $type;
  foreach (split /\n/, $r) {
    if ($_ =~ m/<.*?#(.*?)>/) {
      $type = $1 unless $1 =~ m/^(Identifier|NamedIndividual)$/;
    }
  }

  return $type;
}

sub program_load_idterms {
  my ($onto, $datafile, $pkgid) = @_;

  my $json = read_file($datafile, {binmode=>':utf8'});
  my $data = decode_json $json;

  my $t = keys %$data;
  my $c = 1;
  foreach my $uid (keys %$data) {
    print STDERR "[$c/$t] I::$uid\n";
    $onto->add_data_prop("I::$uid", 'hasSplits', $data->{$uid}->{splits}, 'string');
    $onto->add_data_prop("I::$uid", 'hasTerms', $data->{$uid}->{terms}, 'string');
    $c++;
  }
}

1;

__END__

=SYNOPSIS

TODO

=DESCRIPTION

TODO

=func problem_load_terminology

Compute corpus terminology. Pass as argument an ontology object to
update the data to the ontology.

=func program_load_idtable

Load identifiers table to program ontology.

=func program_load_clang

Load clang-conclave output to program ontology.

=func program_load_antlr

Load conc-antlr output to program ontology.

=func program_load_idterms

Load identifiers splits and terms to program ontology.
