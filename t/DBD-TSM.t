#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl DBD-TSM.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More;

BEGIN { 
    use_ok('DBI');
    use_ok('DBD::TSM'); 
};

unless ($^O eq 'aix' or $^O eq 'linux' or $^O eq 'Win32') {
    plan skip_all => "Not supported for $^0";
    exit(0);
}

unless ($ENV{DBI_DSN} && $ENV{DBI_USER} && $ENV{DBI_PASS}) {
    plan skip_all => "Environment DBI_USER / DBI_PASS / DBI_DSN not set";
    exit(0);
}

my $dbh=DBI->connect(undef,undef,undef,
                     { 
                       PrintError => 0,
                       RaiseError => 0
                     }
                     );

unless ($dbh) {
    plan skip_all => "No TSM started";
    exit(0);
}

plan tests => 7; 

no warnings;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

#Use standard variable

#Do test
$sth=$dbh->do('query status');
ok($sth ne undef,"Do statement");

#Prepare/Execute test
my $sth=$dbh->prepare('query ?');
ok($sth ne undef,"Prepare statement");
exit(0) unless($sth);
$sth->execute('status');
ok($sth->{NAME}->[0] eq 'Server Name',"Execute statement");
while (my $row=$sth->fetchrow_hashref()) {
    if (exists $row->{'Server URL'}) {
        ok($row->{'Server Name'} ne '',"Fetch data");
        last;
    }
}
$dbh->do("query node MYJUNKNODE");
ok($dbh->err == 11,"Check empty statement return code");
ok($sth->finish() == 1,"Finish statement");
ok($dbh->disconnect() eq undef,"Disconnect");
