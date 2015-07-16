#!/usr/bin/perl

=head1 NAME

sites-ok.t - check web sites

=head SYNOPSIS

	cat >> test-server.yaml << __YAML_END__
	open-ports:
	    connect:
	        localhost:
	            22: ssh
	        bratislava.pm.org:
	            80: http
	        camel.cle.sk:
	            443: https
	__YAML_END__

=cut

use strict;
use warnings;

use Test::More;
use Test::Differences;
use Test::Exception;
use Test::Net::Service;
use YAML::Syck 'LoadFile';
use FindBin '$Bin';


eval "use IO::Socket::INET";
plan 'skip_all' => "need IO::Socket::INET to run ports open tests" if $@;

my $file_config;
if ($Bin =~ m{/.+(ce|pro)$}) {
	my $cfg_tt2 = "/etc/ngcp-tests/test-server_$1.yaml";
	if (-r $cfg_tt2) {
		$file_config = $cfg_tt2;
	}
}
my $config = LoadFile($file_config);
do {
	fail("no configuration sections for 'open-ports'");
	done_testing();
	exit 1;
} if (not $config or not $config->{'open-ports'});

my $netstat=`netstat -anu`;

exit main();

sub main {
	my $connect = $config->{'open-ports'}->{'connect'};

	# count the tests and plan them
	my $number_of_tests = 0;
	foreach my $host (keys %$connect) {
		foreach my $port (keys %{$connect->{$host}}) {
			# port connection test
			$number_of_tests ++;
			# service check for all besides closed ports
			$number_of_tests ++
				if not (($connect->{$host}->{$port} || '') eq 'closed');
		}
	}
	plan 'tests' => $number_of_tests;

	# loop through ports that needs to be working
	foreach my $host (keys %$connect) {
		my ($result)="";
		my $net_service = Test::Net::Service->new(
			'host' => $host
		);

		foreach my $port (keys %{$connect->{$host}}) {
			my $service = $connect->{$host}->{$port} || '';
			my $proto   = 'tcp';
			if ($port =~ /([0-9]+)\/(.*)/smg) {
				$port    = $1;
				$proto   = $2;
			};

			my $socket = IO::Socket::INET->new(
				PeerAddr => $host,
				PeerPort => $port,
				Proto    => $proto,
			);

			if ($proto eq "udp") {
				($result)=$netstat=~/\w+\s+\d+\s+\d+\s+[\d.:]+:$port\s+[\d:.]+:\*/;
			} else {
				($result)=$socket;
			};

			# check for closed ports
			if ($service eq 'closed') {
				ok( !$result, "connect to $service on $host port $port/$proto ($service) is filtered" );
				next;
			}

			ok( $result, "connect to $service on $host port $port/$proto ($service)" );

			# skip rest if we failed to connect
			if (not defined $result) {
				SKIP: {
					skip 'skipping service check if port open failed', 1;
				}
				next;
			}

			# skip rest if servis was not specified
			if (not $result) {
				SKIP: {
					skip 'skipping service check no service defined', 1;
				}
				next;
			}

			# skip rest if there is no test_function for the service
			if (not $net_service->can('test_'.$service)) {
				SKIP: {
					skip 'unknown service '.$service.'!!!', 1;
				}
				next;
			}

			# check the service
			lives_ok(
				sub {
					$net_service->test(
						'socket'  => $socket,
						'host'    => $host,
						'service' => $service
					)
				},
				"check $service service default response with proto $proto port $port on host"
			);
		}
	}

	return 0;
}


__END__

=head1 NOTE

Port checking depends on L<IO::Socket::INET>.

=head1 AUTHOR

Jozef Kutej

=cut
