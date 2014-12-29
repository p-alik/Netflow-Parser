#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

my ($cls_name, $count, $packet) = qw/
    Netflow::Parser
    0
    0009001b336e7664533005771c6f1b34000000c801000408644ac701051c4b0a4a7ddaf34a7ddaf3f628f6280050005000000000060200000144f3955a3364404d9056383d9b36c3725436c37254da91da910050005000000000060100000144f3955a33644a9e89051c59747a704d287a704d280d3d0d3d1770177000000000060200000144f3955a3364404783563847bf511aa60b511aa60bcae6cae60050005000000000060200000144f3955a33644a47dc051c643d6fdd4db06fdd4db0494749479c4e9c4e00000000110200000144f3955a336440182c5e8b1caf3b5c505a3b5c505a627a627a8dff8dff00000000110100000144f3955a33644ad319591099924f1ea6ad4f1ea6ad0035003542eb42eb00000000110200000144f3955a33644a87ba563834d25bbed8195bbed819c9c3c9c3303e303e00000000060100000144f3955a33644ad10659108a69804927b4804927b4936193612e702e7000000000110100000144f3955a34644a4e3b5e8b1115adc220f4adc220f4e0d2e0d201bb01bb00000000060200000144f3955a34644a8ecf563839785f8bf6d25f8bf6d2f1c0f1c09632963200000000110100000144f3955a34644a933756384299adc2458aadc2458ac71ec71e01bb01bb00000000060200000144f3955a3464400f8156383acc25fca2d525fca2d5ea08ea080050005000000000060200000144f3955a3464406879563867185bc2f8405bc2f840a4eca4ec0050005000000000060200000144f3955a3464410d7f56387f6657e6355757e63557f868f8680050005000000000060200000144f3955a34644106875fa88b08529631925296319265cd65cd040b040b00000000110200000144f3955a34644a4fc956382cde58dd5cc058dd5cc0c96dc96d0050005000000000060200000144f3955a34644140645fa88b153e21c6073e21c6070432043277e377e300000000110200000144f3955a34644100e956387d7452706a5852706a58cc44cc440050005000000000060200000144f3955a34644000fd56382e5b51ab703451ab7034c1a7c1a70050005000000000060200000144f3955a3464400871563867664f7d688b4f7d688ba963a9630050005000000000060100000144f3955a3464414d415fa88b512e260dab2e260dab46c046c03799379900000000110200000144f3955a34644a867b5e8b1decb038aeb7b038aeb700010001ebdeebde00000000060100000144f3955a34644a50605e8b13d862655a6262655a62000000000000000000000000010200000144f3955a34644ae28725780ca02ec4e9512ec4e951810a810ac8d5c8d500000000110200000144f3955a35644ad64f563803ed36e1ebf636e1ebf6ebb6ebb60050005000000000060100000144f3955a35644111aa5fa88a54598874005988740021ad21ad5f9b5f9b00000000110100000144f3955a350000
    /;
use_ok($cls_name) || BAIL_OUT "can't load $cls_name";

my $template_only_data = pack('H*',
    '0100000c0008000400e10004000c000400e200040007000200e30002000b000200e4000200ea00040004000100e6000101430008'
);

my $cls = new_ok(
    $cls_name,
    [
        'verbose'      => 1,
        templates_data => [$template_only_data],
        'flow_cb'      => sub {
            my ($flow) = @_;
            $count++;

            #note explain $flow;
            is(scalar(keys %{$flow}),
                12, "callback a flow{$count} contains 12 items");
            return $flow;
            }
    ]
);

ok(my $p = $cls->parse(pack('H*', $packet)), 'parse');
note explain $p;
isa_ok($p, 'Netflow::Parser::Packet');
isa_ok($p->header, 'Netflow::Parser::Packet::Header');


my @templates = $cls->templates;
is(scalar(@templates), 1, 'templates');
foreach (@templates) {
    my ($id, $content) = each(%{$_});
    is($content, $cls->template($id), "template(template_id: $id)");
}

done_testing();
