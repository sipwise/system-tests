#!/usr/bin/env perl

use strict;
use warnings;

use DBI;
use Getopt::Long;
use Carp;
use JSON::XS;

# Format: <element-type>/<schema-name>/<element-name>/<element-attribute>
# Where:
#   element-type - tables, columns, views, etc
#   schema-name  - name of the schema
#   element-name - name of the element (table, index, etc)
#   element-attribute - engine for the table, is_nullable for the column, etc
# Perl regex can be used here
# F.e.:
#   views/ldap/ldap_entries/view_definition
# For columns: columns/<schema-name>/<table-name>_<column-name>
#   columns/billing/table1_column1/is_nullable
#   tables/mysql/.+/create_options
my @diff_exceptions = qw(
    views/ldap/ldap_entries/view_definition
    tables/mysql/.+/create_options
    .+/prosody/prosodyarchive

    tables/accounting/cdr_cash_balance_data/create_options
    tables/accounting/cdr_time_balance_data/create_options
    tables/accounting/cdr_relation_data/create_options
    tables/accounting/cdr_tag_data/create_options
    tables/accounting/cdr_mos_data/create_options
    tables/accounting/cdr_export_status_data/create_options
    tables/accounting/cdr_group/create_options
    tables/accounting/cdr_period_costs/create_options
    tables/accounting/cdr/create_options
  
    .+/accounting/cdr_cash_balance_data_[0-9]{6}/.+
    .+/accounting/cdr_time_balance_data_[0-9]{6}/.+
    .+/accounting/cdr_relation_data_[0-9]{6}/.+
    .+/accounting/cdr_tag_data_[0-9]{6}/.+
    .+/accounting/cdr_mos_data_[0-9]{6}/.+
    .+/accounting/cdr_export_status_data_[0-9]{6}/.+
    .+/accounting/cdr_group_[0-9]{6}/.+
    .+/accounting/cdr_period_costs_[0-9]{6}/.+
    .+/accounting/cdr_[0-9]{6}/.+
);

my $credentials_file = '/etc/mysql/sipwise_extra.cnf';
my $argv = {
    formatter   => '',
    host_db1    => 'localhost',
    pass_db1    => '',
    port_db1    => '3306',
    schema_file => '',
    schema_name => '',
    user_db1    => '',
};
get_options();

