package Robot;

use strict;
use warnings;
use Mojolicious::Plugin::Config;
use Mojo::Base 'Mojolicious';

use common;

# Set connetctions for global use
has [qw(queue_contacts contacts domains)];

# This method will run once at server start
sub startup {
	my $self = shift;

	# Turn off writing log
#	delete $self->log->{path};

	# load database config
	$config = $self->plugin(Config => { file => rel_file('../robot.conf') });

	# Create Db connection to zones
	my $queue_contacts = dbconn($config->{'conf'}->{'database'}, $config->{'collection'}->{'queue_contacts'});
	$self->queue_contacts($queue_contacts);

	# Create Db connection to zones
	my $contacts = dbconn($config->{'conf'}->{'database'}, $config->{'collection'}->{'contacts'});
	$self->contacts($contacts);

	# Create Db connections to domains
	my $domains = dbconn($config->{'conf'}->{'database'}, $config->{'collection'}->{'domains'});
	$self->domains($domains);

	# Secret for cookie
	$self->secrets('yfenbkec');

	# set life-time fo session (second)
#	$self->sessions->default_expiration(0);

	# Router
	my $r = $self->routes;

	# Normal route to controller
	$r->any('/add_account')		->to('robot#add_account');
	$r->any('/update_account')	->to('robot#update_account');
	$r->any('/domains_check')	->to('robot#domains_check');
	$r->any('/*')			->to('robot#error');
}

1;
