package Net::Async::Redis;

use strict;
use warnings;

use base qw( IO::Async::Notifier );
use Data::Dumper::Concise;
use Scalar::Util qw[ weaken ];

use IO::Async::Stream;
use Protocol::RESP;
use Future::Utils qw[ repeat ];
use Try::Tiny;

sub CRLF { "\r\n" }

my $resp = Protocol::RESP->new;

sub connect {
    my $self   = shift;
    $self->{_reqs} = [];
    my (%args) = @_;
    my $host   = delete $args{host};
    my $port   = delete $args{port};
    my $f      = $self->loop->connect(
        addr => {
            family   => "inet",
            socktype => "stream",
            port     => $port,
            ip       => $host,
        },
      )->then_with_f(
        sub {
            my ( $f, $socket ) = @_;
            my $_redis = IO::Async::Stream->new(
                read_handle  => $socket,
                write_handle => $socket,
                on_read      => sub {
                    return 0;
                } );
            return Future->wrap( [ $_redis, $socket ] );
        }
      )->else_with_f(
        sub {
            my ( $f1, $exception, @details ) = @_;
            die Dumper( [ $exception, @details ] );
        } );
    my ( $_redis, $socket ) = @{ $f->get };
    $self->loop->add($_redis);
    return $self->{_redis} = $_redis;
}
#our $AUTOLOAD;
#sub AUTOLOAD {
#    my $self = shift;
#    my $cmd = $AUTOLOAD;
#    warn @_;
#}
#
sub del { shift->command("DEL",@_); }

sub set { shift->command("SET",@_); }

sub get { shift->command("GET",@_); }

sub command {
    my ( $self, $cmd, @args ) = @_;
    $cmd = uc($cmd);
    my $str = $self->__format_command( $cmd, @args );
    my $redis = $self->{_redis};
    weaken($redis);
    my $CRLF = CRLF;
    return my $write_future = $redis->write($str)->then(
        sub {
            my $f   = Future->new;
            my $buf = '';
            $redis->push_on_read(
                sub {
                    my ( undef, $buffref, $eof ) = @_;
                    while ( $$buffref =~ s/^(.*$CRLF)// ) {
                        $buf .= $1;
                        my ( $ret, $continue );
                        try {
                            $ret = $resp->parse($buf);
                        }
                        catch {
                            if (/incomplete parse/) {
#                                warn "incomplete parse!";
                                $continue++;
                            }
                            else {
                                die $_;
                            }
                        };
                        return $continue if $continue;
#                        warn sprintf( "got ret: [%s]" => Dumper($ret) );
                        $f->done($ret);
                        $buf = '';
                        return undef;
                    }

                } );
            return $f;
        } );
}
sub __format_command {
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

1;
