package EppClient::Pref;

use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Log;
use Time::HiRes;
use Data::Dumper;

use common;
use Subs;

my $log = Mojo::Log->new(path => 'log/login.log', level => 'debug');
my %fields = (
	'org'	=> 0,
	'fax'	=> 0,
	'id'	=> 0,
	'login'	=> 1,

	'cc'	=> 1,
	'name'	=> 1,
	'email'	=> 1,
	'voice'	=> 1,
	'pc'	=> 1,
	'sp'	=> 1,
	'city'	=> 1,
	'street'=> 1
);
my %service = (
	'autorenew'	=> 0,
	'notification'	=> 0,
	'transfer'	=> 0,
	'prohibit'	=> 0,
	'nschanging'	=> 0,
	'dnschanging'	=> 0
);

my %out = ();

# This method will run once at server login
sub pref {
	my ($self, $domain, $dis, $empty);
	($self) = @_;

	%out = ();
	$domain = $self->param('domain');
	$dis = $self->session->{'discount'};
	$dis = $config->{'discount'}->{"dis$dis"};
	$empty = &getpref($self, 1);

	$self->cookie('error' => '', {expires => -1} );
	$self->render(
		template=> '/pref/pref',
		path	=> $config->{mesg}->{'edit_contact'},
		balance	=> $self->session->{'balance'},
		type	=> $self->session->{'type'},
		discount=> $dis,
		domain	=> $domain,
		timeout => $config->{'conf'}->{'epp_timeout'},
		list	=> \%out
	);
}

