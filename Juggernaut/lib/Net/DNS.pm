package Net::DNS;
#
# $Id: DNS.pm,v 2.109 2004/04/01 07:32:40 ctriv Exp $
#
use strict;
use vars qw(
	$HAVE_XS
	$VERSION
	$DNSSEC
	@ISA
	@EXPORT
	%typesbyname
	%typesbyval
	%qtypesbyname
	%qtypesbyval
	%metatypesbyname
	%metatypesbyval
	%classesbyname
	%classesbyval
	%opcodesbyname
	%opcodesbyval
	%rcodesbyname
	%rcodesbyval
);



BEGIN {
	require DynaLoader;
	require Exporter;
	
	@ISA     = qw(Exporter DynaLoader);
	$VERSION = '0.47';
	$HAVE_XS = eval { __PACKAGE__->bootstrap(); 1 } ? 1 : 0;
}

use Net::DNS::Resolver;
use Net::DNS::Packet;
use Net::DNS::Update;
use Net::DNS::Header;
use Net::DNS::Question;
use Net::DNS::RR;

BEGIN {
	$DNSSEC = eval { require Net::DNS::RR::SIG; 1 } ? 1 : 0;
}
 


@EXPORT = qw(mx yxrrset nxrrset yxdomain nxdomain rr_add rr_del);

#
# If you implement an RR record make sure you also add it to 
# %Net::DNS::RR::RR hash otherwise it will be treated as unknown type.
# 

# Do not use these tybesby hashes directly. Use the interface
# functions, see below.

%typesbyname = (
 	'SIGZERO'   => 0,       # RFC2931 consider this a pseudo type
	'A'			=> 1,		# RFC 1035, Section 3.4.1
	'NS'		=> 2,		# RFC 1035, Section 3.3.11
	'MD'		=> 3,		# RFC 1035, Section 3.3.4 (obsolete)
	'MF'		=> 4,		# RFC 1035, Section 3.3.5 (obsolete)
	'CNAME'		=> 5,		# RFC 1035, Section 3.3.1
	'SOA'		=> 6,		# RFC 1035, Section 3.3.13
	'MB'		=> 7,		# RFC 1035, Section 3.3.3
	'MG'		=> 8,		# RFC 1035, Section 3.3.6
	'MR'		=> 9,		# RFC 1035, Section 3.3.8
	'NULL'		=> 10,		# RFC 1035, Section 3.3.10
	'WKS'		=> 11,		# RFC 1035, Section 3.4.2 (deprecated)
	'PTR'		=> 12,		# RFC 1035, Section 3.3.12
	'HINFO'		=> 13,		# RFC 1035, Section 3.3.2
	'MINFO' 	=> 14,		# RFC 1035, Section 3.3.7
	'MX'		=> 15,		# RFC 1035, Section 3.3.9
	'TXT'		=> 16,		# RFC 1035, Section 3.3.14
	'RP'		=> 17,		# RFC 1183, Section 2.2
	'AFSDB'		=> 18,		# RFC 1183, Section 1
	'X25'		=> 19,		# RFC 1183, Section 3.1
	'ISDN'		=> 20,		# RFC 1183, Section 3.2
	'RT'		=> 21,		# RFC 1183, Section 3.3
	'NSAP'		=> 22,		# RFC 1706, Section 5
	'NSAP_PTR'	=> 23,		# RFC 1348 (obsolete)
	# The following 2 RRs are impemented in Net::DNS::SEC
 	'SIG'		=> 24,		# RFC 2535, Section 4.1
 	'KEY'		=> 25,		# RFC 2535, Section 3.1
 	'PX'		=> 26,		# RFC 2163,
	'GPOS'		=> 27,		# RFC 1712 (obsolete)
	'AAAA'		=> 28,		# RFC 1886, Section 2.1
	'LOC'		=> 29,		# RFC 1876
	# The following RR is impemented in Net::DNS::SEC
	'NXT'		=> 30,		# RFC 2535, Section 5.2
	'EID'		=> 31,		# draft-ietf-nimrod-dns-xx.txt
	'NIMLOC'	=> 32,		# draft-ietf-nimrod-dns-xx.txt
	'SRV'		=> 33,		# RFC 2052
	'ATMA'		=> 34,		# ???
	'NAPTR'		=> 35,		# RFC 2168
	'KX'		=> 36,		# RFC 2230
 	'CERT'		=> 37,		# RFC 2538
	'DNAME'		=> 39,		# RFC 2672
	'OPT'  		=> 41,		# RFC 2671
	# The following 4 RRs are impemented in Net::DNS::SEC
	# Aug 2003: These RRs will be published as RFCs shortly 
	'DS'		=> 43,		# draft-ietf-dnsext-delegation-signer
	'RRSIG'		=> 46,		# draft-ietf-dnsext-dnssec-2535typecode-change
	'NSEC'		=> 47,		# draft-ietf-dnsext-dnssec-2535typecode-change
	'DNSKEY'	=> 48,		# draft-ietf-dnsext-dnssec-2535typecode-change
	'UINFO'		=> 100,		# non-standard
	'UID'		=> 101,		# non-standard
	'GID'		=> 102,		# non-standard
	'UNSPEC'	=> 103,		# non-standard
	'TKEY'		=> 249,		# RFC 2930
	'TSIG'		=> 250,		# RFC 2931
	'IXFR'		=> 251,		# RFC 1995
	'AXFR'		=> 252,		# RFC 1035
	'MAILB'		=> 253,		# RFC 1035 (MB, MG, MR)
	'MAILA'		=> 254,		# RFC 1035 (obsolete - see MX)
	'ANY'		=> 255,		# RFC 1035
);
%typesbyval = reverse %typesbyname;


