package DBD::TSM;

use 5.008003;
use strict;
#use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use DBD::TSM ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(	
);

# Preloaded methods go here.

#--------------------------------------------------------------
# Module principal pour le driver: constructeur
#--------------------------------------------------------------
use Carp;

our ($VERSION,$err,$errstr,$sqlstate,$drh);

$VERSION = '0.04';
## Error in Makefile.PL, see change file

# Gestion des erreurs DBI
$err      = 0;             # DBI::err
$errstr   = "";            # DBI::errstr
$sqlstate = "";            # DBI::state

$drh      = undef;

# Construction / initialisation du driver
sub driver {
    #Ne charge qu'un driver
    return $drh if $drh;

    my ($class,$attr)=@_;

    $drh = DBI::_new_drh($class.'::dr', {
                               'Name'        => 'TSM',
                               'Version'     => $VERSION,
                               'Err'         => \$DBD::TSM::err,
                               'Errstr'      => \$DBD::TSM::errstr,
                               'State'       => \$DBD::TSM::state,
                               'Attribution' => 'DBD::TSM by Laurent Bendavid',
                               }
                         );

    # Gestion de l'erreur à la création                    
    croak 'DBD::TSM: Error - Could not load driver: ',$DBI::errstr,"\n" unless $drh;

    # Gestion des variables d'environnement et autres présence de l'environnement minimum
    # Fin

    return $drh;
}

#--------------------------------------------------------------
# Connexion à la base / déconnexion création du database handler
# à partir du driver
#--------------------------------------------------------------
package DBD::TSM::dr;


use constant DEBUG => 0;
BEGIN {
    DEBUG && require Data::Dumper;
    DEBUG && import Data::Dumper;
}

use strict;
#use warnings;
use DBD::TSM::Functions;

our $imp_data_size = 0;

sub disconnect_all {
    my ($drh)=(@_);

    # Déconnexion: fin de l'utilisation de la connexion et donc de l'objet
    # Fin
}

sub data_sources {
    my ($drh)=@_;
    
    # Recuperer les infos d'un fichier
    my @data_sources=tsm_data_sources($drh);
    # Fin
    
    return @data_sources;
}

sub connect {
    my ($drh, $dbname, $user, $auth, $attr) = @_;
    
    DEBUG && print "DEBUG - ",__PACKAGE__,"->connect: @_\n";

    my $dbh = DBI::_new_dbh($drh, {
                   'Name'         => $dbname,
                   'USER'         => $user,
                   'CURRENT_USER' => $user,
               });

    foreach my $attr_name (qw(PrintError AutoCommit RaiseError)) {
#    foreach my $attr_name (qw(Active PrintError AutoCommit RaiseError)) {
        my $attr_value=(exists $attr->{$attr_name})?($attr->{$attr_name}):(1);
        $dbh->STORE($attr_name => $attr_value);
    }

    # Gestion de la connexion, c'est a dire verification que les user/password permet de se connecter
    if (tsm_connect($dbh,$dbname,$user,$auth)) {
        return $dbh;
    } else {
        return;
    }        
    # Fin

}

#--------------------------------------------------------------
# Préparation des requêtes à la base
#--------------------------------------------------------------
package DBD::TSM::db;

use strict;
#use warnings;

use constant DEBUG => 0;

BEGIN {
    DEBUG && require Data::Dumper;
}

our $imp_data_size = 0;

sub ping {
    my ($dbh) = @_;

    return 1;
}

