use strict;
use warnings;
package Conclave::Utils;
# ABSTRACT: assorted utilities for Conclave OTK et al

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw/conc_base_ontologies/;

use Template;
use File::ShareDir ':ALL';

sub conc_base_ontologies {
  my ($onto, $base_uri) = @_;
  return unless ($onto and $base_uri);

  my $tts_dir;
  if (-e './share/tts') {
    $tts_dir = './';
  }
  else {
    $tts_dir = dist_dir('Conclave-Utils') . '/tts/';
  }
  my $config = {
      INCLUDE_PATH => [ $tts_dir, 'share/tts/' ],
    };
  my $template = Template->new($config);

  my $vars = {
      base_uri => $base_uri,
    };
  my $main = "${onto}_main.tt";

  my $owl;
  $template->process($main, $vars, \$owl) or die $template->error();

  return $owl;
}

1;

__END__

=encoding UTF-8

=head1 DESCRIPTION

This module provides some utility function to be used in the Conclave
environment.

=func conc_base_ontologies

TODO
