package common;

use Mojo::Home;
use MongoDB;
use Exporter();
use vars qw( @ISA @EXPORT @EXPORT_OK );

@ISA = qw( Exporter );
@EXPORT = qw( &rel_file &dbconn $config $passwords );

use vars qw( $config $passwords );

# Find and manage the project root directory
my $home = Mojo::Home->new;
$home->detect;

sub rel_file { $home->rel_file(shift); }

sub dbconn {
	my ($client, $db, $collections);

	$client = MongoDB::Connection->new(
		host		=> $config->{'conf'}->{'mongohost'},
		query_timeout	=> -1,
		auto_connect	=> 0,
		username	=> $config->{'conf'}->{'mongouser'},
		password	=> $config->{'conf'}->{'mongopass'}
	);
	$db = $client->get_database( $config->{'conf'}->{'database'} );
	$collections = $db->get_collection( $config->{'collection'}->{'contacts'} );

	return $collections;
}

1;
