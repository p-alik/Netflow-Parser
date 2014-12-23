package Netflow::Parser;

use 5.006;
use strict;
use warnings;

use fields qw/
    templates
    flow_cb
    verbose
    /;
use Carp;

=head1 NAME

Netflow::Parser

=head1 DESCRIPTION

A Netflow Parser supports only Netflow V9. The callback will be applied to each flow during packet parsing.

=head1 VERSION

Version 0.01

=cut

$Netflow::Parser::VERSION = '0.01';

=head1 SYNOPSIS

    use Netflow::Parser;

    my $nfp = Netflow::Parser->new(
            flow_cb => sub {my ($flow_hr) = @_; ...},
            templates_data => pack('H*', '01020002011b000400e60001')
        );

    while(my $packet = take_packet_from_socket()) {
        my $content = $nfp->parse($packet);

        $content->{unparsed_flowsets} && persist_for_later($content->{unparsed_flowsets});
    }

    my @templates = $nfp->templates;
    foreach (@templates) {
        my ($id, $content) = each(%{$_});
        $nfp->template($id); # persist template if you want
    }

=head1 SUBROUTINES/METHODS

=head2 new(%opts)

options:

=over

=item

C<templates_data>

[raw template piece]

=item

C<flow_cb>

callback method will be applied to each flow

=item

C<verbose>

=back

=cut

sub new {
    my Netflow::Parser $self = shift;
    my (%opts) = @_;
    unless (ref $self) {
        $self = fields::new($self);
    }

    $self->{'verbose'} = delete $opts{'verbose'};
    if ($opts{'flow_cb'}) {
        $self->{'flow_cb'} = delete $opts{'flow_cb'};
    }

    my $templates = delete $opts{'templates_data'};
    foreach (@{$templates}) {
        $self->_parse_template_v9($_);
    }

    %opts
        && warn(sprintf "unsupported parameter(s) '%s'", join ', ', keys %opts);

    return $self;
} ## end sub new

=head2 parse($packet)

currently only NetFlow V9 supported

unpack packet, try to parse flowsets content.

return {
   'header' => {
     'count',
     'seqno',
     'source_id',
     'sysuptime',
     'unix_secs',
     'version' => 9
   },
   'flows' => [flow_cb result],
   'flowsets' => ?, # flowsets number
   'templates' => [], # templates contains in the packet
   'unparsed_flowsets' => [] # no template 
}


=cut

sub parse {
    my ($self, $packet) = @_;
    my ($version) = unpack("n", $packet);
    return $self->_parse_v9($packet);
}

=head2 templates()

return [ { template_id => content} ]

=cut

sub templates {
    my ($self) = @_;
    my @templates = ();
    foreach my $id (keys %{ $self->{'templates'} }) {
        push @templates, { $id => $self->template($id) };
    }
    return @templates;
} ## end sub templates

=head2 template($template_id)

return hex dump of template for given $template_id

=cut

sub template {
    my ($self, $template_id) = @_;
    unless ($self->{'templates'}->{$template_id}) {
        $self->{'verbose'} && $self->_debug("no template $template_id");
        return;
    }

    return pack('n*',
        $template_id,
        scalar(@{ $self->{'templates'}->{$template_id}->{'content'} }) / 2,
        @{ $self->{'templates'}->{$template_id}->{'content'} });
} ## end sub template

#=head2 _parse_v9($packet)
#
#parse a C<$packet> and return content of them
#
#return {
#        'header'            => {
#            'version'   => $version,
#            'count'     => $count,
#            'sysuptime' => $sysuptime,
#            'unix_secs' => $unix_secs,
#            'seqno'     => $seqno,
#            'source_id' => $source_id,
#        },
#        'templates'         => [parsed templates],
#        'flows'             => [parsed flows],
#        'unparsed_flowsets' => [flowset couldn't be parsed],
#        'flowsets'          => scalar(@flowsets),
#    }
#
#=cut

