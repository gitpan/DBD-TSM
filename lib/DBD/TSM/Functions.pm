package DBD::TSM::Functions;

use strict;
use warnings;
use Exporter;
use Carp;

use File::Spec;

use constant DEBUG => 0;

our $VERSION='0.01';

##
## Automatically replace during installation
##

use constant TSM_DSMADMC => 'REPLACE_DURING_INSTALL';
use constant TSM_DSMDIR  => 'REPLACE_DURING_INSTALL';
use constant TSM_DSMCONFIG  => 'REPLACE_DURING_INSTALL';

BEGIN {
    DEBUG && require Data::Dumper;
    DEBUG && import Data::Dumper;
}

our @ISA    = qw(Exporter);
our @EXPORT = qw(tsm_connect tsm_data_sources tsm_execute);

# I do my best effort
sub tsm_choose_dsm_dir {
    if (exists $ENV{DSM_DIR}    and
        -d $ENV{DSM_DIR}        and
        exists $ENV{DSM_CONFIG} and
        -f $ENV{DSM_CONFIG}
        ) {
        my $dsm_config=(-f File::Spec->catfile($ENV{DSM_DIR},"dsm.sys"))?File::Spec->catfile($ENV{DSM_DIR},"dsm.sys"):
                                                                         File::Spec->catfile($ENV{DSM_CONFIG});        
        return ($ENV{DSM_DIR},
                File::Spec->catfile($ENV{DSM_DIR},"dsmadmc"),
                $dsm_config,
                );
    }
    if (-x TSM_DSMADMC   and
        -d TSM_DSMDIR    and
        -f TSM_DSMCONFIG
        ) {
        return (TSM_DSMDIR,TSM_DSMADMC,TSM_DSMCONFIG);
    }
    
    croak(__PACKAGE__,"->tsm_choose_dsm_dir: Cannot found DSM_DIR, DSMADMC, DSM_CONFIG\n");
    return; #Never here
}

sub tsm_connect {
    my ($dbh,$dbname,$user,$auth)=@_;
    
    DEBUG && print "DEBUG - ",__PACKAGE__,"->tsm_connect: ",Dumper(\@_);
    
    $dbname=uc($dbname);
    
    my ($dsm_dir,$dsmadmc)=tsm_choose_dsm_dir();
    $ENV{DSM_DIR} = $ENV{DSM_DIR} || $dsm_dir;

    unless (tsm_data_sources($dbh,$dbname)) {
        $dbh->set_err(1,"Connect: Invalid dbname '$dbname'.");
        return;
    }
    
    @{$dbh->{tsm_connect}}=($dsmadmc,"-servername=$dbname","-id=$user","-password=$auth");
    
    my @cmd=(@{$dbh->{tsm_connect}},"-quiet","query status");
    
    DEBUG && print "DEBUG - ",__PACKAGE__,"->tsm_connect: @cmd\n";
    
    open(DSMADMC, '-|', @cmd);
    close(DSMADMC);
    if ($?) {
        $dbh->set_err(1,"Connect: Invalid user id or password '$user/$auth'.");
        return;
    }
    
    return 1;
}

sub tsm_data_sources {
    my ($dbh,$data_source)=@_;
    
    my $dsm_dir=$ENV{DSM_DIR};
    
    unless (-d $dsm_dir) {
        $dbh->DBI::set_err(1,"data sources: could not parse directory '$dsm_dir'.");
        return;
    }
    
    my $dsm_sys=File::Spec->catfile($dsm_dir,'dsm.sys');
    
    DEBUG && print "DEBUG - ",__PACKAGE__,"->tsm_data_sources: dsm.sys = $dsm_sys\n";
    
    unless (-r $dsm_sys) {
        $dbh->DBI::set_err(1,"data sources: could not read file '$dsm_sys'.");
        return;
    }
    
    my $fh;
    unless (open $fh, '<', $dsm_sys) {
        $dbh->DBI::set_err(1,"data sources: could not open file '$dsm_sys'.");
        return;
    }
    
    my %data_sources;
    local $_;
    while (<$fh>) {
        chomp;
        if (my ($server_name) = (m/^\s*[sS][eE]\w*\s+(\S+)/) ) {
            $data_sources{uc($server_name)}++;
        }
    }
    close $fh;
    
    DEBUG && print "DEBUG - ",__PACKAGE__,"->tsm_data_sources: ",Dumper(\%data_sources);
    
    if ($data_source) {
        if (exists $data_sources{$data_source}) {
            return 1;
        } else {
            $dbh->DBI::set_err(1,"data sources: could not find data source '$data_source'.");
            return;
        }
    }
    
    my @data_sources=keys(%data_sources);
    map {s/^/DBI:TSM:/} @data_sources;
    
    return (@data_sources);
}

sub tsm_execute {
    my ($sth,$statement)=@_;
    
    DEBUG && print "DEBUG - ",__PACKAGE__,"->tsm_execute: AutoCommit = ",$sth->FETCH('AutoCommit'),"\n";
    my @cmd=@{$sth->{Database}->{tsm_connect}};
    push(@cmd,'-itemcommit') if ($sth->FETCH('AutoCommit'));
    push(@cmd,'-noconfirm','-displaymode=list',$statement);
    
    DEBUG && print "DEBUG - ",__PACKAGE__,"->tsm_execute: command = \"",join('" "',@cmd),"\"\n";
    
    my $ch;
    unless (open $ch, '-|', @cmd) {
        $sth->DBI::set_err(1,"Cannot open '@cmd'.\n");
        return;
    }
    
    my $rc=0;
    my $cursor=0;
    my $errstr="";
    
    my (@data,@fields,%fields);
    local $_;
    while (<$ch>) {
        $errstr.=$_ if m/^[A-Z][A-Z][A-Z]\d\d\d\d[^I]/;
        chomp;
        $rc=$1 if (m/^ANS8002I\s+Highest\s+return\s+code\s+was\s+(-?\d+)./);
        
        if (m/^ANS8000I/ ... m/^ANS8002I/) {
            next if (m/^ANS8000I/ or m/^ANS8002I/);
            next if (m/^\s*AN[SR]/);
            
            if ( my ($field,$value) = (m/\s*([^:]+):\s+(.*)/) ) {
                # Détection des champs
                $cursor=$fields{$field} || 0;
                
                push(@{$data[$cursor]},$value);
                
                # Incrémente les nouveaux champs
                $fields{$field}++;
                
                # Ajout des champs dans l'ordre
                push(@fields,$field) unless $cursor;
                next;
            }
        }
    }
    close $ch;
		if ($rc) {
       $sth->DBI::set_err($rc,$errstr);
       return;
    }
    
    return (\@data,\@fields);
}

1;
