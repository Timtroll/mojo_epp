package EppClient::Login;

use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Log;

use Email::Valid;
use Mojo::UserAgent;
use JSON::XS;
use Time::HiRes;

use common;
use Subs;

use Data::Dumper;

my $log = Mojo::Log->new(path => 'log/login.log', level => 'debug');

sub repeat {
	my ($self, $newusers, $resp, @error);
	($self) = @_;

	# check e-mail
	if ($self->param('email')) {
		if (Email::Valid->address($self->param('email'))) {
			# check exists e-mail in new users database
			$newusers = &dblist(
				'collection'	=> $self->{'app'}->{'new_users'},
				'query'		=> { 'email' => $self->param('email') }
			);

			if ($$newusers[0]->{'email'} eq $self->param('email')) {
				# send registration code
				$resp = &send_mail(
					'server'=> $config->{'conf'}->{'smtp_server'},
					'port'	=> $config->{'conf'}->{'smtp_port'},
					'login'	=> $config->{'conf'}->{'smtp_login'},
					'pass'	=> $config->{'conf'}->{'smtp_password'},
					'from'	=> $config->{'conf'}->{'robot_mail'},
					'to'	=> $self->param('email'),
					'subj'	=> 'Registration code (Repetition)',
					'text'	=> $$newusers[0]->{'code'}
				);
				unless ($resp) {
					push @error, "email=".$config->{'mesg'}->{'sent_activate_repeat'};
					$self->cookie('error' => join('|', @error),  { domain => $config->{'mesg'}->{'url'}, expires => $config->{'mesg'}->{'url'} } );
					$self->res->code(301);
					$self->redirect_to('/add2.html');
					return;
				}
				else {
					push @error, "email=".$config->{'mesg'}->{'empty_error'};
				}
			}
			else {
				push @error, "email=".$config->{'mesg'}->{'email_error'};
			}
		}
		else {
			push @error, "email=".$config->{'mesg'}->{'email_error'};
		}
	}
	else {
		push @error, "email=".$config->{'mesg'}->{'empty_error'};
	}

	$self->cookie('error' => join('|', @error),  { domain => $config->{'mesg'}->{'url'}, expires => $config->{'mesg'}->{'url'} } );
	$self->res->code(301);
	$self->redirect_to('/repeat.html');
	return;
}