sub prepare {
    my ($dbh, $statement, @attribs) = @_;

    # Initialisation
    my ($sth) = DBI::_new_sth($dbh, {
             'Statement' => $statement,
             });
    $sth->STORE('NUM_OF_PARAMS' => ($statement =~ tr/\?//));
    $sth->STORE('tsm_params'   => []);

    # Compilation de requete
    # Fin

    return ($sth);
}

#NEW: spec non fini
#$dbh->table_info($catalog, $schema, $table, $type);
#$dbh->tables($catalog, $schema, $table, $type);
#$dbh->get_info($info_type);
#$dbh->type_info_all($info_type);
#$dbh->type_info($info_type);
#$dbh->column_info($catalog, $schema, $table, $type);
#$dbh->primary_key_info($catalog, $schema, $table);
#$dbh->primary_key($catalog, $schema, $table);
#$dbh->foreign_key_info($catalog, $schema, $table);
#$dbh->foreign_key($catalog, $schema, $table);

# Pas de commit ni rollback implemente
sub commit {
    my ($dbh) = @_;
    if ($dbh->FETCH('Warn')) {
        warn("Commit ineffective while AutoCommit is on");
    }
    return 1;
}
sub rollback {
    my ($dbh) = @_;
    if ($dbh->FETCH('Warn')) {
        warn("Rollback ineffective while AutoCommit is on");
    }
    return 0;
}

sub STORE {
    my ($dbh, $attr, $val) = @_;

    if ($attr eq 'AutoCommit') {
        die "Can't disable AutoCommit" unless $val;
        return 1;
    }

    if ($attr =~ m/^tsm_/ ) {
        # Attributs prives
        $dbh->{$attr} = $val;
        return 1;
    }

    # Else pass up to DBI to handle for us
    $dbh->SUPER::STORE($attr, $val);
}

sub FETCH {
    my ($dbh, $attr) = @_;
    return 1                           if ($attr eq 'AutoCommit');
    return $dbh->{$attr}               if ($attr =~ m/^tsm_/);
    return $dbh->SUPER::FETCH($attr);
}

sub DESTROY {
    my ($dbh) = @_;
    
    DEBUG && print "DEBUG - ",__PACKAGE__,"->DESTROY: call @_\n";
}

#---------------------------------------------------------------------
# Execution
#---------------------------------------------------------------------
package DBD::TSM::st;

#use warnings;
use strict;

use DBD::TSM::Functions;

use constant DEBUG => 0;

our $imp_data_size = 0;

sub bind_param {
    my ($sth, $pNum, $val, $attr) = @_;
    my $type = (ref $attr) ? $attr->{TYPE} : $attr;
    if ($type) {
        my $dbh = $sth->{Database};
        $val = $dbh->quote($sth, $type);
    }
    my $params = $sth->FETCH('tsm_params');
    $params->[$pNum-1] = $val;
    1;
}

sub execute {
    my ($sth, @bind_values) = @_;
    
    #Référence sur les paramètres d'exécute
    my $params = (@bind_values) ? \@bind_values : $sth->FETCH('tsm_params');
    my $numOfParam=$sth->FETCH('NUM_OF_PARAMS');
    my $num_param =scalar(@{$params});

    # Nombre de paramètre au moment du prepare
    if ($numOfParam > $num_param) {
            $sth->DBI::set_err(1,"Bad numbers of param: $num_param/$numOfParam.");
            return;
    }

    my $statement = $sth->{Statement};
    my $eval_statement="";

    foreach my $param (@{$params}) {
        if (my ($sql,$next) = ($statement =~ m/([^\?]+)\?(.*)/)) {
            $eval_statement = $eval_statement.$sql.$param;
            $statement      = $next;
        }
    }
    $statement = $eval_statement.$statement;

    DEBUG && print "DEBUG - ",__PACKAGE__,"->execute: AutoCommit=",$sth->FETCH('AutoCommit'),"\n";
    my ($data,$fields)=tsm_execute($sth,$statement) or return;

    my ($fields_lc,$fields_uc);

    @{$fields_uc}=map {uc($_)} @{$fields};
    @{$fields_lc}=map {lc($_)} @{$fields};

    # Stock les parametres
    $sth->STORE('tsm_data',$data);
    $sth->STORE('tsm_rows',scalar(@{$data})); # number of rows
    my $nb_fields=@{$fields};
    DEBUG && print "DEBUG - ",__PACKAGE__,"->execute: nb fields = $nb_fields, ",$sth->FETCH('NUM_OF_FIELDS'),"\n";
    $sth->STORE('NUM_OF_FIELDS',$nb_fields); # unless ($nb_fields == $sth->FETCH('NUM_OF_FIELDS')); pourquoi je faisais ce test?
    $sth->STORE('NAME',$fields);
    $sth->STORE('NAME_lc',$fields_lc);
    $sth->STORE('NAME_uc',$fields_uc);
    $sth->STORE('NULLABLE'      => [ (0) x @{$fields} ]);
    $sth->STORE('TYPE'          => [ (DBI::SQL_VARCHAR()) x @{$fields} ]);
    $sth->STORE('SCALE'         => undef);
    $sth->STORE('PRECISION'     => undef);

    return (@{$data} || '0E0');
}

sub fetchrow_arrayref {
     my ($sth) = @_;

     my $data = $sth->FETCH('tsm_data');
     my $row  = shift @{$data};

     # Fin du tableau
     return undef unless ($row);

     if ($sth->FETCH('ChopBlanks')) {
        map { $_ =~ s/\s+$//;
              $_ =~ s/^\s+//;
             } @$row;
     }
     return $sth->_set_fbav($row);
}

*fetch = \&fetchrow_arrayref;

sub rows {
    my ($sth) = @_;
    return ($sth->FETCH('tsm_rows'));
}

sub STORE {
    my ($sth, $attr, $val) = @_;

    return 1 if ($attr eq 'AutoCommit');

    if ($attr =~ m/^tsm_/  or
        $attr =~ m/^NAME/   or
        $attr eq 'NULLABLE' or
        $attr eq 'SCALE'    or
        $attr eq 'TYPE'     or
        $attr eq 'PRECISION'   ) {
        $sth->{$attr} = $val;
        return 1;
    }

    # Else pass up to DBI to handle for us
    $sth->SUPER::STORE($attr, $val);
}

sub FETCH {
    my ($sth, $attr) = @_;

    # Parametres optionnels de Database, mélange Min et Maj
    return 1                         if ($attr eq 'AutoCommit');
    return $sth->{$attr}             if ($attr =~ m/^tsm_/);
    return $sth->SUPER::FETCH($attr);
}


1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

DBD::TSM - Perl DBD driver for TSM admin client

=head1 SYNOPSIS

    use DBI;
    
    my ($server_name,$user,$password)=(...); #or set DBI_DSN,DBI_USER,DBI_PASS

    my $dbh=DBI->connect("DBB:TSM:$server_name",$user,$password,
                         {RaiseError => 0,
                         PrintError => 0}) or die $DBI::errstr;
    #If you use environment variable $dbh=DBI->connect();

    my $sth=$dbh->prepare("select node_name from nodes") or 
            die $dbh->errstr;
    $sth->execute() or die $sth->errstr();

    print "@{$sth->{NAME}}\n";
    $sth->dump_results();

=head1 DESCRIPTION

DBD::TSM is a DBI Driver to interface DBI with dsmadmc.
You could use all the command possible with dsmadmc with the Power of DBI.
I don't test all the DBI capabilities.

To work you need to have:

=over 4

=item *

A TSM server started

=item *

A TSM Client full operationnal. i.e.:

=over 4

=item *

TSM Binary installed (dsmadmc is the much important for me)

=item *

dsm.sys or/and dsm.opt set to work with your tsm server.

=over 4

=item *

Check it before with a manual test with:

    dsmc query session command

=item *

Check it before with a manual test with:

    dsmadmc -id=<user> -pa=<password> -se=<Your Server Name stanza> query status

=back

=back

=back

=head2 AutoCommit

When you set AutoCommit (the default), I add -itemcommit in command line.

=head2 Advice

I always set PrintError => 0 and RaiseError => 0. Because, TSM send a '11' return code
for empty statement and DBI exit automatically with rc > 0.

I prefer to check return code with function err and messages with errmsg. I do a filter 
on AN.....[^I] to print error messages.

=head2 EXPORT

None by default.

=head1 SEE ALSO

DBI(3).

TSM Client Reference Manual.

=head1 BUGS

I'm not using TSM API. So, I do one session for each statement. I'm not a C developper, 
sor it's a Pure Perl Module.

=head1 AUTHOR

Laurent Bendavid, E<lt>bendavid.laurent@free.frE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Laurent Bendavid

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.3 or,
at your option, any later version of Perl 5 you may have available.

=cut
