#!/usr/bin/perl

use 5.008003;
use ExtUtils::MakeMaker;

use strict;

use Cwd;
use File::Spec;
use Config;

my $pwd=cwd();

sub tsm_choose_dsm_dir {
    if (-d $ENV{DSM_DIR} and
        -f $ENV{DSM_CONFIG}
        ) {
        my $dsm_config=(-f File::Spec->catfile($ENV{DSM_DIR},"dsm.sys"))?File::Spec->catfile($ENV{DSM_DIR},"dsm.sys"):
                                                                         File::Spec->catfile($ENV{DSM_CONFIG});        
        return ($ENV{DSM_DIR},
                File::Spec->catfile($ENV{DSM_DIR},"dsmadmc"),
                $dsm_config,
                );
    }
    ($^O eq 'linux') and return (File::Spec->catfile("","opt","tivoli","tsm","client","ba","bin"),
                                 File::Spec->catfile("","opt","tivoli","tsm","client","ba","bin","dsmadmc"),
                                 File::Spec->catfile("","opt","tivoli","tsm","client","ba","bin","dsm.sys"),
                                 );
    ($^O eq 'aix')   and return (File::Spec->catfile("","usr","tivoli","tsm","client","ba","bin"),
                                 File::Spec->catfile("","usr","bin","dsmadmc"),
                                 File::Spec->catfile("","usr","tivoli","tsm","client","ba","bin","dsm.sys"),
                                 );
    ($^O eq 'win32')   and return (File::Spec->catfile($ENV{ProgramFiles},"tivoli","tsm","client","ba"),
                                   File::Spec->catfile($ENV{ProgramFiles},"tivoli","tsm","client","ba","dsmadmc"),
                                   File::Spec->catfile($ENV{ProgramFiles},"tivoli","tsm","client","ba","dsm.opt"),
                                  );
    return;
}

sub config_macro {
    my ($dsm_dir,$dsmadmc,$dsm_config)=tsm_choose_dsm_dir();

    unless (-d $dsm_dir    and
            -x $dsmadmc    and
            -f $dsm_config) {
            print "Could not detect automatically prerequisite. Help me:\n";
            my $value;
            while (! -d $value) {
                $value=prompt("Install dir for TSM Client where (dsmc, dsmadmc, dsm.*) exists",$dsm_dir);
            }
            $dsm_dir=$value;
            $value=undef;
            while (! -x $value) {
                $value=prompt("dsmadmc command",$dsmadmc);
            }
            $dsmadmc=$value;
            $value=undef;
            while (! -x $value) {
                $value=prompt("TSM client config file (dsm.sys UNIX, dsm.opt Windows)",$dsm_config);
            } 
            $dsm_config=$value;    
    }      
    print "Choose TSM Install directory:  $dsm_dir\n";
    print "Choose TSM dsmadmc command:    $dsmadmc\n";
    print "Choose TSM client config file: $dsm_config\n";
    
    return {
            TSM_DSMDIR    => $dsm_dir,
            TSM_DSMCONFIG => $dsm_config,
            TSM_DSMADMC   => $dsmadmc,
            };  
}

my $macros        = config_macro();
my @module        = ('DBD','TSM');
my $module_name   = join('::',@module);
my $module_filter = File::Spec->catfile('lib',@module,'configure.pl');
$module[-1]      .= '.pm';
my $module_path   = File::Spec->catfile('lib',@module);

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => $module_name,
    VERSION_FROM      => $module_path, # finds $VERSION
    PREREQ_PM         => {DBI => 1.4}, # e.g., Module::Name => 1.1
    macro             => $macros,
    PM_FILTER         => $Config{perlpath}." ".$module_filter,
    ($] >= 5.008 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/DBD/TSM.pm', # retrieve abstract from module
       AUTHOR         => 'Laurent Bendavid <bendavid.laurent@free.fr>') : ()),
);