sub singup {
	my ($self, $error, $epp, $resp, $code, $users, $newusers, $query, $text, @tmp, @fields, @error);
	($self) = @_;

	@fields = ('login','pass','cc','name','email','voice','pc','city','street');
	foreach (@fields) {
		unless ($self->param($_)) {
			push @error, "$_=".$config->{'mesg'}->{$_};
		}
		else {
			if (/^email$/) {
				unless (Email::Valid->address($self->param($_))) {
					push @error, "$_=".$config->{'mesg'}->{'email_error'};
				}
			}
		}
	}

	unless (scalar(@error)) {
		# check exists add login in user and new_user databases
		$users = &dblist(
			'collection'	=> $self->{'app'}->{'users'},
			'query'		=> { },
			'fields'	=> { 'login' => 1, 'email' => 1 }
		);

		$newusers = &dblist(
			'collection'	=> $self->{'app'}->{'new_users'},
			'query'		=> { },
			'fields'	=> { 'login' => 1, 'email' => 1 }
		);

		if (($$users[0]->{'login'} eq $self->param('login'))||($$newusers[0]->{'login'} eq $self->param('login'))) {
			push @error, "login=".$config->{'mesg'}->{'exists_login'};
		}
		if (($$users[0]->{'email'} eq $self->param('email'))||($$newusers[0]->{'email'} eq $self->param('email'))) {
			push @error, "email=".$config->{'mesg'}->{'exists_email'};
		}
		if (scalar(@error)) {
			$self->cookie('error' => join('|', @error),  { domain => $config->{'mesg'}->{'url'}, expires => $config->{'mesg'}->{'url'} } );
			$self->res->code(301);
			$self->redirect_to('/add.html');
			return;
		}
		else {
			$self->cookie('error' => '', {expires => -1} );
		}

		# generate activayion link
		@tmp = ('A'..'Z', '0'..'9', 'a'..'z');
		srand();
		for (1..16) { $code .= $tmp[rand(@tmp)]; }
		$text = $config->{'mesg'}->{'activate_code'}.$code;

		# send registration code
		$resp = &send_mail(
			'server'=> $config->{'conf'}->{'smtp_server'},
			'port'	=> $config->{'conf'}->{'smtp_port'},
			'login'	=> $config->{'conf'}->{'smtp_login'},
			'pass'	=> $config->{'conf'}->{'smtp_password'},
			'from'	=> $config->{'conf'}->{'robot_mail'},
			'to'	=> $self->param('email'),
			'subj'	=> 'Registration code',
			'text'	=> $text
		);
		if ($resp) {
			push @error, "email=".$resp;
			$self->cookie('error' => join('|', @error),  { domain => $config->{'mesg'}->{'url'}, expires => $config->{'mesg'}->{'url'} } );
			$self->res->code(301);
			$self->redirect_to('/add.html');
			return;
		}
		else {
			# create new user structure
			$query = {
				'date'	=> join('', Time::HiRes::gettimeofday),
				'code'	=> $code,
				'email'	=> $self->param('email'),
				'login'	=> $self->param('login'),
				'user'	=> {
					'postalInfo' => {
						'loc' => {
							'org'	=> $self->param('org'),
							'name'	=> $self->param('name'),
							'addr' => {
								'sp'	=> $self->param('sp'),
								'city'	=> $self->param('city'),
								'cc'	=> $self->param('cc'),
								'street' => [ 
									$self->param('street'),
								],
								'pc' => $self->param('pc'),
							}
						}
					},
					'status' => [ 
						'new'
					],
					'voice'		=> $self->param('voice'),
					'fax'		=> $self->param('fax'),
					'email'		=> $self->param('email'),
					'usertype'	=> 'user',
					'id'		=> '',
					'login'		=> $self->param('login'),
					'pass'		=> $self->param('pass'),
					'package' => {
						'discount'	=> 0,
						'autorenew'	=> 0,
						'notification'	=> 0,
						'transfer'	=> 0,
						'prohibit'	=> 0,
						'nschanging'	=> 0
					},
					'crDate'		=> sec2date(time(), 'iso'),
					'discount'		=> 4,

					'roid'			=> '',
					'upID'			=> '',
					'clID'			=> $config->{'conf'}->{'epp_user'},
					'crID'			=> $config->{'conf'}->{'epp_user'},
					'authInfo'		=> ''
				}
			};
			&dbinsert($self->{'app'}->{'new_users'}, $query);

			# Set message for user
			push @error, "email=".$config->{'mesg'}->{'sent_activate'};
			$self->cookie('error' => join('|', @error),  { domain => $config->{'mesg'}->{'url'}, expires => $config->{'mesg'}->{'url'} } );
	
			$self->res->code(301);
			$self->redirect_to('/add2.html');
		}
	}
	else {
		$self->cookie('error' => join('|', @error),  { domain => $config->{'mesg'}->{'url'}, expires => $config->{'mesg'}->{'url'} } );
		$self->res->code(301);
		$self->redirect_to('/add.html');
	}
	return;
}

sub forgot {
	my ($self, $users, $resp, $code, $query, @tmp, @error);
	($self) = @_;

	unless (Email::Valid->address($self->param('forgot'))) {
		push @error, $config->{'mesg'}->{'email_error'};

		$self->cookie('error_forgot' => join('|', @error),  { domain => $config->{'mesg'}->{'url'}, expires => $config->{'mesg'}->{'url'} } );
		$self->res->code(301);
		$self->redirect_to('/forgot.html');
	}
	else {
		# check exists user
		$users = users_mail($self->{'app'}->{'users'}, 'email');
		if (exists $users->{$self->param('forgot')}) {
			# generate new pass & send it to user
			@tmp = ('A'..'Z', '0'..'9', 'a'..'z');
			srand();
			for (1..128) { $code .= $tmp[rand(@tmp)]; }

			# save restore code to database
			$query = {
				'date'	=> join('', Time::HiRes::gettimeofday),
				'code'	=> $code,
				'email'	=> $self->param('forgot')
			};
			&dbinsert($self->{'app'}->{'restore'}, $query);

			# Create link for password restore
			$code = $config->{'mesg'}->{'restore_link'}."http://".$config->{'conf'}->{'url'}."/restore?code=$code";

			# Send e-mail
			$resp = &send_mail(
				'server'=> $config->{'conf'}->{'smtp_server'},
				'port'	=> $config->{'conf'}->{'smtp_port'},
				'login'	=> $config->{'conf'}->{'smtp_login'},
				'pass'	=> $config->{'conf'}->{'smtp_password'},
				'from'	=> $config->{'conf'}->{'robot_mail'},
				'to'	=> $self->param('forgot'),
				'subj'	=> 'Password restore link',
				'text'	=> $code
			);

			if ($resp) {
				push @error, "login=".$config->{'mesg'}->{'while_sending_error'};

				# try again
				$self->cookie('error' => join('|', @error),  { domain => $config->{'mesg'}->{'url'}, expires => $config->{'mesg'}->{'url'} } );
				$self->res->code(301);
				$self->redirect_to('/forgot.html');
				return;
			}

			# Clear massages
			$self->cookie('error' => '', {expires => -1} );

			# success sent email
			push @error, "forgot=".$config->{'mesg'}->{'sent_email'};
			$self->cookie('error' => join('|', @error),  { domain => $config->{'mesg'}->{'url'}, expires => $config->{'mesg'}->{'url'} } );
			$self->res->code(301);
			$self->redirect_to('/index.html');
			return;
		}
		else {
			push @error, "login=".$config->{'mesg'}->{'email_error'};

			# try again
			$self->cookie('error' => join('|', @error),  { domain => $config->{'mesg'}->{'url'}, expires => $config->{'mesg'}->{'url'} } );
			$self->res->code(301);
			$self->redirect_to('/forgot.html');
			
		}
	}
}

