#!/usr/bin/perl -w

use strict;

use Test::More tests => 53;

use Tangence::Constants;
use Tangence::Registry;
use t::TestObj;

my $registry = Tangence::Registry->new();
my $obj = $registry->construct(
   "t::TestObj",
);

# SCALAR 

is( $obj->get_prop_scalar, "123", 'scalar initially' );

my $scalar;
$obj->watch_property( scalar =>
   on_set => sub { $scalar = shift },
);

my $scalar_shadow;
$obj->watch_property( scalar =>
   on_updated => sub { $scalar_shadow = shift },
);

is( $scalar_shadow, "123", 'scalar shadow initially' );

$obj->set_prop_scalar( "456" );
is( $obj->get_prop_scalar, "456", 'scalar after set' );
is( $scalar, "456", '$scalar after set' );

is( $scalar_shadow, "456", 'scalar shadow finally' );

# HASH

is_deeply( $obj->get_prop_hash, { one => 1, two => 2, three => 3 }, 'hash initially' );

my $hash;
my ( $h_key, $h_value );
$obj->watch_property( hash => 
   on_set => sub { $hash = shift },
   on_add => sub { ( $h_key, $h_value ) = @_ },
   on_del => sub { ( $h_key ) = @_ },
);

my $hash_shadow;
$obj->watch_property( hash =>
   on_updated => sub { $hash_shadow = shift },
);

is_deeply( $hash_shadow, { one => 1, two => 2, three => 3 }, 'hash shadow initially' );

$obj->set_prop_hash( { four => 4 } );
is_deeply( $obj->get_prop_hash, { four => 4 }, 'hash after set' );
is_deeply( $hash, { four => "4" }, '$hash after set' );

$obj->add_prop_hash( five => 5 );
is_deeply( $obj->get_prop_hash, { four => 4, five => 5 }, 'hash after add' );
is( $h_key,   'five', '$h_key after add' );
is( $h_value, 5,      '$h_value after add' );

$obj->add_prop_hash( five => 6 );
is_deeply( $obj->get_prop_hash, { four => 4, five => 6 }, 'hash after add as change' );
is( $h_key,   'five', '$h_key after add as change' );
is( $h_value, 6,      '$h_value after add as change' );

$obj->del_prop_hash( 'five' );
is_deeply( $obj->get_prop_hash, { four => 4 }, 'hash after del' );
is( $h_key, 'five', '$h_key after del' );

is_deeply( $hash_shadow, { four => 4 }, 'hash shadow finally' );

# QUEUE

is_deeply( $obj->get_prop_queue, [ 1, 2, 3 ], 'queue initially' );

my $queue;
my ( $q_count, @q_values );
$obj->watch_property( queue =>
   on_set => sub { $queue = shift },
   on_push => sub { @q_values = @_ },
   on_shift => sub { ( $q_count ) = @_ },
);

my $queue_shadow;
$obj->watch_property( queue =>
   on_updated => sub { $queue_shadow = shift },
);

is_deeply( $queue_shadow, [ 1, 2, 3 ], 'queue shadow initially' );

$obj->set_prop_queue( [ 4, 5, 6 ] );
is_deeply( $obj->get_prop_queue, [ 4, 5, 6 ], 'queue after set' );
is_deeply( $queue, [ 4, 5, 6 ], '$queue after set' );

$obj->push_prop_queue( 7 );
is_deeply( $obj->get_prop_queue, [ 4, 5, 6, 7 ], 'queue after push' );
is_deeply( \@q_values, [ 7 ], '@q_values after push' );

$obj->shift_prop_queue;
is_deeply( $obj->get_prop_queue, [ 5, 6, 7 ], 'queue after shift' );
is( $q_count, 1, '$q_count after shift' );

$obj->shift_prop_queue( 2 );
is_deeply( $obj->get_prop_queue, [ 7 ], 'queue after shift(2)' );
is( $q_count, 2, '$q_count after shift(2)' );

is_deeply( $queue_shadow, [ 7 ], 'queue shadow finally' );

# ARRAY

is_deeply( $obj->get_prop_array, [ 1, 2, 3 ], 'array initially' );

my $array;
my ( $a_index, $a_count, @a_values, $a_delta );
$obj->watch_property( array =>
   on_set => sub { $array = shift },
   on_push => sub { @a_values = @_ },
   on_shift => sub { ( $a_count ) = @_ },
   on_splice => sub { ( $a_index, $a_count, @a_values ) = @_ },
   on_move => sub { ( $a_index, $a_delta ) = @_ },
);

my $array_shadow;
$obj->watch_property( array =>
   on_updated => sub { $array_shadow = shift },
);

is_deeply( $array_shadow, [ 1, 2, 3 ], 'array shadow initially' );

$obj->set_prop_array( [ 4, 5, 6 ] );
is_deeply( $obj->get_prop_array, [ 4, 5, 6 ], 'array after set' );
is_deeply( $array, [ 4, 5, 6 ], '$array after set' );

$obj->push_prop_array( 7 );
is_deeply( $obj->get_prop_array, [ 4, 5, 6, 7 ], 'array after push' );
is_deeply( \@a_values, [ 7 ], '@a_values after push' );

$obj->shift_prop_array;
is_deeply( $obj->get_prop_array, [ 5, 6, 7 ], 'array after shift' );
is( $a_count, 1, '$a_count after shift' );

$obj->shift_prop_array( 2 );
is_deeply( $obj->get_prop_array, [ 7 ], 'array after shift(2)' );
is( $a_count, 2, '$a_count after shift(2)' );

$obj->splice_prop_array( 0, 0, ( 5, 6 ) );
is_deeply( $obj->get_prop_array, [ 5, 6, 7 ], 'array after splice(0,0)' );
is( $a_index, 0, '$a_index after splice(0,0)' );
is( $a_count, 0, '$a_count after splice(0,0)' );
is_deeply( \@a_values, [ 5, 6 ], '@a_values after splice(0,0)' );

$obj->splice_prop_array( 2, 1, () );
is_deeply( $obj->get_prop_array, [ 5, 6 ], 'array after splice(2,1)' );
is( $a_index, 2, '$a_index after splice(2,1)' );
is( $a_count, 1, '$a_count after splice(2,1)' );
is_deeply( \@a_values, [ ], '@a_values after splice(2,1)' );

$obj->move_prop_array( 0, 1 );
is_deeply( $obj->get_prop_array, [ 6, 5 ], 'array after move(+1)' );
is( $a_index, 0, '$a_index after move' );
is( $a_delta, 1, '$a_delta after move' );

$obj->set_prop_array( [ 0 .. 9 ] );
$obj->move_prop_array( 3, 2 );
is_deeply( $obj->get_prop_array, [ 0, 1, 2, 4, 5, 3, 6, 7, 8, 9 ], 'array after move(+2)' );

$obj->move_prop_array( 5, -2 );
is_deeply( $obj->get_prop_array, [ 0 .. 9 ], 'array after move(-2)' );

is_deeply( $array_shadow, [ 0 .. 9 ], 'array shadow finally' );
