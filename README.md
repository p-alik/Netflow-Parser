Netflow-Parser
==============

[![CPAN version](https://badge.fury.io/pl/Netflow-Parser.png)](https://badge.fury.io/pl/Netflow-Parser)
[![Build Status](https://travis-ci.org/p-alik/perl-Gearman.png)](https://travis-ci.org/p-alik/Netflow-Parser)
[![Coverage Status](https://coveralls.io/repos/github/p-alik/Netflow-Parser/badge.png)](https://coveralls.io/github/p-alik/Netflow-Parser)

Netflow::Parser
==============
* supports only _[Netflow](https://en.wikipedia.org/wiki/NetFlow) V9_
* parses NetFlow datagrams by applying known templates and execute a callback method for each flow.

**EXAMPLE** shows simple [Netflow::Collector](https://github.com/p-alik/Netflow-Collector) implementation 

```perl

my $p = Netflow::Parser->new(
    verbose      => 1,
    flow_cb      => sub {
        my ($hr) = @_;
        ...
    }
);

my $c = Netflow::Collector->new(
    port => $port,
    dispatch => sub { $p->parse(@_) }
        );

$c->run();

```
