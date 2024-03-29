use strict;
use warnings;
package Conclave::Utils::PC;
# ABSTRACT: OTK program comprehension specific tasks

use Conclave::OTK;
use File::Basename;
use JSON;
use File::Slurp qw/write_file read_file/;

sub program_load_clang {
  my ($onto, $datafile, %opts) = @_;
  my $total = _count_lines($datafile);
  my $c = 0;

  open my $fh , '<', $datafile or die "Can't open $datafile: $!";
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
    print STDERR "[$c/$total] $uid\n" unless ($opts{silent});

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
  my ($onto, $datafile, %opts) = @_;
  my $total = _count_lines($datafile);
  my $c = 0;

  open my $fh , '<', $datafile or die "Can't open $datafile: $!";
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
    print STDERR "[$c/$total] $uid\n" unless ($opts{silent});

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

sub program_load_idterms {
  my ($onto, $datafile) = @_;

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

sub _count_lines {
  my ($datafile) = @_;

  my $count = 0;
  open my $fh , '<', $datafile or die "Can't open $datafile: $!";
  while( <$fh> ) { $count++ unless (m/^#/); }
  close $fh;

  return $count;
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