#
# typesbyval and typesbyname functions are wrappers around the similarly named
# hashes. They are used for 'unknown' DNS RR types (RFC3597)

# typesbyname returns they TYPEcode as a function of the TYPE
# mnemonic. If the TYPE mapping is not specified the generic mnemonic
# TYPE### is returned.


# typesbyval returns they TYPE mnemonic as a function of the TYPE
# code. If the TYPE mapping is not specified the generic mnemonic
# TYPE### is returned.
#

sub typesbyname {
	my $name = uc shift;

	return $typesbyname{$name} if $typesbyname{$name};

	die "Net::DNS::typesbyname() argument ($name) is not TYPE###" unless 
		$name =~ m/^\s*TYPE(\d+)\s*$/;  
	
	my $val = $1;
	
	die 'Net::DNS::typesbyname() argument larger than ' . 0xffff if $val > 0xffff;
	
	return $val;
}



sub typesbyval {
	my $val = shift;
	
	die "Net::DNS::typesbyval() argument ($val) is not numeric" unless 
		$val =~ m/^\s*\d+\s*$/;  
	
	$val =~ s/\s*//g; 
	$val =~ s/^0*//; 
	
	return $typesbyval{$val} if $typesbyval{$val};
	
	die 'Net::DNS::typesbyval() argument larger than '. 0xffff if 
		$val > 0xffff;
	
	return "TYPE$val";
}



#
# Do not use these classesby hashes directly. See below. 
#
 
%classesbyname = (
	'IN'		=> 1,		# RFC 1035
	'CH'		=> 3,		# RFC 1035
	'HS'		=> 4,		# RFC 1035
	'NONE'		=> 254,		# RFC 2136
	'ANY'		=> 255,		# RFC 1035
);
%classesbyval = reverse %classesbyname;



# classesbyval and classesbyname functions are wrappers around the
# similarly named hashes. They are used for 'unknown' DNS RR classess
# (RFC3597)

# See typesbyval and typesbyname, these beasts have the same functionality

sub classesbyname {
	my $name = uc shift;
	return $classesbyname{$name} if $classesbyname{$name};
	
	die "Net::DNS::classesbyval() argument is not CLASS### ($name)" unless 
		$name =~ m/^\s*CLASS(\d+)\s*$/;
	
	my $val = $1;
	
	die 'Net::DNS::classesbyval() argument larger than '. 0xffff if $val > 0xffff;
	
	return $val;
}



sub classesbyval {
	my $val = shift;
	
	die "Net::DNS::classesbyname() argument is not numeric ($val)" unless 
		$val=~/^\s*\d+\s*$/;
	
	$val =~ s/\s*//g;
	$val =~ s/^0*//;
	
	return $classesbyval{$val} if $classesbyval{$val};
	
	die 'Net::DNS::classesbyname() argument larger than ' . 0xffff if $val > 0xffff;
	
	return "CLASS$val";
}



# The qtypesbyval and metatypesbyval specify special typecodes
# See rfc2929 and the relevant IANA registry
# http://www.iana.org/assignments/dns-parameters


