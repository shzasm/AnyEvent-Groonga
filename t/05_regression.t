use strict;
use warnings;
use utf8;
use lib '../lib';
use AnyEvent::Groonga;
use Test::More;
use FindBin;
use File::Spec;
use File::Basename qw(dirname);

unlink $_ for glob( File::Spec->catfile( $FindBin::RealBin, "data", "*") );

my $g = AnyEvent::Groonga->new( debug => 0 );
my $groonga_path = $g->groonga_path;
my $test_database_path
    = File::Spec->catfile( $FindBin::RealBin, "data", "test.db" );

unless ( $groonga_path and -e $groonga_path ) {
    plan skip_all => "groonga is not installed.";
}
else{
    plan tests => 2;
}

# create data directory.
unless( -d dirname($test_database_path) ) {
    mkdir( dirname($test_database_path) ) or die "can't create the data directory for groonga";
}

`$groonga_path -n $test_database_path quit`;

$g->protocol("local_db");
$g->database_path(
    File::Spec->catfile( $FindBin::RealBin, "data", "test.db" ) );

$g->call(
    table_create => {
        name     => "Site",
        flags    => "TABLE_HASH_KEY",
        key_type => "ShortText",
    }
)->recv;

$g->call(
    column_create => {
        table => "Site",
        name  => "title",
        flags => "COLUMN_SCALAR",
        type  => "ShortText",
    }
)->recv;

{
    my @data = (
        { _key  => "http://example.com/tzd",
          title => "test record containing backslash\\ character.",
        },
        { _key  => "http://example.com/gez",
          title => "test record containing quote' character.",
        },
        { _key  => "http://example.com/jpn",
          title => "日本語を含むレコード",
        },
        { _key  => "http://example.com/swz",
          title => "test record containing backquote` character.",
        }
    );

    my $result = $g->call(
        load => {
            table => "Site",
            values => \@data,
        }
    )->recv;
    is( $result->body, 4 );

    $result = $g->call( select => { table => "Site" } )->recv;

    is_deeply(
        $result->items,
        [
            { _id   => 1,
              _key  => "http://example.com/tzd",
              title => "test record containing backslash\\ character.",
            },
            { _id   => 2,
              _key  => "http://example.com/gez",
              title => "test record containing quote' character.",
            },
            { _id   => 3,
              _key  => "http://example.com/jpn",
              title => "日本語を含むレコード",
            },
            { 
              _id   => 4,
              _key  => "http://example.com/swz",
              title => "test record containing backquote` character.",
            },
        ]
    );
}
