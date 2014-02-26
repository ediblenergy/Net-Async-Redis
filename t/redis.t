use strict;
use warnings;
use Test::More;
use Net::Async::Redis;
use IO::Async::Loop;
use Test::RedisServer;
use Data::Dumper::Concise;
my $loop = IO::Async::Loop->new;

#my $r= Test::RedisServer->new(
#    conf => {
#        port => 9999,
#    } );
#warn Dumper( $r->connect_info );
my $redis = Net::Async::Redis->new;
$loop->add($redis);
$redis->connect(
    host => 'localhost',
    port => 6379,
);
my $f_del = $redis->del("foo");
$f_del->get;
#is $f_del->get,0,"del returns 0";
my $f = $redis->set("foo","bar");
is $f->get,"OK","got OK from set";
is $redis->get("foo")->get, "bar";
$loop->delay_future( after => 3 )->on_done( sub { $loop->stop } );
$loop->loop_forever;
done_testing;
