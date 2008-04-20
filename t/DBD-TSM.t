#!/usr/bin/perl

# %W%

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl DBD-TSM.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More;
use Data::Dumper;

BEGIN { 
    use_ok('DBI');
    use_ok('DBD::TSM'); 
};

my @os_tested_by_user = qw(aix darwin linux Win32);
my %os_tested_by_user = map {$_ => 1} @os_tested_by_user;

unless (exists $os_tested_by_user{$^O}) {
    plan skip_all => "Never tested '$^O' by me or an other user. Change \@os_tested_by_user in '$0' and inform me, if tests run successfully";
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

plan tests => 12; 

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
my $raw = $sth->{tsm_raw};
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
my $select = "select * from domains, nodes where domains.DOMAIN_NAME = nodes.DOMAIN_NAME";
$sth = $dbh->prepare($select);
#print Dumper($sth, $dbh, DBI::errstr);
ok($sth, "Prepare: $select");
ok($sth->execute(), "Execute: $select");
#print Dumper($sth->{tsm_raw});
ok($sth->fetchall_hashref('NODE_NAME'), "Fetchall: $select");
$sth->finish();
my $command = "show threads";

$sth = $dbh->prepare($command);
ok($sth, "Prepare: $command");
ok($sth->execute(), "Execute: $command");
my $raw_data_ref = $sth->{tsm_raw};
#print @{$raw_data_ref};
ok(@{$raw_data_ref}, "Get raw data \$sth->{tsm_raw}");
