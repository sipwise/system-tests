#!/usr/bin/perl

=head1 NAME

hostname-and-interfaces - check hostname and ip resolution on interfaces

=head2 SYNOPSIS

	NONE

=head2 DESCRIPTION

Checks the hostname short name and fqdn. Cheks the ip adresses on the interfaces
if resolv to some hostname.

=cut

use strict;
use warnings;

use Test::More 'tests' => 3;
use Test::Differences;

use List::MoreUtils 'any';
use Sys::Net 'resolv', 'interfaces';

my $HOSTNAME_CMD = 'hostname';

exit main();


sub main {
	my $hostname_short_ip;
	my $hostname_fqdn_ip;
	SKIP: {
		my $hostname = `$HOSTNAME_CMD`;
		skip 'hostname command not found', 2
			if not defined $hostname;

		my $hostname_short = `$HOSTNAME_CMD --short`;
		$hostname_short    =~ s/^\s*(.*)\s*$/$1/;
		diag 'short hostname - ', $hostname_short
			if $ENV{TEST_VERBOSE};
		my $hostname_fqdn  = `$HOSTNAME_CMD --fqdn`;
		$hostname_fqdn     =~ s/^\s*(.*)\s*$/$1/;
		diag 'fqdn hostname  - ', $hostname_fqdn
			if $ENV{TEST_VERBOSE};

		is($hostname_short . '.', $hostname_fqdn, 'short hostname should be the same as fqdn (ignoring trailing dot)');

		# short hostname from fqdn
		my ($short) = split /\./, $hostname_fqdn;

		is($short, $hostname_short, 'check short hostname');

		# resolv ip-s for short and fqdn hostname
		$hostname_short_ip = resolv($hostname_short);
		$hostname_fqdn_ip  = resolv($hostname_fqdn);
		is(
			$hostname_short_ip,
			$hostname_fqdn_ip,
			'ip-s of short hostname and fqdn should be the same - '.$hostname_fqdn_ip,
		);
	}

	return 0;
}


__END__

=head1 AUTHOR

Jozef Kutej

=cut
