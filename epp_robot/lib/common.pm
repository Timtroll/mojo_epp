package common;

use Mojo::Home;
use MongoDB;
use Net::EPP::Simple;
use Data::Dumper;

BEGIN {
	# set not verify ssl connection
	IO::Socket::SSL::set_ctx_defaults(
		'SSL_verify_mode' => 0 #'SSL_VERIFY_NONE'
        );
	$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = '0';
};

use Exporter();
use vars qw( @ISA @EXPORT @EXPORT_OK );

@ISA = qw( Exporter );
@EXPORT = qw( $config &rel_file &dbconn &dblist &connect_epp &dbupdate &dbremove );

use vars qw( $config );

# Find and manage the project root directory
my $home = Mojo::Home->new;
$home->detect;

sub rel_file { $home->rel_file(shift); }

sub dbconn {
	my ($client, $db, $collections, $database, $col);
	$database = shift;
	$col = shift;

	$client = MongoDB::Connection->new(
		host		=> $config->{'conf'}->{'mongohost'},
		query_timeout	=> 1000,
		#auto_reconnect	=> true,
		username	=> $config->{'conf'}->{'mongouser'},
		password	=> $config->{'conf'}->{'mongopass'}
	);

	$db = $client->get_database( $database );
	$collections = $db->get_collection( $col );

	return $collections;
}

sub dblist {
	my (@list, %hach);
	%hach = @_;

	if ($hach{'fields'}) {
		@list = $hach{'collection'}->find( $hach{'query'}, $hach{'fields'} )->all;
	}
	else {
		@list = $hach{'collection'}->find( $hach{'query'} )->all;
	}

	return \@list;
}

sub connect_epp {
	my ($epp);

	# Connect to Epp server
	$epp = Net::EPP::Simple->new(
		host	=> $config->{'conf'}->{'epp_host'},
		user	=> $config->{'conf'}->{'epp_user'},
		timeout	=> $config->{'conf'}->{'epp_timeout'},
		pass	=> $config->{'conf'}->{'epp_pass'},
		debug	=> $config->{'conf'}->{'debug_epp'}
	);

	if (($Net::EPP::Simple::Code == 2500)||($Net::EPP::Simple::Code == 2501)||($Net::EPP::Simple::Code == 2502)) {
print "ERROR\n\n";
	}

	return $epp;
}

sub dbupdate {
	my ($collection, $find, $query);
	$collection = shift;
	$find = shift;
	$query = shift;

print Dumper($query);
	$collection->update( $find, { '$set' => $query } );

	return;
}

sub dbremove {
	my ($collection, $query);
	$collection = shift;
	$query = shift;

	print $collection->remove( $query );
print "\n";

	return;
}

1;