sub getpref {
	my ($self, $list, $flag, $name, $empty);
	$self = shift;
	$flag = shift;

	$name = $self->session->{'login'};
	$list = dblist(
		'collection'	=> $self->{'app'}->{'users'},
		'query'		=> { 'login' => $name }
	);
	unless (scalar(@{$list})) {
		$self->render(
			template=> '/domains/error',
			mess	=> 'Not exists user <b>'.$self->session->{'login'}.'</b> in database',
		);
	}
	elsif (scalar(@{$list}) > 1) {
		$self->render(
			template=> '/domains/error',
			mess	=> 'More than one user <b>'.$self->session->{'login'}.'</b> exists in database',
		);
	}

	if ($flag) {
		if ($$list[0]->{'org'}) { $out{'org'} = $$list[0]->{'postalInfo'}->{'loc'}->{'org'}; }
		else { $out{'org'} = ''; }
		if ($$list[0]->{'fax'}) { $out{'fax'} = $$list[0]->{'fax'}; }
		else { $out{'fax'} = ''; }
		if ($$list[0]->{'id'}) { $out{'id'} = $$list[0]->{'id'}; }
		else { $out{'id'} = ''; }

		if ($$list[0]->{'login'}) { $out{'login'} = $$list[0]->{'login'}; }
		else { $out{'login'} = ''; $empty++; }
		if ($$list[0]->{'postalInfo'}->{'loc'}->{'addr'}->{'cc'}) { $out{'cc'} = $$list[0]->{'postalInfo'}->{'loc'}->{'addr'}->{'cc'}; }
		else { $out{'cc'} = ''; $empty++; }
		if ($$list[0]->{'postalInfo'}->{'loc'}->{'name'}) { $out{'name'} = $$list[0]->{'postalInfo'}->{'loc'}->{'name'}; }
		else { $out{'name'} = ''; $empty++; }
		if ($$list[0]->{'email'}) { $out{'email'} = $$list[0]->{'email'}; }
		else { $out{'email'} = ''; $empty++; }
		if ($$list[0]->{'voice'}) { $out{'voice'} = $$list[0]->{'voice'}; }
		else { $out{'voice'} = ''; $empty++; }
		if ($$list[0]->{'postalInfo'}->{'loc'}->{'addr'}->{'pc'}) { $out{'pc'} = $$list[0]->{'postalInfo'}->{'loc'}->{'addr'}->{'pc'}; }
		else { $out{'pc'} = ''; $empty++; }
		if ($$list[0]->{'postalInfo'}->{'loc'}->{'addr'}->{'sp'}) { $out{'sp'} = $$list[0]->{'postalInfo'}->{'loc'}->{'addr'}->{'sp'}; }
		else { $out{'sp'} = ''; }
		if ($$list[0]->{'postalInfo'}->{'loc'}->{'addr'}->{'city'}) { $out{'city'} = $$list[0]->{'postalInfo'}->{'loc'}->{'addr'}->{'city'}; }
		else { $out{'city'} = ''; $empty++; }
		if ($$list[0]->{'postalInfo'}->{'loc'}->{'addr'}->{'street'}[0]) { $out{'street'} = $$list[0]->{'postalInfo'}->{'loc'}->{'addr'}->{'street'}[0]; }
		else { $out{'street'} = ''; $empty++; }

		foreach (keys %service) {
			if ($$list[0]->{'package'}->{$_}) { $out{$_} = 1; }
			else { $out{$_} = ''; $empty++; }
		}

	}
	else {
		if ($self->session->{'type'} =~ /^admin$/) {
			foreach (keys %fields) {
				if ($self->param($_)) { $out{$_} = $self->param($_); }
				else {
					$out{$_} = '';
					if ($fields{$_}) { $empty++; }
				}
			}
		}
		else {
			if ($$list[0]->{'org'}) { $out{'org'} = $$list[0]->{'postalInfo'}->{'loc'}->{'org'}; }
			else { $out{'org'} = ''; }
			if ($$list[0]->{'fax'}) { $out{'fax'} = $$list[0]->{'fax'}; }
			else { $out{'fax'} = ''; }
			if ($$list[0]->{'id'}) { $out{'id'} = $$list[0]->{'id'}; }
			else { $out{'id'} = ''; }

			if ($$list[0]->{'login'}) { $out{'login'} = $$list[0]->{'login'}; }
			else { $out{'login'} = ''; $empty++; }
			if ($$list[0]->{'postalInfo'}->{'loc'}->{'addr'}->{'cc'}) { $out{'cc'} = $$list[0]->{'postalInfo'}->{'loc'}->{'addr'}->{'cc'}; }
			else { $out{'cc'} = ''; $empty++; }
			if ($$list[0]->{'postalInfo'}->{'loc'}->{'name'}) { $out{'name'} = $$list[0]->{'postalInfo'}->{'loc'}->{'name'}; }
			else { $out{'name'} = ''; $empty++; }
			if ($$list[0]->{'email'}) { $out{'email'} = $$list[0]->{'email'}; }
			else { $out{'email'} = ''; $empty++; }
			if ($$list[0]->{'voice'}) { $out{'voice'} = $$list[0]->{'voice'}; }
			else { $out{'voice'} = ''; $empty++; }
			if ($$list[0]->{'postalInfo'}->{'loc'}->{'addr'}->{'pc'}) { $out{'pc'} = $$list[0]->{'postalInfo'}->{'loc'}->{'addr'}->{'pc'}; }
			else { $out{'pc'} = ''; $empty++; }
			if ($$list[0]->{'postalInfo'}->{'loc'}->{'addr'}->{'sp'}) { $out{'sp'} = $$list[0]->{'postalInfo'}->{'loc'}->{'addr'}->{'sp'}; }
			else { $out{'sp'} = ''; $empty++; }
			if ($$list[0]->{'postalInfo'}->{'loc'}->{'addr'}->{'city'}) { $out{'city'} = $$list[0]->{'postalInfo'}->{'loc'}->{'addr'}->{'city'}; }
			else { $out{'city'} = ''; $empty++; }
			if ($$list[0]->{'postalInfo'}->{'loc'}->{'addr'}->{'street'}[0]) { $out{'street'} = $$list[0]->{'postalInfo'}->{'loc'}->{'addr'}->{'street'}[0]; }
			else { $out{'street'} = ''; $empty++; }
		}

		foreach (keys %service) {
			if ($self->param($_)) { $out{$_} = 1; }
			else { $out{$_} = ''; }
		}
	}

	return $empty;
}