sub _parse_v9 {
    my ($self, $packet) = @_;
    my (
        $version, $count,     $sysuptime, $unix_secs,
        $seqno,   $source_id, @flowsets
    ) = unpack("nnNNNN(nnX4/a)*", $packet);

    eval { $version == 9 } || Carp::croak("the version of packet is not v9");

    my $content = {
        'templates'         => [],
        'flows'             => [],
        'unparsed_flowsets' => [],
        'flowsets'          => scalar(@flowsets),
        'header'            => {
            'version'   => $version,
            'count'     => $count,
            'sysuptime' => $sysuptime,
            'unix_secs' => $unix_secs,
            'seqno'     => $seqno,
            'source_id' => $source_id,
        },
    };

    scalar(@flowsets) > length($packet)
        && warn sprintf("extimated %d flowsets > paket length %d",
        scalar(@flowsets), length($packet));
    for (my $i = 0; $i < scalar(@flowsets); $i += 2) {
        my $flowset_id = $flowsets[$i];

        # chop off id/length
        my $flowset = substr($flowsets[$i + 1], 4);
        if ($flowset_id == 0) {
            if ($flowset) {
                my @tmpl = $self->parse_template_v9($flowset);
                if (@tmpl) {
                    push @{ $content->{'templates'} }, @tmpl;
                }
                else {
                    push @{ $content->{'unparsed_flowsets'} },
                        { $flowset_id => $flowset };
                }
            } ## end if ($flowset)
        } ## end if ($flowset_id == 0)
        elsif ($flowset_id == 1) {

            # 1 - Options Template FlowSet
            $self->{'verbose'} && $self->_debug("do nothing for flowset id 1");

            push @{ $content->{'unparsed_flowsets'} }, $flowset;
        } ## end elsif ($flowset_id == 1)
        elsif ($flowset_id > 255) {
            my @flows = $self->_parse_flowset_v9($flowset_id, $flowset);
            if (scalar(@flows)) {
                push @{ $content->{'flows'} }, { $flowset_id => [@flows] };
            }
            else {
                push @{ $content->{'unparsed_flowsets'} },
                    { $flowset_id => $flowset };
            }
        } ## end elsif ($flowset_id > 255)
        else {
            # reserved FlowSet
            $self->{'verbose'}
                && $self->_debug("Unknown FlowSet ID $flowset_id found");
        }
    } ## end for (my $i = 0; $i < scalar...)
    return $content;
} ## end sub _parse_v9

#=head2 _parse_flowset_v9 ($flowset_id, $flowset)
#
#parse flowset if defined instance template for $flowset_id
#
#apply C<flow_cb> to each flow
#
#=over
#
#=item C<$flowset_id>
#
#is a template id number
#
#=item C<$flowset>
#
#flowset data
#
#=back
#
#return [{flow}]
#
#=cut

sub _parse_flowset_v9 {
    my ($self, $flowset_id, $flowset) = @_;
    if (!defined($self->{'templates'}->{$flowset_id})) {
        $self->{'verbose'}
            && $self->_debug("unknown template id $flowset_id");
        return;
    }

    my ($tmpl_length, @template) = (
        $self->{'templates'}->{$flowset_id}->{'length'},
        @{ $self->{'templates'}->{$flowset_id}->{'content'} }
    );

    my $cb = $self->{flow_cb};
    my ($datalen, $ofs) = (length($flowset), 0);

    my @flows = ();
    while (($ofs + $tmpl_length) <= $datalen) {
        my $flow = {};
        for (my $i = 0; $i < scalar @template; $i += 2) {
            my $fld_type = $template[$i];
            my $fld_len  = $template[$i + 1];
            my $fld_val  = substr($flowset, $ofs, $fld_len);
            $ofs += $fld_len;

            $flow->{$fld_type} = $fld_val;
        } ## end for (my $i = 0; $i < scalar...)

        $cb && $cb->($flow);

        #        push @flows, $flow;
        push @flows, $cb ? $cb->($flow) : $flow;
    } ## end while (($ofs + $tmpl_length...))

    return @flows;
} ## end sub _parse_flowset_v9

#=head2 _parse_template_v9($flowset)
#
#parse $flowset data, update instance templates
#
#return ({template_id => [template content]})
#
#=cut

sub _parse_template_v9 {
    my ($self, $flowset) = @_;
    my @template_ints = unpack("n*", $flowset);
    my ($i, $count, @tmpl) = (0, scalar(@template_ints));
    while ($i < $count) {
        my $template_id = $template_ints[$i];
        my $fld_count   = $template_ints[$i + 1];
        last if (!defined($template_id) || !defined($fld_count));

        #TODO $template_id < 255 || $template_id > 300; is 300 enough?
        ($template_id < 255 || $template_id > 300)
            && Carp::croak("wrong template id: $template_id");

        my $content
            = [@template_ints[($i + 2) .. ($i + 2 + $fld_count * 2 - 1)]];
        my $totallen = 0;
        for (my $j = 1; $j < scalar @$content; $j += 2) {
            $totallen += $content->[$j];
        }

        $self->{'verbose'}
            && $self->_debug(
            $self->{'templates'}->{$template_id}
            ? "update templates item $template_id"
            : "add $template_id to templates",
            "content: $totallen",
            "length: $totallen"
            );

        $self->{'templates'}->{$template_id} = {
            'content' => $content,
            'length'  => $totallen
        };

        $i += (2 + $fld_count * 2);

        push @tmpl, { $template_id => $content };
    } ## end while ($i < $count)

    return @tmpl;
} ## end sub _parse_template_v9

sub _debug {
    my ($self, @msg) = @_;
    (undef, undef, my $line) = caller;
    print join(' ', "LINE[$line]:", @msg, $/);
}

=head1 AUTHOR

Alexei Pastuchov E<lt>palik at cpan.orgE<gt>.

=head1 REPOSITORY

L<https://github.com/p-alik/Netflow-Parser>

=head1 LICENSE AND COPYRIGHT

Copyright 2014 by Alexei Pastuchov E<lt>palik at cpan.orgE<gt>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;    # End of Netflow::Parser
