package Net::IRR;

use strict;
use warnings;

use Carp;
use Net::TCP;

use vars qw/ @ISA %EXPORT_TAGS @EXPORT_OK $VERSION /;

$VERSION = '0.02';

#  used for route searches
use constant EXACT_MATCH   => 'o';
use constant ONE_LEVEL     => 'l';
use constant LESS_SPECIFIC => 'L';
use constant MORE_SPECIFIC => 'M';

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK   = qw( EXACT_MATCH ONE_LEVEL LESS_SPECIFIC MORE_SPECIFIC );
%EXPORT_TAGS = ( 
    'all'   => \@EXPORT_OK,
    'route' => \@EXPORT_OK,
);

#  constructor
sub connect {
    my ($class, %args) = @_;
    my $self = bless {}, ref($class) || $class;
    $self->{host} = $args{host} || '127.0.0.1';
    $self->{port} = $args{port} || 43;
    my $error;
    eval {
        local $SIG{__WARN__} = sub { $error = shift };
        $self->{tcp} = Net::TCP->new($self->{host}, $self->{port});
    };
    return undef if $error;
    $self->_multi_mode();
    $self->_identify();
    return $self; 
}

sub get_routes_by_origin {
    my ($self, $as) = @_;
    croak("usage: \$whois->get_routes_by_community( \$as_number )") unless @_ == 2;
    $as = 'as'.$as unless $as =~ /^as/i;
    $self->{tcp}->send("!g${as}\n");
    if (my $data = $self->_response()) {
        return (wantarray) ? split(" ", $data) : $data;
    }
    return ();
}

# RIPE-181 Only
sub get_routes_by_community {
    my ($self, $community) = @_;
    croak("usage: \$whois->get_routes_by_community( \$community )") unless @_ == 2;
    $self->{tcp}->send("!h${community}\n");
    if (my $data = $self->_response()) {
        return (wantarray) ? split(" ", $data) : $data;
    }
    return ();
}

sub get_sync_info {
    my ($self, @dbs) = @_;
    my $dbs = (@dbs) ? join(",",@dbs) : '-*';
    $self->{tcp}->send("!j${dbs}\n");
    return $self->_response();
}

sub get_as_set {
    my ($self, $as_set, $expand) = @_;
    croak("usage: $\whois->get_as_set( \$as_set )") unless @_ >= 2 && @_ <= 3;
    $expand = ($expand) ? ',1' : '';
    $self->{tcp}->send("!i${as_set}${expand}\n");
    if (my $data = $self->_response()) {
        return (wantarray) ? split(" ", $data) : $data;
    }
    return ();
}

sub match {
    my ($self, $type, $key) = @_;
    croak("usage: \$whois->match( \$object_type, \$key )") unless @_ == 3;
    $self->{tcp}->send("!m${type},${key}\n");
    return $self->_response();
}

*disconnect = \&quit;
sub quit { 
    my $self = shift; 
    $self->{tcp}->send("!q\n"); 
}

sub _identify {
    my ($self) = @_;
    $self->{tcp}->send("!nIRR.pm\n");
    return $self->_response();
}

sub _multi_mode {
    my ($self) = @_;
    $self->{tcp}->send("!!\n");
    return 1;
}

sub get_irrd_version {
    my ($self) = @_;
    $self->{tcp}->send("!v\n");
    return $self->_response();
}

sub route_search {
    my ($self, $route, $specific) = @_;
    croak("usage: \$whois->route_search( \$route )") unless @_ >= 2 && @_ <= 3;
    my $cmd = "!r${route}";
    $cmd .= ",${specific}" if $specific;
    $self->{tcp}->send("$cmd\n");
    my $response = $self->_response();
    # clean the output up a little
    chomp($response);
    $response =~ s/\s*$//;
    return $response;
}

sub sources {
    my ($self, @sources) = @_;
    my $source = (@sources) ? join(",", @sources) : '-lc';
    $self->{tcp}->send("!s${source}\n");
    return $self->_response();
}

sub update {
    my ($self, $db, $action, $object) = @_;
    croak("usage: \$whois->update( \$db, \"ADD|DEL\", \$object )") unless @_ == 4;
    croad("second argument to \$whois->update() must be either ADD or DEL\n")
        unless $action eq 'ADD' || $action eq 'DEL';
    $self->{tcp}->send("!us${db}\n${action}\n\n${object}\n\n!ue\n");
    return $self->_response();
}

sub _response {
    my $self = shift;
    my $t = $self->{tcp};
    my $header = $t->getline();
    return () if ($header =~ /^[CDEF].*$/);
    my($data_length) = $header =~ /^A(.*)$/;
    my $data = '';
    while($data_length != length($data)) {
        $data .= $t->getline();
    }
    warn "only got " . length($data) . " out of $data_length bytes\n" 
        if $data_length != length($data);
    my $footer = $t->getline();
    return $data;
}

sub error {
    my $self = shift;
    return $self->{errstr};
}

1;
__END__

=pod

=head1 NAME

Net::IRR - Perl interface to the Internet Route Registry Daemon