sub confirm {
	my ($self, $code, $codes, $list, $bal, $text, $resp, $query, $ua, $tx, @tmp, @error);
	($self) = @_;

	$code = $self->param('confirm');
	if ($code) {
		# check exists code
		$codes = &dblist(
			'collection'	=> $self->{'app'}->{'new_users'},
			'query'		=> { 'code' => $code }
		);

		if (scalar(@{$codes}) == 1) {
			# check exists new user in current user & balance list databases
			$list = &dblist(
				'collection'	=> $self->{'app'}->{'users'},
				'query'		=> { 'login' => $$codes[0]->{'login'}, 'email' => $$codes[0]->{'email'} }
			);
			$bal = &dblist(
				'collection'	=> $self->{'app'}->{'balance'},
				'query'		=> { 'login' => $$codes[0]->{'login'} }
			);
			if ((scalar(@{$list}) > 0)||(scalar(@{$bal}) > 0)) {
				push @error, "restore=".$config->{'mesg'}->{'new_user_exists'};
				$self->cookie('error' => join('|', @error),  { domain => $config->{'mesg'}->{'url'}, expires => $config->{'mesg'}->{'url'} } );

				$self->res->code(301);
				$self->redirect_to('/add2.html');
				return;
			}
			$list = $bal = '';

			# Create new user in balance database
			&dbinsert($self->{'app'}->{'balance'}, { 'login' =>$$codes[0]->{'login'}, 'balance' => 0 });

			# Create new user in user-list database
			&dbinsert($self->{'app'}->{'users'}, $$codes[0]->{'user'});

			# check added users in user & balance databases
			$list = &dblist(
				'collection'	=> $self->{'app'}->{'users'},
				'query'		=> { 'login' => $$codes[0]->{'login'}, 'email' => $$codes[0]->{'email'} }
			);
			$bal = &dblist(
				'collection'	=> $self->{'app'}->{'balance'},
				'query'		=> { 'login' => $$codes[0]->{'login'} }
			);
			if ((scalar(@{$list}) != 1 )&&(scalar(@{$bal}) != 1)) {
				# delete added user from new user database
				&dbremove($self->{'app'}->{'users'}, {'email' => $$codes[0]->{'email'}} );

				# delete added user from balance database
				&dbremove($self->{'app'}->{'balance'}, {'email' => $$codes[0]->{'email'}} );

				push @error, "restore=".$config->{'mesg'}->{'new_user_error'};
				$self->cookie('error' => join('|', @error),  { domain => $config->{'mesg'}->{'url'}, expires => $config->{'mesg'}->{'url'} } );

				$self->res->code(301);
				$self->redirect_to('/add2.html');
				return;
			}

			# reload auth-daemon
			$ua = Mojo::UserAgent->new;
			$tx = $ua->get( "http://$config->{'conf'}->{'urlauthdaemon'}:$config->{'conf'}->{'portauthdaemon'}/rel");

			# Get & check auth response
			unless ($tx->success) {
				@tmp = $tx->error;
				push @error, "login=".$config->{'mesg'}->{'not_set_new_password'};
				$self->cookie('error' => join('|', @error),  { domain => $config->{'mesg'}->{'url'}, expires => $config->{'mesg'}->{'url'} } );

				$self->res->code(301);
				$self->redirect_to('/add2.html');
				return;
			}

			# remove new user from new_users database
			&dbremove($self->{'app'}->{'new_users'}, {'email' => $$codes[0]->{'email'}} );

			# prepare user data for sending to user
#			@tmp = ('login', 'pass', 'name', 'org', 'street', 'city', 'sp', 'pc', 'cc', 'voice', 'fax', 'email');
#			map { $text .= $self->param($_); } (@tmp);
#			$text .= "<hr>\n\n";
#			@tmp = ('autorenew', 'notification', 'transfer', 'prohibit', 'nschanging', 'dnschanging');
#			map { $text .= $self->param($_); } (@tmp);

			# Send mail to new user
			$resp = &send_mail(
				'server'=> $config->{'conf'}->{'smtp_server'},
				'port'	=> $config->{'conf'}->{'smtp_port'},
				'login'	=> $config->{'conf'}->{'smtp_login'},
				'pass'	=> $config->{'conf'}->{'smtp_password'},
				'from'	=> $config->{'conf'}->{'robot_mail'},
				'to'	=> $$codes[0]->{'email'},
				'subj'	=> 'Confirmed',
#				'text'	=> $config->{'mesg'}->{'new_user_created'}.$text
				'text'	=> $config->{'mesg'}->{'new_user_created'}
			);

			if ($resp) {
				push @error, "restore=".$config->{'mesg'}->{'while_sending_error'};
			}

			# add creating user command in epp queue
			$query = {
				'owner'		=> $$codes[0]->{'user'}->{'login'},
				'status'	=> 'new',
				'date'		=> join('', Time::HiRes::gettimeofday),
				'command'	=> 'create_contact',
				'request'	=> {
					'id' => 'autonic',
					'postalInfo' => {
						'loc' => {
							'name' => $$codes[0]->{'user'}->{'postalInfo'}->{'loc'}->{'name'},
							'org' => $$codes[0]->{'user'}->{'postalInfo'}->{'loc'}->{'org'},
							'addr' => {
								'street'=> [ $$codes[0]->{'user'}->{'postalInfo'}->{'loc'}->{'addr'}->{'street'}[0] ],
								'city'	=> $$codes[0]->{'user'}->{'postalInfo'}->{'loc'}->{'addr'}->{'city'},
								'sp'	=> $$codes[0]->{'user'}->{'postalInfo'}->{'loc'}->{'addr'}->{'sp'},
								'pc'	=> $$codes[0]->{'user'}->{'postalInfo'}->{'loc'}->{'addr'}->{'pc'},
								'cc'	=> $$codes[0]->{'user'}->{'postalInfo'}->{'loc'}->{'addr'}->{'cc'}
							},
						},
					},
					'voice'	=> &format_phone($$codes[0]->{'user'}->{'voice'}),
					'fax'	=> &format_phone($$codes[0]->{'user'}->{'fax'}),
					'email'	=> $$codes[0]->{'user'}->{'email'},
					'authInfo' => &create_rnd(11)
				}
			};
			&dbinsert($self->{'app'}->{'queue_contacts'}, $query);

			push @error, "restore=".$config->{'mesg'}->{'new_user_created'};
			$self->cookie('error' => join('|', @error),  { domain => $config->{'mesg'}->{'url'}, expires => $config->{'mesg'}->{'url'} } );

			$self->res->code(301);
			$self->redirect_to('/add3.html');
			return;
		}
		elsif (scalar(@{$codes}) == 0) {
			push @error, "confirm=".$config->{'mesg'}->{'new_user_exists'};
		}
		else {
			push @error, "confirm=".$config->{'mesg'}->{'more_one_code'};
		}
	}

	# try again
	if (scalar(@error)) {
		$self->cookie('error' => join('|', @error),  { domain => $config->{'mesg'}->{'url'}, expires => $config->{'mesg'}->{'url'} } );
	}

	$self->res->code(301);
	$self->redirect_to('/add2.html');
	return;
}