my $queries = {
tables => <<"__SQL__"
SELECT
  TABLE_NAME,
  ENGINE,
  TABLE_COLLATION,
  CREATE_OPTIONS,
  TABLE_NAME AS key_col
FROM information_schema.TABLES
  WHERE TABLE_SCHEMA = ?
    AND TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME
__SQL__
,

columns => <<"__SQL__"
SELECT
  c.TABLE_NAME,
  c.COLUMN_NAME,
  c.COLUMN_DEFAULT,
  c.IS_NULLABLE,
  c.COLUMN_TYPE,
  c.EXTRA,
  c.CHARACTER_SET_NAME,
  c.COLLATION_NAME,
  c.ORDINAL_POSITION,
  CONCAT(c.TABLE_NAME, '/', c.COLUMN_NAME) AS key_col
FROM information_schema.COLUMNS c
  INNER JOIN information_schema.TABLES t
    ON c.TABLE_NAME = t.TABLE_NAME
WHERE t.TABLE_TYPE = 'BASE TABLE'
  AND c.TABLE_SCHEMA = t.TABLE_SCHEMA
  AND t.TABLE_SCHEMA = ?
ORDER BY c.TABLE_NAME, c.COLUMN_NAME
__SQL__
,

indexes => <<"__SQL__"
SELECT
  TABLE_NAME,
  INDEX_NAME,
  NON_UNIQUE,
  COLUMN_NAME,
  SEQ_IN_INDEX,
  COLLATION,
  SUB_PART,
  NULLABLE,
  INDEX_TYPE,
  CONCAT(TABLE_NAME, '/', INDEX_NAME, '/',  SEQ_IN_INDEX) AS key_col
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = ?
ORDER BY TABLE_NAME, INDEX_NAME, COLUMN_NAME
__SQL__
,

constraints => <<"__SQL__"
SELECT
  rc.CONSTRAINT_NAME,
  rc.TABLE_NAME,
  rc.REFERENCED_TABLE_NAME,
  rc.UPDATE_RULE,
  rc.DELETE_RULE,
  cu.REFERENCED_COLUMN_NAME,
  cu.COLUMN_NAME,
  CONCAT(  rc.TABLE_NAME, '/', rc.CONSTRAINT_NAME, '/',
    cu.COLUMN_NAME, '/', rc.REFERENCED_TABLE_NAME, '/',
    cu.REFERENCED_COLUMN_NAME) AS key_col
FROM information_schema.REFERENTIAL_CONSTRAINTS rc
  LEFT JOIN information_schema.KEY_COLUMN_USAGE cu
    ON (rc.CONSTRAINT_NAME=cu.CONSTRAINT_NAME
      AND rc.CONSTRAINT_SCHEMA=cu.CONSTRAINT_SCHEMA)
WHERE rc.CONSTRAINT_SCHEMA = ?
ORDER BY CONSTRAINT_NAME, rc.TABLE_NAME, cu.COLUMN_NAME
__SQL__
,

triggers => <<"__SQL__"
SELECT
  TRIGGER_NAME,
  EVENT_MANIPULATION,
  ACTION_STATEMENT,
  ACTION_TIMING,
  EVENT_OBJECT_SCHEMA,
  EVENT_OBJECT_TABLE,
  CONCAT(TRIGGER_NAME, '/', EVENT_OBJECT_TABLE) AS key_col
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA = ?
ORDER BY EVENT_OBJECT_TABLE, TRIGGER_NAME
__SQL__
,

views => <<"__SQL__"
SELECT
  TABLE_NAME AS key_col,
  VIEW_DEFINITION
FROM information_schema.VIEWS
WHERE TABLE_SCHEMA = ?
ORDER BY TABLE_NAME
__SQL__
,

routines => <<"__SQL__"
SELECT
  ROUTINE_NAME AS key_col,
  ROUTINE_DEFINITION,
  ROUTINE_TYPE
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = ?
__SQL__
,
};

if ( $argv->{port_db1} eq '3308' ) {
  push @diff_exceptions, '.+/kamailio/voicemail_spool';
  push @diff_exceptions, '.+/provisioning/autoprov_firmwares_data';
}

my $schema1 = "DBI:mysql:$argv->{schema_name};host=$argv->{host_db1};port=$argv->{port_db1};mysql_read_default_file=$credentials_file";
my $dbh1 = DBI->connect(
    $schema1,
    $argv->{user_db1},
    $argv->{pass_db1},
    { RaiseError => 1 } ) or
    croak("Can't connect to local db: $schema1");

my $res = [];
my $exit = 0;

my $json;
{
    #Enable 'slurp' mode
    local $/ = '';
    open my $fh, "<", $argv->{schema_file};
    $json = <$fh>;
    close $fh;
}
my $json_schema = decode_json($json);

my @objs_list = qw( tables columns indexes constraints triggers views routines );
foreach my $obj (@objs_list) {
    my $db_schema = $dbh1->selectall_hashref( $queries->{$obj}, 'key_col', undef, $argv->{schema_name} );
    print_diff( $db_schema, $json_schema->{$obj}, $obj, $res, $argv->{schema_name} );
}

if ( $argv->{formatter} eq 'tap' ) {
    $exit = 0;
    tap_output();
}
else {
    human_output();
}

exit $exit;

sub get_options {
    GetOptions(
        'formatter=s'           => \$argv->{'formatter'},
        'schema-file=s'         => \$argv->{'schema_file'},
        'schema-name=s'         => \$argv->{'schema_name'},
        'host-db1=s'            => \$argv->{'host_db1'},
        'user-db1=s'            => \$argv->{'user_db1'},
        'pass-db1=s'            => \$argv->{'pass_db1'},
        'port-db1=s'            => \$argv->{'port_db1'},
        'help|h'                => sub{ print_usage(); exit(0); },
    );
}