%qtypesbyname = (
	'IXFR'   => 251,  # incremental transfer                [RFC1995]
	'AXFR'   => 252,  # transfer of an entire zone          [RFC1035]
	'MAILB'  => 253,  # mailbox-related RRs (MB, MG or MR)	 [RFC1035]
	'MAILA'  => 254,  # mail agent RRs (Obsolete - see MX)	 [RFC1035]
	'ANY'    => 255,  # all records		                 [RFC1035]
);
%qtypesbyval = reverse %qtypesbyname;


%metatypesbyname = (
	'TKEY'        => 249,    # Transaction Key   [RFC2930]
	'TSIG'        => 250,    # Transaction Signature  [RFC2845]
	'OPT'         => 41,     # RFC 2671
);
%metatypesbyval = reverse %metatypesbyname;


%opcodesbyname = (
	'QUERY'	       => 0,		# RFC 1035
	'IQUERY'       => 1,		# RFC 1035
	'STATUS'       => 2,		# RFC 1035
	'NS_NOTIFY_OP' => 4,		# RFC 1996
	'UPDATE'       => 5,		# RFC 2136
);
%opcodesbyval = reverse %opcodesbyname;


%rcodesbyname = (
	'NOERROR'	=> 0,		# RFC 1035
	'FORMERR'	=> 1,		# RFC 1035
	'SERVFAIL'	=> 2,		# RFC 1035
	'NXDOMAIN'	=> 3,		# RFC 1035
	'NOTIMP'	=> 4,		# RFC 1035
	'REFUSED'	=> 5,		# RFC 1035
	'YXDOMAIN'	=> 6,		# RFC 2136
	'YXRRSET'	=> 7,		# RFC 2136
	'NXRRSET'	=> 8,		# RFC 2136
	'NOTAUTH'	=> 9,		# RFC 2136
	'NOTZONE'	=> 10,		# RFC 2136
);
%rcodesbyval = reverse %rcodesbyname;


sub version      { $VERSION; }
sub PACKETSZ  () { 512; }
sub HFIXEDSZ  () {  12; }
sub QFIXEDSZ  () {   4; }
sub RRFIXEDSZ () {  10; }
sub INT32SZ   () {   4; }
sub INT16SZ   () {   2; }



# mx()
#
# Usage:
#    my @mxes = mx('example.com', 'IN');
#
sub mx {
	my $res = ref $_[0] ? shift : Net::DNS::Resolver->new;

	my ($name, $class) = @_;
	$class ||= 'IN';

	my $ans = $res->query($name, 'MX', $class) || return;

	# This construct is best read backwords.
	#
	# First we take the answer secion of the packet.
	# Then we take just the MX records from that list
	# Then we sort the list by preference
	# Then we return it.
	# We do this into an array to force list context.
	my @ret = sort { $a->preference <=> $b->preference } 
	       	  grep { $_->type eq 'MX'} $ans->answer;


	return @ret;
}

sub yxrrset {
	return Net::DNS::RR->new_from_string(shift, 'yxrrset');
}

sub nxrrset {
	return Net::DNS::RR->new_from_string(shift, 'nxrrset');
}

sub yxdomain {
	return Net::DNS::RR->new_from_string(shift, 'yxdomain');
}

sub nxdomain {
	return Net::DNS::RR->new_from_string(shift, 'nxdomain');
}

sub rr_add {
	return Net::DNS::RR->new_from_string(shift, 'rr_add');
}

sub rr_del {
	return Net::DNS::RR->new_from_string(shift, 'rr_del');
}

1;
__END__

=head1 NAME

Net::DNS - Perl interface to the DNS resolver

=head1 SYNOPSIS

C<use Net::DNS;>

=head1 DESCRIPTION

Net::DNS is a collection of Perl modules that act as a Domain
Name System (DNS) resolver.  It allows the programmer to perform
DNS queries that are beyond the capabilities of C<gethostbyname>
and C<gethostbyaddr>.

The programmer should be somewhat familiar with the format of
a DNS packet and its various sections.  See RFC 1035 or
I<DNS and BIND> (Albitz & Liu) for details.

=head2 Resolver Objects

A resolver object is an instance of the
L<Net::DNS::Resolver|Net::DNS::Resolver> class. A program can have
multiple resolver objects, each maintaining its own state information
such as the nameservers to be queried, whether recursion is desired,
etc.

=head2 Packet Objects

L<Net::DNS::Resolver|Net::DNS::Resolver> queries return
L<Net::DNS::Packet|Net::DNS::Packet> objects.  Packet objects have five
sections:

=over 3

=item *

The header section, a L<Net::DNS::Header|Net::DNS::Header> object.

=item *

The question section, a list of L<Net::DNS::Question|Net::DNS::Question>
objects.

=item *

The answer section, a list of L<Net::DNS::RR|Net::DNS::RR> objects.

=item *

The authority section, a list of L<Net::DNS::RR|Net::DNS::RR> objects.

=item *

The additional section, a list of L<Net::DNS::RR|Net::DNS::RR> objects.

=back

=head2 Update Objects

The L<Net::DNS::Update|Net::DNS::Update> package is a subclass of
L<Net::DNS::Packet|Net::DNS::Packet> for creating packet objects to be
used in dynamic updates.  

=head2 Header Objects

L<Net::DNS::Header|Net::DNS::Header> objects represent the header
section of a DNS packet.

=head2 Question Objects

L<Net::DNS::Question|Net::DNS::Question> objects represent the question
section of a DNS packet.

=head2 RR Objects

L<Net::DNS::RR|Net::DNS::RR> is the base class for DNS resource record
(RR) objects in the answer, authority, and additional sections of a DNS
packet.

Don't assume that RR objects will be of the type you requested -- always
check an RR object's type before calling any of its methods.

=head1 METHODS

See the manual pages listed above for other class-specific methods.

=head2 version

    print Net::DNS->version, "\n";

Returns the version of Net::DNS.

=head2 mx

    # Use a default resolver -- can't get an error string this way.
    use Net::DNS;
    my @mx = mx("example.com");

    # Use your own resolver object.
    use Net::DNS;
    my $res = Net::DNS::Resolver->new;
    my  @mx = mx($res, "example.com");

Returns a list of L<Net::DNS::RR::MX|Net::DNS::RR::MX> objects
representing the MX records for the specified name; the list will be
sorted by preference. Returns an empty list if the query failed or no MX
records were found.

This method does not look up A records -- it only performs MX queries.

See L</EXAMPLES> for a more complete example.

=head2 yxrrset

Use this method to add an "RRset exists" prerequisite to a dynamic
update packet.  There are two forms, value-independent and
value-dependent:

    # RRset exists (value-independent)
    $update->push(pre => yxrrset("host.example.com A"));

Meaning:  At least one RR with the specified name and type must
exist.

    # RRset exists (value-dependent)
    $packet->push(pre => yxrrset("host.example.com A 10.1.2.3"));

Meaning:  At least one RR with the specified name and type must
exist and must have matching data.

Returns a C<Net::DNS::RR> object or C<undef> if the object couldn't
be created.

=head2 nxrrset

Use this method to add an "RRset does not exist" prerequisite to
a dynamic update packet.

    $packet->push(pre => nxrrset("host.example.com A"));

Meaning:  No RRs with the specified name and type can exist.

Returns a C<Net::DNS::RR> object or C<undef> if the object couldn't
be created.

=head2 yxdomain

Use this method to add a "name is in use" prerequisite to a dynamic
update packet.

    $packet->push(pre => yxdomain("host.example.com"));

Meaning:  At least one RR with the specified name must exist.

Returns a C<Net::DNS::RR> object or C<undef> if the object couldn't
be created.

=head2 nxdomain

Use this method to add a "name is not in use" prerequisite to a
dynamic update packet.

    $packet->push(pre => nxdomain("host.example.com"));

Meaning:  No RR with the specified name can exist.

Returns a C<Net::DNS::RR> object or C<undef> if the object couldn't
be created.

=head2 rr_add

Use this method to add RRs to a zone.

    $packet->push(update => rr_add("host.example.com A 10.1.2.3"));

Meaning:  Add this RR to the zone.

RR objects created by this method should be added to the "update"
section of a dynamic update packet.  The TTL defaults to 86400
seconds (24 hours) if not specified.

Returns a C<Net::DNS::RR> object or C<undef> if the object couldn't
be created.

=head2 rr_del

Use this method to delete RRs from a zone.  There are three forms:
delete an RRset, delete all RRsets, and delete an RR.

    # Delete an RRset.
    $packet->push(update => rr_del("host.example.com A"));

Meaning:  Delete all RRs having the specified name and type.

    # Delete all RRsets.
    $packet->push(update => rr_del("host.example.com"));

Meaning:  Delete all RRs having the specified name.

    # Delete an RR.
    $packet->push(update => rr_del("host.example.com A 10.1.2.3"));