sub restore {
	my ($self, $code, $codes, $pass, $resp, $users, $ua, $tx, @error, @tmp);
	($self) = @_;

	$code = $self->param('code');
	if ($code) {
		# check exists code
		$codes = &dblist(
			'collection'	=> $self->{'app'}->{'restore'},
			'query'		=> { 'code' => $code }
		);

		if (scalar(@{$codes}) == 1) {
			if (exists $$codes[0]->{'email'}) {
				# read list of users
				$users = &dblist(
					'collection'	=> $self->{'app'}->{'users'},
					'query'		=> { 'email' => $$codes[0]->{'email'} }
				);

				if (scalar(@{$users}) == 1) {
					@tmp = ('A'..'Z', '0'..'9', 'a'..'z');
					srand();
					for (1..9) { $pass .= $tmp[rand(@tmp)]; }

					# store new password to the database
					&update_user($self->{'app'}->{'users'}, {'email' => $$codes[0]->{'email'}}, {'pass' => $pass});

					# reload auth-daemon
					$ua = Mojo::UserAgent->new;
					$tx = $ua->post(
						"http://$config->{'conf'}->{'urlauthdaemon'}:$config->{'conf'}->{'portauthdaemon'}/" => form => {
							user	=> $self->param('login'),
							pass	=> $pass,
							rel	=> 1
						}
					);

					# Get & check auth response
					unless ($tx->success) {
						@tmp = $tx->error;
						push @error, "login=".$config->{'mesg'}->{'not_set_new_password'};
					}

					# send mail with new password
					$resp = &send_mail(
						'server'=> $config->{'conf'}->{'smtp_server'},
						'port'	=> $config->{'conf'}->{'smtp_port'},
						'login'	=> $config->{'conf'}->{'smtp_login'},
						'pass'	=> $config->{'conf'}->{'smtp_password'},
						'from'	=> $config->{'conf'}->{'robot_mail'},
						'to'	=> $$codes[0]->{'email'},
						'subj'	=> 'Restored',
						'text'	=> $config->{'mesg'}->{'restored_pass'}.$pass
					);

					if ($resp) {
						push @error, "restore=".$config->{'mesg'}->{'while_sending_error'};
					}
					else {
						push @error, "restore=".$config->{'mesg'}->{'sent_restored'};
					}

					# delete record of restore code
					&dbremove($self->{'app'}->{'restore'}, {'email' => $$codes[0]->{'email'}} );
				}
			}
		}
		else {
			push @error, "restore=".$config->{'mesg'}->{'more_one_code'};
		}
	}

	# try again
	$self->cookie('error' => join('|', @error),  { domain => $config->{'mesg'}->{'url'}, expires => $config->{'mesg'}->{'url'} } );

	$self->res->code(301);
	$self->redirect_to('/login.html');
	return;
}

