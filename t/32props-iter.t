#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use Tangence::Registry;

use t::TestObj;
use t::TestServerClient;

my $registry = Tangence::Registry->new(
   tanfile => "t/TestObj.tan",
);
my $obj = $registry->construct(
   "t::TestObj",
);

my ( $server, $client ) = make_serverclient( $registry );
my $proxy = $client->rootobj;

my $iter;
my @value;
my $on_more = sub {
   my $idx = shift;
   @value[$idx .. $idx + $#_] = @_;
};

# Fowards from first
{
   $proxy->watch_property(
      property => "queue",
      on_set => sub { @value = @_ },
      on_push => sub { push @value, @_ },
      on_shift => sub { shift @value for 1 .. shift },
      iter_from => "first",
      on_iter => sub {
         ( $iter, undef, my $last_idx ) = @_;
         $#value = $last_idx;
      },
   );

   is_deeply( \@value, [ undef, undef, undef ], '@value initially' );

   $iter->next_forward( on_more => $on_more );

   is_deeply( \@value, [ 1, undef, undef ], '@value after first next_forward' );

   $obj->push_prop_queue( 4, 5 );

   is_deeply( \@value, [ 1, undef, undef, 4, 5 ], '@value after push' );

   $iter->next_forward( on_more => $on_more );

   is_deeply( \@value, [ 1, 2, undef, 4, 5 ], '@value after second next_forward' );

   $obj->shift_prop_queue( 1 );

   is_deeply( \@value, [ 2, undef, 4, 5 ], '@value after shift' );

   $iter->next_forward( on_more => $on_more );

   is_deeply( \@value, [ 2, 3, 4, 5 ], '@value after third next_forward' );

   $proxy->unwatch_property(
      property => "queue",
   );
}

# Reset
undef @value;
$obj->set_prop_queue( [ 1, 2, 3 ] );

# Backwards from last
{
   $proxy->watch_property(
      property => "queue",
      on_set => sub { @value = @_ },
      on_push => sub { push @value, @_ },
      on_shift => sub { shift @value for 1 .. shift },
      iter_from => "last",
      on_iter => sub {
         ( $iter, undef, my $last_idx ) = @_;
         $#value = $last_idx;
      },
   );

   is_deeply( \@value, [ undef, undef, undef ], '@value initially' );

   $iter->next_backward( on_more => $on_more );

   is_deeply( \@value, [ undef, undef, 3 ], '@value after first next_backward' );

   $obj->push_prop_queue( 4, 5 );

   is_deeply( \@value, [ undef, undef, 3, 4, 5 ], '@value after push' );

   $iter->next_backward( on_more => $on_more );

   is_deeply( \@value, [ undef, 2, 3, 4, 5 ], '@value after second next_backward' );

   $obj->shift_prop_queue( 1 );

   is_deeply( \@value, [ 2, 3, 4, 5 ], '@value after shift' );

   $iter->next_backward( on_more => $on_more );

   is_deeply( \@value, [ 2, 3, 4, 5 ], '@value after third next_backward' );

   $proxy->unwatch_property(
      property => "queue",
   );
}

done_testing;
