#!/usr/bin/perl -w

use strict;

use Test::More tests => 37;
use Test::Exception;
use Test::HexString;
use IO::Async::Test;
use IO::Async::Loop;

use Tangence::Constants;
use Tangence::Registry;
use Tangence::Connection;
$Tangence::Message::SORT_HASH_KEYS = 1;

my $loop = IO::Async::Loop->new();
testing_loop( $loop );

my ( $S1, $S2 ) = $loop->socketpair() or die "Cannot create socket pair - $!";

{
   my $clientstream = "";
   sub wait_for_message
   {
      my $msglen;
      wait_for_stream { length $clientstream >= 5 and
                        length $clientstream >= ( $msglen = 5 + unpack "xN", $clientstream ) } $S2 => $clientstream;

      return substr( $clientstream, 0, $msglen, "" );
   }
}

my $conn = Tangence::Connection->new(
   handle => $S1,
   on_error => sub { die "Test died early - $_[0]" },
   identity => "testscript",
);
$loop->add( $conn );

my $expect;

# MSG_GETROOT
$expect = "\x40" . "\0\0\0\x0b" .
          "\x2a" . "testscript";

is_hexstr( wait_for_message, $expect, 'client stream initially contains MSG_GETROOT' );

# MSG_GETREGISTRY
$expect = "\x41" . "\0\0\0\0";

is_hexstr( wait_for_message, $expect, 'client stream initially contains MSG_GETREGISTRY' );

$S2->syswrite( "\x82" . "\0\0\0\xcf" .
               "\xe2" . "t::Bag\0" .
                        "\x64" . "events\0"     . "\x61" . "destroy\0" . "\x61" . "args\0" . "\x40" .
                                 "isa\0"        . "\x42" . "\x26" . "t::Bag" .
                                                           "\x30" . "Tangence::Object" .
                                 "methods\0"    . "\x63" . "add_ball\0"  . "\x62" . "args\0" . "\x41" . "\x23" . "obj" .
                                                                                    "ret\0"  . "\x20" .
                                                           "get_ball\0"  . "\x62" . "args\0" . "\x41" . "\x23" . "str" .
                                                                                    "ret\0"  . "\x23" . "obj" .
                                                           "pull_ball\0" . "\x62" . "args\0" . "\x41" . "\x23" . "str" .
                                                                                    "ret\0"  . "\x23" . "obj" .
                                 "properties\0" . "\x61" . "colours\0" . "\x62" . "dim\0"  . "\x21" . "2" .
                                                                                  "type\0" . "\x23" . "int" .
                        "\x40" .
               "\xe1" . "\0\0\0\1" . "t::Bag\0" . "\x40" .
               "\x84" . "\0\0\0\1" );

wait_for { defined $conn->get_root };

$S2->syswrite( "\x82" . "\0\0\0\xf8" .
               "\xe2" . "Tangence::Registry\0" .
                        "\x64" . "events\0"     . "\x63" . "destroy\0"            . "\x61" . "args\0" . "\x40" .
                                                           "object_constructed\0" . "\x61" . "args\0" . "\x41" . "\x23" . "int" .
                                                           "object_destroyed\0"   . "\x61" . "args\0" . "\x41" . "\x23" . "int" .
                                 "isa\0"        . "\x42" . "\x32" . "Tangence::Registry" .
                                                           "\x30" . "Tangence::Object" .
                                 "methods\0"    . "\x61" . "get_by_id\0" . "\x62" . "args\0" . "\x41" ."\x23" . "int" .
                                                                                    "ret\0"  . "\x23" . "obj" .
                                 "properties\0" . "\x61" . "objects\0" . "\x62" . "dim\0"  . "\x21" . "2" .
                                                                                  "type\0" . "\x23" . "str" .
                        "\x40" .
               "\xe1" . "\0\0\0\0" . "Tangence::Registry\0" . "\x40" .
               "\x84" . "\0\0\0\0" );

wait_for { defined $conn->get_registry };

my $bagproxy = $conn->get_root;

# We'll need to wait for a result, where the result is 'undef' later... To do
# that neatly, we'll have an array that contains one element
my @result;

$bagproxy->call_method(
   method => "pull_ball",
   args   => [ "red" ],
   on_result => sub { push @result, shift },
);

# MSG_CALL
$expect = "\1" . "\0\0\0\x10" . 
          "\x02" . "\x01" .
          "\x29" . "pull_ball" .
          "\x23" . "red";

is_hexstr( wait_for_message, $expect, 'client stream contains MSG_CALL' );

# MSG_RESULT

# This long string is massive and annoying. Sorry.

