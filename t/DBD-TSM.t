#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl DBD-TSM.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 14;
BEGIN { 
use_ok('DBI');
use_ok('DBD::TSM'); 
};

no warnings;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

#Use standard variable

ok(($^O eq 'aix' or $^O eq 'linux' or $^O eq 'Win32'),"Test OS supported (aix|linux|win32)");
ok($ENV{DBI_DSN} ne '',"Test environment variable DBI_DSN");
ok($ENV{DBI_USER} ne '',"Test environment variable DBI_USER");
ok($ENV{DBI_PASS} ne '',"Test environment variable DBI_PASS");
exit(2) unless ($ENV{DBI_DSN}   and
                $ENV{DBI_PASS}  and
                $ENV{DBI_USER});

#Connect test        
my $dbh=DBI->connect(undef,undef,undef,
                     { 
                       PrintError => 0,
                       RaiseError => 0
 
                    });
ok($dbh ne undef,"Connect to $ENV{DBI_DSN} as $ENV{DBI_USER}/****");
exit(2) unless ($dbh);

#Do test
$sth=$dbh->do('query status');
ok($sth ne undef,"Do statement");

#Prepare/Execute test
my $sth=$dbh->prepare('query ?');
ok($sth ne undef,"Prepare statement");
exit(2) unless($sth);
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