Meaning:  Delete all RRs having the specified name, type, and data.

RR objects created by this method should be added to the "update"
section of a dynamic update packet.

Returns a C<Net::DNS::RR> object or C<undef> if the object couldn't
be created.

=head1 EXAMPLES

The following examples show how to use the C<Net::DNS> modules.
See the other manual pages and the demo scripts included with the
source code for additional examples.

See the C<Net::DNS::Update> manual page for an example of performing
dynamic updates.

=head2 Look up a host's addresses.

  use Net::DNS;
  my $res   = Net::DNS::Resolver->new;
  my $query = $res->search("host.example.com");
  
  if ($query) {
      foreach my $rr ($query->answer) {
          next unless $rr->type eq "A";
          print $rr->address, "\n";
      }
  } else {
      warn "query failed: ", $res->errorstring, "\n";
  }

=head2 Find the nameservers for a domain.

  use Net::DNS;
  my $res   = Net::DNS::Resolver->new;
  my $query = $res->query("example.com", "NS");
  
  if ($query) {
      foreach $rr (grep { $_->type eq 'NS' } $query->answer) {
          print $rr->nsdname, "\n";
      }
  }
  else {
      warn "query failed: ", $res->errorstring, "\n";
  }

=head2 Find the MX records for a domain.

  use Net::DNS;
  my $name = "example.com";
  my $res  = Net::DNS::Resolver->new;
  my @mx   = mx($res, $name);
  
  if (@mx) {
      foreach $rr (@mx) {
          print $rr->preference, " ", $rr->exchange, "\n";
      }
  } else {
      warn "Can't find MX records for $name: ", $res->errorstring, "\n";
  }


=head2 Print a domain's SOA record in zone file format.

  use Net::DNS;
  my $res   = Net::DNS::Resolver->new;
  my $query = $res->query("example.com", "SOA");
  
  if ($query) {
      ($query->answer)[0]->print;
  } else {
      print "query failed: ", $res->errorstring, "\n";
  }

=head2 Perform a zone transfer and print all the records.

  use Net::DNS;
  my $res  = Net::DNS::Resolver->new;
  $res->nameservers("ns.example.com");
  
  my @zone = $res->axfr("example.com");
  
  foreach $rr (@zone) {
      $rr->print;
  }

=head2 Perform a background query and do some other work while waiting
for the answer.

  use Net::DNS;
  my $res    = Net::DNS::Resolver->new;
  my $socket = $res->bgsend("host.example.com");

  until ($res->bgisready($socket)) {
      # do some work here while waiting for the answer
      # ...and some more here
  }

  my $packet = $res->bgread($socket);
  $packet->print;


=head2 Send a background query and use select to determine when the answer
has arrived.

  use Net::DNS;
  use IO::Select;
  
  my $timeout = 5;
  my $res     = Net::DNS::Resolver->new;
  my $bgsock  = $res->bgsend("host.example.com");
  my $sel     = IO::Select->new($bgsock);
  
  # Add more sockets to $sel if desired.
  my @ready = $sel->can_read($timeout);
  if (@ready) {
      foreach my $sock (@ready) {
          if ($sock == $bgsock) {
              my $packet = $res->bgread($bgsock);
              $packet->print;
              $bgsock = undef;
          }
	      # Check for the other sockets.
	      $sel->remove($sock);
	      $sock = undef;
      }
  } else {
      warn "timed out after $timeout seconds\n";
  }

=head1 BUGS

C<Net::DNS> is slow.

For other items to be fixed, please see the TODO file included with
the source distribution.

=head1 COPYRIGHT

Copyright (c) 1997-2002 Michael Fuhr. 

Portions Copyright (c) 2002-2003 Chris Reinhardt.

All rights reserved.  This program is free software; you may redistribute
it and/or modify it under the same terms as Perl itself.

=head1 AUTHOR INFORMATION

Net::DNS is currently maintained by a group, led by:
	Chris Reinhardt
	ctriv@net-dns.org

Net::DNS was created by:
	Michael Fuhr
	mike@fuhr.org

For more information see:
	http://www.net-dns.org/

=head1 SEE ALSO
 
L<perl(1)>, L<Net::DNS::Resolver>, L<Net::DNS::Packet>, L<Net::DNS::Update>,
L<Net::DNS::Header>, L<Net::DNS::Question>, L<Net::DNS::RR>, RFC 1035,
I<DNS and BIND> by Paul Albitz & Cricket Liu

=cut