$S2->syswrite( "\x82" . "\0\0\0\xd2" .
               "\xe2" . "t::Ball\0" .
                        "\x64" . "events\0"     . "\x62" . "bounced\0" . "\x61" . "args\0" . "\x41" . "\x23" . "str" .
                                                           "destroy\0" . "\x61" . "args\0" . "\x40" .
                                 "isa\0"        . "\x42" . "\x27" . "t::Ball" .
                                                           "\x30" . "Tangence::Object" .
                                 "methods\0"    . "\x61" . "bounce\0" . "\x62" . "args\0" . "\x41" . "\x23" . "str" .
                                                                                 "ret\0" . "\x23" . "str" .
                                 "properties\0" . "\x62" . "colour\0" . "\x62" . "dim\0" . "\x21" . "1" .
                                                                                 "type\0" . "\x23" . "str" .
                                                           "size\0"   . "\x63" . "dim\0" . "\x21" . "1" .
                                                                                 "smash\0" . "\x21" . "1" .
                                                                                 "type\0" . "\x23" . "int" .
                        "\x41" . "\x24" . "size" .
               "\xe1" . "\0\0\0\2" . "t::Ball\0" . "\x41" . "\x23" . "100" .
               "\x84" . "\0\0\0\2" );

wait_for { @result };

isa_ok( $result[0], "Tangence::ObjectProxy", 'result contains an ObjectProxy' );

my $ballproxy = $result[0];

ok( $ballproxy->proxy_isa( "t::Ball" ), 'proxy for isa t::Ball' );

is_deeply( $ballproxy->can_method( "bounce" ),
           { args => [qw( str )], ret => "str" },
           'proxy can_method bounce' );

my $result;

$ballproxy->call_method(
   method => "bounce",
   args   => [ "20 metres" ],
   on_result => sub { $result = shift },
);

# MSG_CALL
$expect = "\1" . "\0\0\0\x13" .
          "\x02" . "\x02" .
          "\x26" . "bounce" .
          "\x29" . "20 metres";

is_hexstr( wait_for_message, $expect, 'client stream contains MSG_CALL' );

# MSG_RESULT
$S2->syswrite( "\x82" . "\0\0\0\x09" .
               "\x28" . "bouncing" );

wait_for { defined $result };

is( $result, "bouncing", 'result of MSG_CALL' );

dies_ok( sub { $ballproxy->call_method(
                 method => "no_such_method",
                 args   => [ 123 ],
                 on_result => sub {},
               ); },
         'Calling no_such_method fails in proxy' );

my $howhigh;
my $subbed;
$ballproxy->subscribe_event(
   event => "bounced",
   on_fire => sub {
      ( $howhigh ) = @_;
   },
   on_subscribed => sub { $subbed = 1 },
);

# MSG_SUBSCRIBE
$expect = "\2" . "\0\0\0\x0a" .
          "\x02" . "\x02" .
          "\x27" . "bounced";

is_hexstr( wait_for_message, $expect, 'client stream contains MSG_SUBSCRIBE' );

# MSG_SUBSCRIBED
$S2->syswrite( "\x83" . "\0\0\0\0" );

wait_for { $subbed };

# MSG_EVENT
$S2->syswrite( "\4" . "\0\0\0\x14" .
               "\x02" . "\x02" .
               "\x27" . "bounced" .
               "\x29" . "10 metres" );

wait_for { defined $howhigh };

is( $howhigh, "10 metres", '$howhigh is 10 metres after MSG_EVENT' );

# Check it said MSG_OK
$expect = "\x80" . "\0\0\0\0";

is_hexstr( wait_for_message, $expect, 'client stream contains MSG_OK' );

my $bounced = 0;
$ballproxy->subscribe_event(
   event => "bounced",
   on_fire => sub { $bounced = 1 }
);

# MSG_EVENT
$S2->syswrite( "\4" . "\0\0\0\x13" .
               "\x02" . "\x02" .
               "\x27" . "bounced" .
               "\x28" . "5 metres" );

wait_for { $bounced };

is( $howhigh, "5 metres", '$howhigh is orange after second MSG_EVENT' );
is( $bounced, 1, '$bounced is true after second MSG_EVENT' );

# MSG_OK
$expect = "\x80" . "\0\0\0\0";

is_hexstr( wait_for_message, $expect, 'client stream contains MSG_OK' );

dies_ok( sub { $ballproxy->subscribe_event(
                 event => "no_such_event",
                 on_fire => sub {},
               ); },
         'Subscribing to no_such_event fails in proxy' );

is( $ballproxy->prop( "size" ), 100, 'Smashed property initially set in proxy' );

my $colour;

$ballproxy->get_property(
   property => "colour",
   on_value => sub { $colour = shift },
);

# MSG_GETPROP
$expect = "\5" . "\0\0\0\x09" .
          "\x02" . "\x02" .
          "\x26" . "colour";

is_hexstr( wait_for_message, $expect, 'client stream contains MSG_GETPROP' );

# MSG_RESULT
$S2->syswrite( "\x82" . "\0\0\0\4" .
               "\x23" . "red" );

wait_for { defined $colour };

is( $colour, "red", '$colour is red' );

my $didset = 0;
$ballproxy->set_property(
   property => "colour",
   value    => "blue",
   on_done  => sub { $didset = 1 },
);