sub check {
	my ($self, $cookie, $tmp, @error);
	($self) = @_;

	# check session if not log into system
	if ($self->session->{'login'}) {
		# check session & cookie
		$cookie = $self->cookie('session');
		if ($self->session->{'login'} && $cookie) {
			$tmp = JSON::XS->new->decode ($cookie);
			if (exists $$tmp{$self->session->{'login'}}) {
				if ($self->session->{'session'} eq $$tmp{$self->session->{'login'}}) {
					return 1;
				}
				else {
					push @error, "login=".$config->{'mesg'}->{'session_wrong'};
				}
			}
			else {
				push @error, "login=".$config->{'mesg'}->{'session_expired'};
			}
		}

		# Did not find user or incorrect password
		else {
			push @error, "login=".$config->{'mesg'}->{'session_expired'};
		}
		if (scalar(@error)) {
			$self->cookie('error' => join('|', @error),  { domain => $config->{'mesg'}->{'url'}, expires => $config->{'mesg'}->{'url'} } );
			$self->res->code(301);
			$self->redirect_to('/login.html');
			return 0;
		}
	}
	else {
		push @error, "login=".$config->{'mesg'}->{'session_expired'};

		$self->cookie('error' => join('|', @error),  { domain => $config->{'mesg'}->{'url'}, expires => $config->{'mesg'}->{'url'} } );
		$self->res->code(301);
		$self->redirect_to('/login.html');
		return 0;
	}
}