=head1 SYNOPSIS

  use Net::IRR qw/ :route /;

  my $host = 'whois.radb.net';

  my $i = Net::IRR->connect( host => $host ) 
      or croak "can't connect to $host";

  print "IRRd Version: " . $i->get_irrd_version() . "\n";

  print "Routes by Origin AS5650\n";
  my @routes = $i->get_routes_by_origin("AS5650");
  print "found $#routes routes\n";

  print "AS-SET for AS5650\n";
  if (my @ases = $i->get_as_set("AS-ELI")) {
      print "found $#ases AS's\n";
      print "@ases\n";
  }
  else {
      print "none found\n";
  }

  my $aut-num = $i->match("aut-num","as5650");
      or warn("Can't find object: " . $i->error . "\n");

  print $i->route_search("208.186.0.0/15", EXACT_MATCH) 
      . " originates 208.186.0.0/15\n";

  print "Syncronization Information\n";
  print $i->get_sync_info(), "\n";

  $i->disconnect();

=head1 DESCRIPTION

This module provides an object oriented perl interface to the Internet Route Registry.  The interface uses the RIPE/RPSL Tool Query Language as defined in Appendix B of the IRRd User Guide.  The guide can be found at http://www.irrd.net/, however an understanding of the query language is not required to use this module.  Net::IRR supports IRRd's multiple-command mode.  Multiple-command mode is good for intensive queries since only one TCP connection needs to be made for multiple queries.  The interface also allows for additional queries that aren't supported by standard UNIX I<whois> utitilies.  Hopefully this module will stimulate development of new Route Registry tools written in Perl.  An example of Route Registry tools can be found by googling for RAToolset which is now known as the IRRToolset.  The RAToolset was originally developed by ISI, http://www.isi.edu/, and is now maintained by RIPE, http://www.ripe.net/.

=head1 METHODS

=over 4

=item Net::IRR->connect( host => $hostname, port => $port_number )

This class method is used to connect to a route registry server.  Net::IRR->connect() is also the constructor for the Net::IRR class.  The constructor returns a Net::IRR object upon connection to the IRR server or undef upon failure.

=item $whois->disconnect()

This method closes the connection to the route registry server.

=item $whois->quit()

Same as $whois->disconnect().

=item $whois->get_routes_by_origin('AS5650')

Get routes with a specified origin AS.  This method takes an autonomous system number and returns the set of routes it originates.  Upon success this method returns a list of routes in list context or a string of space seperated routes.  undef is returned upon failure.

=item $whois->get_routes_by_community($community_name)

This method is for RIPE-181 only.  It is not supported by RPSL.  This method takes a community object name  and returns the set of routes it originates.  Upon success this method returns a list of routes in list context or a string of space seperated routes.  undef is returned upon failure.

=item $whois->get_sync_info()

This method provides database syncronization information.  This makes it possible to view the mirror status of a database.  This method optionally takes the name of a database such as RADB or ELI.  If no argument is given the method will return information about all databases originating from and mirrored by the registry server.  If the optional argument is given the database specified will be checked and it's status returned.  This method returns undef if no database exists or if access is denied.

=item $whois->get_as_set("AS-ELI", 1)

This method takes an AS-SET object name and returns the ASNs registered for the AS-SET object.  The method takes and optional second argument which enables AS-SET key expasion since an AS-SET can contain both ASNs and AS-SET keys.  undef is returned upon failure.

=item $whois->match('aut-num', 'AS5650'); - get RPSL objects registered in the database

The example above will retrieve the aut-num object with the key AS5650.  This method will return the first RPSL object matching the object type and name specified as parameters to $whois->match().  undef is returned upon failure.

=item $whois->get_irrd_version()

This methods takes no arguments and returns the version of the IRRd server that was specified as the hostname to the connect() method.

=item $whois->route_search("208.186.0.0/15", EXACT_MATCH)

The method is used to search for route objects.  The method takes two arguments, a route and an optional flag.  The flag can be one of four values: EXACT_MATCH, LEVEL_ONE, LESS_SPECIFIC, MORE_SPECIFIC.  These constants can be imported into your namespace by using the :all or :route export tag when importing the Net::IRR module.

    use Net::IRR qw( :route );

    print "EXACT_MATCH = " . EXACT_MATCH . "\n";

=item $whois->sources()

This method is used to both get and set the databases used for Internet Route Registry queries.  The $whois->sources() method accepts a list of databases in the order they should be searched.  If no arguments are given the method will return a list of all the databases mirrored by the route registry you are connected to.

=item $whois->update($database, 'ADD', $rpsl_rr_object)

This method is used to add or delete a database object.  This method takes three arguments.   The first argument is the database to update.  The second arguemnt is the action which can be either "ADD" or "DEL".  The third and final required arguement is a route object in RPSL format.

=item $whois->error()

Most Net::IRR methods set an error message when errors occur.  These errors can only be accessed by using the error() method.

=back

=head1 AUTHOR

Todd Caine  <tcaine@eli.net>

=head1 SEE ALSO

Main IRRd Site

http://www.irrd.net/

RIPE/RPSL Tool Query Language

http://www.irrd.net/irrd-user.pdf, Appendix B

=head1 COPYRIGHT

Copyright 2002, 2003, 2004 by Todd Caine.  All rights reserved.  This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


=cut