# MSG_SETPROP
$expect = "\6" . "\0\0\0\x0e" .
          "\x02" . "\x02" .
          "\x26" . "colour" .
          "\x24" . "blue";

is_hexstr( wait_for_message, $expect, 'client stream contains MSG_SETPROP' );

# MSG_OK
$S2->syswrite( "\x80" . "\0\0\0\0" );

wait_for { $didset };

my $watched;
$ballproxy->watch_property(
   property => "colour",
   on_set => sub { $colour = shift },
   on_watched => sub { $watched = 1 },
);

# MSG_WATCH
$expect = "\7" . "\0\0\0\x0a" .
          "\x02" . "\x02" .
          "\x26" . "colour" .
          "\x00";

is_hexstr( wait_for_message, $expect, 'client stream contains MSG_WATCH' );

# MSG_WATCHING
$S2->syswrite( "\x84" . "\0\0\0\0" );

wait_for { $watched };

# MSG_UPDATE
$S2->syswrite( "\x09" . "\0\0\0\x11" .
               "\x02" . "\x02" .
               "\x26" . "colour" .
               "\x02" . "\x01" .
               "\x25" . "green" );

undef $colour;
wait_for { defined $colour };

is( $colour, "green", '$colour is green after MSG_UPDATE' );

# MSG_OK
$expect = "\x80" . "\0\0\0\0";

is_hexstr( wait_for_message, $expect, 'client stream contains MSG_OK' );

my $colourchanged = 0;
my $secondcolour;
$ballproxy->watch_property(
   property => "colour",
   on_set => sub {
      $secondcolour = shift;
      $colourchanged = 1
   },
   want_initial => 1,
);

# MSG_GETPROP
$expect = "\5" . "\0\0\0\x09" .
          "\x02" . "\x02" .
          "\x26" . "colour";

is_hexstr( wait_for_message, $expect, 'client stream contains MSG_GETPROP' );

# MSG_RESULT
$S2->syswrite( "\x82" . "\0\0\0\6" .
               "\x25" . "green" );

wait_for { $colourchanged };

is( $secondcolour, "green", '$secondcolour is green after second watch' );

# MSG_UPDATE
$S2->syswrite( "\x09" . "\0\0\0\x12" .
               "\x02" . "\x02" .
               "\x26" . "colour" .
               "\x02" . "\x01" .
               "\x26" . "orange" );

$colourchanged = 0;
wait_for { $colourchanged };

is( $colour, "orange", '$colour is orange after second MSG_UPDATE' );
is( $colourchanged, 1, '$colourchanged is true after second MSG_UPDATE' );

# MSG_OK
$expect = "\x80" . "\0\0\0\0";

is_hexstr( wait_for_message, $expect, 'client stream contains MSG_OK' );

dies_ok( sub { $ballproxy->get_property(
                 property => "no_such_property",
                 on_value => sub {},
               ); },
         'Getting no_such_property fails in proxy' );

# Test the smashed properties

my $size;
$watched = 0;
$ballproxy->watch_property(
   property => "size",
   on_set => sub { $size = shift },
   on_watched => sub { $watched = 1 },
   want_initial => 1,
);

is( $watched, 1, 'watch_property on smashed prop is synchronous' );

is( $size, 100, 'watch_property on smashed prop gives initial value' );

# MSG_UPDATE
$S2->syswrite( "\x09" . "\0\0\0\x0b" .
               "\x02" . "\x02" .
               "\x24" . "size" .
               "\x02" . "\x01" .
               "\x02" . "\xc8" ); # 0xC8 == 200

undef $size;
wait_for { defined $size };

is( $size, 200, 'smashed prop watch succeeds' );

# MSG_OK
$expect = "\x80" . "\0\0\0\0";

is_hexstr( wait_for_message, $expect, 'client stream contains MSG_OK after smashed prop UPDATE' );

$bagproxy->call_method(
   method => "add_ball",
   args   => [ $ballproxy ],
   on_result => sub { push @result, shift },
);

# MSG_CALL
$expect = "\1" . "\0\0\0\x10" . 
          "\x02" . "\x01" .
          "\x28" . "add_ball" .
          "\x84" . "\0\0\0\2";

is_hexstr( wait_for_message, $expect, 'client stream contains MSG_CALL with an ObjectProxy' );

$S2->syswrite( "\x82" . "\0\0\0\0" );

undef @result;
wait_for { @result };

is( $result[0], undef, 'result is undef' );

# Test object destruction

my $proxy_destroyed = 0;

$ballproxy->subscribe_event(
   event => "destroy",
   on_fire => sub { $proxy_destroyed = 1 },
);

# MSG_DESTROY
$S2->syswrite( "\x0a" . "\0\0\0\2" .
               "\x02" . "\x02" );

wait_for { $proxy_destroyed };
is( $proxy_destroyed, 1, 'proxy gets destroyed' );

# MSG_OK
$expect = "\x80" . "\0\0\0\0";

is_hexstr( wait_for_message, $expect, 'client stream contains MSG_OK after MSG_DESTROY' );