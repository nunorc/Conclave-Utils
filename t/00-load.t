#!perl -T

use Test::More;

BEGIN {
  my $tests = 0;

  foreach (qw/Conclave::Utils Conclave::Utils::PC/) {
    use_ok($_) || print "$_ failed to load!\n";
    $tests++;
  }

  done_testing($tests);
}