sub savepref {
	my ($self, $domain, $dis, $empty, $query, $find, $resp, $text, $txt, @error);
	($self) = @_;

	$domain = $self->param('domain');
	$dis = $self->session->{'discount'};
	$dis = $config->{'discount'}->{"dis$dis"};
	$empty = &getpref($self);

	if ($empty) {
		%out = ();
		$self->render(
			template=> '/pref/pref',
			path	=> $config->{mesg}->{'edit_contact'},
			balance	=> $self->session->{'balance'},
			type	=> $self->session->{'type'},
			discount=> $dis,
			domain	=> $domain,
			timeout => $config->{'conf'}->{'epp_timeout'},
			list	=> \%out
		);
	}
	else {
		# save service properties
		$query = {
			'package' => {
				'autorenew'	=> $out{'autorenew'} ? 1 : 0,
				'notification'	=> $out{'notification'} ? 1 : 0,
				'transfer'	=> $out{'transfer'} ? 1 : 0,
				'prohibit'	=> $out{'prohibit'} ? 1 : 0,
				'nschanging'	=> $out{'nschanging'} ? 1 : 0,
				'dnschanging'	=> $out{'dnschanging'} ? 1 : 0
			}
		};
		# send mail if exists new password
		if ($self->param('login')) {
			$query->{'login'} = $self->param('login');
		}
		$find = { 'login' => $self->session->{'login'} };
		&dbupdate($self->{'app'}->{'users'}, $find, $query);

		# add task 'modify user' to queue
		$query = {
			owner	=> $self->session->{'login'},
			status	=> 'new',
			date	=> join('', Time::HiRes::gettimeofday),
			command	=> 'update_contact',
			request	=> {
				chg => {
					postalInfo => {
						int => {
							name => $out{'name'},
							org => $out{'org'},
							addr => {
								street => [ $out{'street'} ],
								city => $out{'city'},
								sp => $out{'sp'},
								pc => $out{'pc'},
								cc => uc($out{'cc'})
							},
						},
					},
					voice => &format_phone($out{'fax'}),
					fax => &format_phone($out{'fax'}),
					email => $out{'email'},
					authInfo => &create_rnd(11)
				}
			}
		};
		&dbinsert($self->{'app'}->{'queue_contacts'}, $query);

		# send email to user
		foreach (sort {$a cmp $b} keys %out) {
			if (exists $service{$_}) {
				if ($out{$_}) { $txt .= $config->{mesg}->{"text_".$_}.": ".$config->{mesg}->{"text_on"}."<br>\n"; }
				else { $txt .= $config->{mesg}->{"text_".$_}.": ".$config->{mesg}->{"text_off"}."<br>\n"; }
			}
			else {
				$text .= $config->{mesg}->{"text_".$_}.": $out{$_}<br>\n";
			}
		}
		$text = "$text<hr>\n\n$txt";
		$resp = &send_mail(
			'server'=> $config->{'conf'}->{'smtp_server'},
			'port'	=> $config->{'conf'}->{'smtp_port'},
			'login'	=> $config->{'conf'}->{'smtp_login'},
			'pass'	=> $config->{'conf'}->{'smtp_password'},
			'from'	=> $config->{'conf'}->{'robot_mail'},
			'to'	=> $self->session->{'email'},
			'subj'	=> $config->{mesg}->{'mail_changing_pref'},
			'text'	=> $text
		);

		# send message to user
		$query = {
			'to'	=> $self->session->{'login'},
			'from'	=> 'admin',
			'subj'	=> $config->{mesg}->{'mail_changing_pref'},
			'text'	=> $text,
			'status'=> 'new'
		};
		&dbinsert($self->{'app'}->{'helpdesk'}, $query);

		# ckeck error while sending mail
		if ($resp) { push @error, "email=".$resp; }

		# set message ' changes saved saved'
		%out = ();
		push @error, 'mess='.$config->{mesg}->{'mail_changing_pref'};
		$self->cookie('error' => join('|', @error),  { domain => $config->{'mesg'}->{'url'}, expires => $config->{'mesg'}->{'url'} } );
	
		# print main page
		$self->res->code(301);
		$self->redirect_to('/main');
	}

}

1;