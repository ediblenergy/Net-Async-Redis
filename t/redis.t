use strict;
use warnings;
use Test::More;
use Net::Async::Redis;
use IO::Async::Loop;
use Test::RedisServer;
use Data::Dumper::Concise;
my $loop = IO::Async::Loop->new;
my $p = 9999;
my $r= Test::RedisServer->new(
    conf => {
        port => $p,
    } );
warn "redis instantiated";
#warn Dumper( $r->connect_info );
my $redis = Net::Async::Redis->new;
$loop->add($redis);
$redis->connect(
    host => 'localhost',
    port => $p,
);
my $f_del = $redis->del("foo");
$f_del->get;
#is $f_del->get,0,"del returns 0";
my $f = $redis->set("foo","bar");
is $f->get,"OK","got OK from set";
is $redis->get("foo")->get, "bar";
my %floops = ( hey => 'you', chipz => 'ahoy' );
$redis->command( 'hmset', floops => %floops );

is_deeply +{ @{ $redis->command('hgetall', 'floops' )->get } }, \%floops, "got back floops";
warn(
    "dump:" . Dumper( { @{ $redis->command( 'hgetall', 'floops' )->get } } ) );
$loop->delay_future( after => 2 )->on_done( sub { $loop->stop } );
$loop->loop_forever;
done_testing;
