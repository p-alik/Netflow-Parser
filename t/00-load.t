#!perl -T
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Netflow::Parser' ) || print "Bail out!\n";
}

diag( "Testing Netflow::Parser $Netflow::Parser::VERSION, Perl $], $^X" );
