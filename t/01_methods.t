
use Test::More tests => 10;

use_ok('Net::IRR');

my $host = 'whois.radb.net';
my $i = Net::IRR->connect( host => $host );
ok( $i, "connected to $host" );

ok ($i->get_irrd_version, 'IRRd version number found');

my @routes = $i->get_routes_by_origin("AS5650");
my $found = scalar @routes;
ok ($found, "found $found routes for AS5650");

if (my @ases = $i->get_as_set("AS-ELI", 1)) {
    my $found = scalar @ases;
    ok ($found, "found $found ASNs in the AS-ELI AS set.");
}
else {
    fail('no ASNs found in the AS-ELI AS set');
}

my $person = $i->match("aut-num","as5650");
ok($person, "found an aut-num object for AS5650");

my $origin = $i->route_search("208.186.0.0/15", 'o');
ok( $origin, "$origin originates 208.186.0.0/15" );

my $origin1 = $i->route_search("10.0.0.0/8", 'o');
ok( not(defined($i->error())), "RFC1918 addresses 10.0.0.0/8 were not found" );

my $info = $i->get_sync_info();
ok($info, 'found syncronization information');

ok($i->disconnect(), 'diconnect was successful');

