use 5.006;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME               => 'Netflow::Parser',
    AUTHOR             => q{Alexei Pastuchov E<lt>palik at cpan.orgE<gt>.},
    VERSION_FROM       => 'lib/Netflow/Parser.pm',
    ABSTRACT_FROM      => 'lib/Netflow/Parser.pm',
    LICENSE            => 'perl',
    PL_FILES           => {},
    MIN_PERL_VERSION   => 5.006,
    CONFIGURE_REQUIRES => { 'ExtUtils::MakeMaker' => 0, },
    BUILD_REQUIRES     => { 'Test::More' => 0, },
    PREREQ_PM          => {
        'fields' => 0,
        'Carp'   => 0,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES    => 'Netflow-Parser-*' },
);
