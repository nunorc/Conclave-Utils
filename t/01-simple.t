#!perl -T

use Test::More tests => 3;

use Conclave::Utils;

my $rdfxml = conc_base_ontologies('http://test/program','program');
ok( length($rdfxml) > 500, 'got some RDF for program' );

$rdfxml = conc_base_ontologies('http://test/program','problem');
ok( length($rdfxml) > 100, 'got some RDF for problem' );

$rdfxml = conc_base_ontologies('http://test/program');
ok( length($rdfxml) > 100, 'got some RDF for default' );

