package Auth;

use strict;
use warnings;
use Mojolicious::Plugin::Config;
use Mojo::Base 'Mojolicious';

use common;

# Set connetctions for global use
has [qw(domains)];

# This method will run once at server start
sub startup {
	my $self = shift;

	# Turn off writing log
#	delete $self->log->{path};

	# load database config
	$config = $self->plugin(Config => { file => rel_file('../auth.conf') });

	# Create Db connection to zones
	my $domains = dbconn($config->{'conf'}->{'database'}, $config->{'collection'}->{'contacts'});
	$self->domains($domains);

	# Secret for cookie
	$self->secrets('yfenbkec');

	# set life-time fo session (second)
#	$self->sessions->default_expiration(0);

	# Router
	my $r = $self->routes;

	# Normal route to controller
	$r->any('/')->to('user#auth');
	$r->any('/rel')->to('user#reload');
	$r->any('/*')->to('user#error');
}

1;