sub login {
	my ($self, $ua, $res, $auth, $tx, $err, $code, $user, $balance, $zones, @error);
	($self) = @_;

	# Check user
	if ($self->param('login') || $self->param('pass')) {
		# connect to auth server
		$ua = Mojo::UserAgent->new;
		$tx = $ua->post(
				"http://$config->{'conf'}->{'urlauthdaemon'}:$config->{'conf'}->{'portauthdaemon'}/" => form => {
				user	=> $self->param('login'),
				pass	=> $self->param('pass')
			}
		);

		# Get & check auth response
		unless ($res = $tx->success) {
			($err, $code) = $tx->error;
			push @error, "login=".$config->{'mesg'}->{'session_expired'};

			$self->cookie('error' => join('|', @error),  { domain => $config->{'mesg'}->{'url'}, expires => $config->{'mesg'}->{'url'} } );
			$self->res->code(301);
			$self->redirect_to('/login.html');
			return 0;
		}
		$auth = JSON::XS->new->decode ($res->body);

		if ($auth->{'auth'}) {
			# Read user balance
			$balance = &dblist(
				'collection'	=> $self->{'app'}->{'balance'},
				'query'		=> { 'login' => $self->param('login') }
			);
			if (@{$balance} != 1) {
				$self->render(
					template=> '/domains/error',
					mess	=> 'More than one balance for user <b>'.$self->param('login').'</b> exists in database',
				);
				return;
			}

			# Read setting of user
			$user = &dblist(
				'collection'	=> $self->{'app'}->{'users'},
				'query'		=> { 'login' => $self->param('login') },
				'fields'	=> { 'discount' => 1, 'login' => 1 }
			);
			if (@{$user} != 1) {
				$self->render(
					template=> '/domains/error',
					mess	=> 'More than one user <b>'.$self->param('login').'</b> exists in database',
				);
				return;
			}

			$code = create_rnd(32);

			# delete login/register/forgot cookies
			$self->cookie('error' => '', {expires => -1} );
			$self->cookie('error_forgot' => '', {expires => -1} );
			$self->cookie('fields_storage' => '', {expires => -1} );
			$self->session(
				'login'		=> $self->param('login'),
				'discount'	=> $$user[0]->{'discount'},
				'email'		=> $$user[0]->{'email'},
				'balance'	=> $$balance[0]->{'balance'},
				'hold'		=> $$balance[0]->{'hold'},
				'cunic'		=> $auth->{'cunic'},
				'type'		=> $auth->{'type'},
				'session'	=> $code
			);

			$code = JSON::XS->new->encode( { $self->param('login') => $code } );
			$self->cookie( 'session' => $code, { expires => time() + $config->{'conf'}->{'expires_cookie'} });

			# Read domains price to global hash for current user
			&load_domains_price($self->{'app'}->{'zones'}, $self->session->{'discount'});

			# calculate balans by payment documents
			&get_real_balance($self, $self->param('login'));

			$self->main();
		}
		else {
			push @error, "login=".$config->{'mesg'}->{'login_error'};

			$self->cookie('error' => join('|', @error),  { expires => time() + $config->{'conf'}->{'expires_cookie'} } );
			$self->res->code(301);
			$self->redirect_to('/login.html');
		}
		return 0;
	}
	else {
		push @error, "login=".$config->{'mesg'}->{'login_empty_error'};
		$self->cookie('error' => join('|', @error),  { expires => time() + $config->{'conf'}->{'expires_cookie'} } );
		$self->res->code(301);
		$self->redirect_to('/login.html');
		return 0;
	}
}

sub main {
	my ($self, $domain, $password, $template, $list, $newdomains);
	($self) = @_;

	$list = &dblist(
		'collection'	=> $self->{'app'}->{'domains'},
		'query'		=> { 'contacts.admin' => $self->session->{'cunic'} },
		'fields'	=> { 'name' => 1, 'exDate' => 1, 'expires' => 1 }
	);

	# read list of new domains
	$newdomains = &get_cart($self);

	$domain = $self->param('domain');
	if (scalar(@{$list})) {
		$template = '/login/domains';
	}
	else {
		$template = '/login/domainsnull';
	}
	$self->render(
		template	=> $template,
		path		=> $config->{'mesg'}->{'main'},
		balance 	=> $self->session->{'balance'},
		list		=> $list,
		newdomains	=> $newdomains,
		domain		=> $domain,
		timeout		=> $config->{'conf'}->{'epp_timeout'}
	);
	return;
}

sub logout {
	my ($self, $login, $password);
	($self) = @_;

	map { delete $self->session->{$_}; } (keys %{$self->session});

	$self->cookie('session' => '', {expires => -1} );
	$self->cookie('error' => '', {expires => -1} );
	$self->cookie('error_forgot' => '', {expires => -1} );
	$self->cookie('fields_storage' => '', {expires => -1} );
	
	$self->res->code(301);
	$self->redirect_to('/login.html');
	return;
}

1;