sub print_usage {
    my $usage =<<__USAGE__
Usage: compare_db.pl [<options>]

This script compares structure of schemes on local mysql instance with
all configured replica instances and prints result.

Options:
      --formatter=[tap]         The format of output. Supported values:
                                    tap   - print in a TAP format.
      --schemes=<name>          List of schemes which should be compared.
      --host-db1=<hostname>     Host of the 1st schema
      --user-db1=<username>     User of the 1st schema
      --pass-db1=<password>     Password of the 1st schema
      --port-db1=<password>     Port of the 1st schema
  -h, --help                    Print this message and exit.
__USAGE__
;
    print $usage;

    return 1;
}

sub is_exception {
    my ($exceptions, $type, $schema, $element, $attr) = @_;

    $attr //= '';
    foreach my $exception (@{$exceptions}) {
        # 'views/ldap/ldap_entries/view_definition'
        if ( lc("$type/$schema/$element/$attr") =~ $exception ) {
            print {*STDERR} "Exception found: $exception\n";
            return 1;
        }
    }

    return 0;
}

sub print_diff {
    my ($obj1, $obj2, $object_name, $result, $schema) = @_;

    foreach my $key ( sort( keys( %{$obj1} ) ) ) {
        unless ( exists($obj2->{$key}) ) {
            next if ( is_exception(\@diff_exceptions, $object_name, $schema, $key) );
            push( @{$result}, "Element: " . lc("$object_name/$schema/$key") . " is missing in json file" );
            next;
        }
        foreach my $c_name ( sort( keys( %{ $obj1->{$key} } ) ) ) {
            unless ( exists($obj2->{$key}->{$c_name}) ) {
                next if ( is_exception(\@diff_exceptions, $object_name, $schema, $key, $c_name) );
                push( @{$result}, "Element: " . lc("$object_name/$schema/$key/$c_name") . " is missing in json file" );
                next;
            }

            # The value of $obj1->{$key}->{$c_name} is the value of some object's attribute in schema
            # The attribute can be NULL so in perl hash it is undef
            # Check and replace undef value with literal NULL
            $obj1->{$key}->{$c_name} = 'NULL' if ( ! defined($obj1->{$key}->{$c_name}) );
            $obj2->{$key}->{$c_name} = 'NULL' if ( ! defined($obj2->{$key}->{$c_name}) );

            if ( $obj1->{$key}->{$c_name} ne $obj2->{$key}->{$c_name} ) {
                next if ( is_exception(\@diff_exceptions, $object_name, $schema, $key, $c_name) );
                push( @{$result}, "Element: " . lc("$object_name/$schema/$key/$c_name") . " are not equal:\n  ---\n"
                  . "  local db:  $obj1->{$key}->{$c_name}\n"
                  . "  json file: $obj2->{$key}->{$c_name}" );
            }
        }
    }

    foreach my $key ( sort( keys( %{$obj2} ) ) ) {
        unless ( exists($obj1->{$key}) ) {
            next if ( is_exception(\@diff_exceptions, $object_name, $schema, $key) );
            push( @{$result}, "Element: " . lc("$object_name/$schema/$key") . " is missing in local db" );
            next;
        }
        foreach my $c_name ( sort( keys( %{ $obj2->{$key} } ) ) ) {
            unless ( exists($obj1->{$key}->{$c_name}) ) {
                next if ( is_exception(\@diff_exceptions, $object_name, $schema, $key, $c_name) );
                push( @{$result}, "Element: ". lc("$object_name/$schema/$key/$c_name") ." is missing in local db" );
                next;
            }
        }
    }

    return 1;
}

sub tap_output {
    my $number = scalar(@{$res});
    my $counter = 1;
    if ( $number > 0 ) {
        print "1..$number\n";
        foreach my $err ( @{$res} ) {
            print "not ok $counter $err\n";
            $counter++;
        }
    }
    else {
        print "1..1\n";
        print "ok 1 Schema is ok\n";
    }
}

sub human_output {
    my $number = scalar(@{$res});
    if ( $number > 0 ) {
        $exit = 1;
        print "The following errors were found:\n\n";
        foreach my $err ( @{$res} ) {
            print "$err\n";
        }
    }
    else {
        print "Schema $argv->{schema_name} is equal to json file\n";
    }
}
