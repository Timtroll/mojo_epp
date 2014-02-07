package Auth::User;

use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';

use common;

sub instance {
	my ($self, $connection,  @data, %pass);

	unless ($passwords) {
		$connection = $self->{'app'}->{'new_users'};
		# check connection
		unless ($connection) {
			$connection = &dbconn();
		}
		# $client = MongoDB::Connection->new(
			# host		=> $config->{'conf'}->{'mongohost'},
			# query_timeout	=> 1000,
			# username	=> $config->{'conf'}->{'mongouser'},
			# password	=> $config->{'conf'}->{'mongopass'}
		# );
		# $db = $client->get_database( $config->{'conf'}->{'database'} );
		# $collections = $db->get_collection( $config->{'collection'}->{'contacts'} );

		# Read list of domains
		@data = $connection->find()->all;
		%pass = ();
		map {
			if ($_->{'login'} && $_->{'pass'}) {
				$pass{$_->{'login'}} = {
					'pass'	=> $_->{'pass'},
					'type'	=> $_->{'usertype'},
					'cunic'	=> $_->{'id'}
				};
			}
		} (@data);
		@data = ();
		$passwords = \%pass;
	}

	return;
}


sub auth {
	my ($self, $user, $pass, $rel, $auth, $type, $cunic);
	($self) = @_;

	# read all users to memory
	&instance();

	$user = $self->param('user');
	$pass = $self->param('pass');

	# reload user list if auth true && 'rel' flag exists
	if ($user && $pass) {
		($auth, $type, $cunic) = check($user, $pass);
	}
	else {
		$auth = $type = $cunic = 0;
	}

	# Render template "user/auth.html.ep" with message
	$self->render( json =>{ 'auth' => $auth, 'type' => $type , 'cunic' => $cunic } );
}

sub reload {
	my ($self, $count, $cnt);
	($self) = @_;

	$count = scalar(keys %{$passwords});
	$passwords = undef;
	&instance();
	$cnt = scalar(keys %{$passwords});
print "befor $count===\nafter $cnt===\n";
	# Render template "user/auth.html.ep" with message
	if ($count == $cnt) {
		$self->render( json =>{ 'rel' => 0 } );
	}
	else {
		$self->render( json =>{ 'rel' => 1 } );
	}
}

sub check {
	my ($user, $pass) = @_;

	if ($user) {
		if (exists $passwords->{$user}) {
			if ($passwords->{$user}->{'pass'} eq $pass) {
				return 1, $passwords->{$user}->{'type'}, $passwords->{$user}->{'cunic'};
			}
		}
	}
	return 0, 0, 0;
}

sub error {
	my $self = shift;

	# Render template "user/auth.html.ep" with message
	$self->render( json =>{auth => 0} );
}

1;
