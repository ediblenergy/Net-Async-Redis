package Net::Async::HTTP::Connection;

use strict;
use warnings;

use base qw( IO::Async::Stream );

sub _build__redis {
    my $self = shift;
    my $f    = $self->loop->connect(
        addr => {
            family   => "inet",
            socktype => "stream",
            port     => $self->redis_port,
            ip       => "localhost",
        },
      )->then_with_f(
        sub {
            my ( $f, $socket ) = @_;
            my $stream = IO::Async::Stream->new(
                read_handle  => $socket,
                write_handle => $socket,
                on_read      => sub {
                    my ( undef, $buffref, $eof ) = @_;
                    while ( $$buffref =~ s/^(.*\n)// ) {
                        print "Received a line: $1";
                    }
                    return 0;
                } );
            return Future->wrap( [ $stream, $socket ] );
          }
      )->else_with_f(
        sub {
            my ( $f1, $exception, @details ) = @_;
            die Dumper( [ $exception, @details ] );
        } );
    my $arr = $f->get;
    my ( $stream, $socket ) = @$arr;
    $self->loop->add($stream);
    return $stream;
}

sub __send_command {
  my $self = shift;
  my $cmd  = uc(shift);
  my @cmd     = split /_/, $cmd;
  my $n_elems = scalar(@_) + scalar(@cmd);
  my $buf     = "\*$n_elems\r\n";
  for my $bin (@cmd, @_) {
    # force to consider inputs as bytes strings.
    Encode::_utf8_off($bin);
    $buf .= defined($bin) ? '$' . length($bin) . "\r\n$bin\r\n" : "\$-1\r\n";
  }

  ## Check to see if socket was closed: reconnect on EOF
  return $buf;
}

sub redis_send {
    my ( $self, $cmd, @args ) = @_;
    my $str = $self->__send_command($cmd,@args);
    my $redis = $self->_redis;
    weaken( $redis );
    warn $str;
    $self->loop->later(sub{ $redis->write($str) });
}
1;
