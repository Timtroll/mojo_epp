package EppClient::Query;

use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Log;
use URI::Escape;
use Mojo::UserAgent;
use Time::HiRes;

use Data::Dumper;

use common;
use Subs;

my $log = Mojo::Log->new(path => 'log/query.log', level => 'debug');


sub querydomain {
	my ($self, $domain, $info, %data);
	($self) = @_;

	$domain = $self->param('domain');
	if ($domain) {
		$domain =~ s/\..*$//;

		# load list of available zones excluding most popular domains
		map {
			unless (exists $self->{'app'}->{popularzones}->{$_->{'zone'}}) {
				$data{$_->{'zone'}} = 1;
			}
		} $self->{'app'}->{zones}->find( {}, { 'zone' => 1 } )->all;

		$self->render(template => '/query/query', timeout => $config->{'conf'}->{'epp_timeout'}, domain => $domain, dat => \%data, popularzones => $self->{'app'}->{popularzones}, mess => 'Query domain');
	}
	else {
		$self->res->code(301);
		$self->redirect_to('/');
	}
}

sub query {
	my ($self, $domain, $info, %data);
	($self) = @_;

	$domain = $self->param('domain');
	if ($domain) {
		$domain =~ s/\..*$//;

		# load list of available zones excluding most popular domains
		map {
			unless (exists $self->{'app'}->{popularzones}->{$_->{'zone'}}) {
				$data{$_->{'zone'}} = 1;
			}
		} $self->{'app'}->{zones}->find( {}, { 'zone' => 1 } )->all;

		$self->render(template => '/domains/query', timeout => $config->{'conf'}->{'epp_timeout'}, domain => $domain, dat => \%data, popularzones => $self->{'app'}->{popularzones}, mess => 'Query domain', timeout => $config->{'conf'}->{'epp_timeout'});
	}
	else {
		$self->res->code(301);
		$self->redirect_to('/');
	}
}

sub query_domain {
	my ($self, $domain, $domains, $result, $zone, $name, $price, $zones, $number, $adninc, $registrar);
	($self) = @_;

	$price = $config->{'domains_price'};
	$domain = $self->param('domain');
	if ($domain) {
		# check domain in regisrtation database
		$domains = &dblist(
			'collection'	=> $self->{'app'}->{'domains'},
			'query'		=> { 'name' => $domain }
		);

		unless (scalar(@{$domains})) { $result = &whois_exists($domain); }
		else { $result = 1; }
		$zone = $domain;
		$zone =~ s/^.*?\.//;

		# get domain info about registrator and administrator
		if ($zone =~ /ua$/) {
			$result =~ /(\n|\r).*?(admin.*?\:)(.*?)(\n|\r)/i;
			$adninc = $3;
		}
		else {
			$result =~ /(\n|\r).*?(Registrant Name\:)(.*?)(\n|\r)/i;
			$adninc = $3;
		}
		if ($adninc) {
			$adninc = uri_escape($adninc);
		}

		# get info about current registrator
		if ($zone =~ /crimea\.ua$/) {
			$result =~ /(\n|\r).*?(registrator\:)(.*?)(\n|\r)/i;
			$registrar = $3;
		}
		elsif ($zone =~ /ua$/) {
			$result =~ /(registrar\:)(.*?)(\n|\r)/;
			$registrar = $2;
		}
		else {
			$result =~ /(Registrar\:)(.*?)(\n|\r)/;
			$registrar = $2;
		}
		if ($registrar) {
			$registrar = uri_escape($registrar);
		}

		# check whois responce
		$result = &check_whois($result);

		# read price list of domains if need
		unless (scalar(keys %{$price})) {
			$zones = &dblist(
				'collection'	=> $self->{'app'}->{'zones'},
				'query'		=> {}
			);

			# create hash of free domain price
			map { $price->{$_->{'zone'}} = $_->{'price'}[$self->session->{'discount'}]; } (@{$zones});
			$config->{'domains_price'} = $price;
		}
	}
	else {
		$self->res->code(301);
		$self->redirect_to('/500.html');
	}

	if ($self->param('number')) { $number = $self->param('number'); }
	if ($self->param('name')) { $name = $self->param('name'); }

	$self->render(
		template=> '/domains/query_one',
		timeout	=> $config->{'conf'}->{'epp_timeout'},
		name	=> $name,
		zone	=> $zone,
		price	=> $price,
		reg	=> $registrar,
		admin	=> $adninc,
		result	=> $result,
		domain	=> $domain,
		number	=> $number
	);
	return;
}

sub query_one {
	my ($self, $domain, $domains, $result, $zone, $name, $price, $zones, $number, $adninc, $registrar);
	($self) = @_;

	$price = $config->{'domains_price'};
	$domain = $self->param('domain');
	if ($domain) {
		# check domain in regisrtation database
		$domains = &dblist(
			'collection'	=> $self->{'app'}->{'domains'},
			'query'		=> { 'name' => $domain }
		);

		unless (scalar(@{$domains})) { $result = &whois_exists($domain); }
		else { $result = 1; }
		$zone = $domain;
		$zone =~ s/^.*?\.//;

		# get domain info about registrator and administrator
		if ($zone =~ /ua$/) {
			$result =~ /(\n|\r).*?(admin.*?\:)(.*?)(\n|\r)/i;
			$adninc = $3;
		}
		else {
			$result =~ /(\n|\r).*?(Registrant Name\:)(.*?)(\n|\r)/i;
			$adninc = $3;
		}
		if ($adninc) {
			$adninc = uri_escape($adninc);
		}

		# get info about current registrator
		if ($zone =~ /crimea\.ua$/) {
			$result =~ /(\n|\r).*?(registrator\:)(.*?)(\n|\r)/i;
			$registrar = $3;
		}
		elsif ($zone =~ /ua$/) {
			$result =~ /(registrar\:)(.*?)(\n|\r)/;
			$registrar = $2;
		}
		else {
			$result =~ /(Registrar\:)(.*?)(\n|\r)/;
			$registrar = $2;
		}
		if ($registrar) {
			$registrar = uri_escape($registrar);
		}

		# check whois responce
		$result = &check_whois($result);

		# read price list of domains if need
		unless (scalar(keys %{$price})) {
			$zones = &dblist(
				'collection'	=> $self->{'app'}->{'zones'},
				'query'		=> {}
			);

			# create hash of free domain price
			map { $price->{$_->{'zone'}} = $_->{'price'}[$config->{'domains_discount'}]; } (@{$zones});
			$config->{'domains_price'} = $price;
		}
	}
	else {
		$self->res->code(301);
		$self->redirect_to('/500.html');
	}

	if ($self->param('number')) { $number = $self->param('number'); }
	if ($self->param('name')) { $name = $self->param('name'); }

	$self->render(
		template=> '/query/query_one',
		timeout	=> $config->{'conf'}->{'epp_timeout'},
		name	=> $name,
		zone	=> $zone,
		price	=> $price,
		reg	=> $registrar,
		admin	=> $adninc,
		result	=> $result,
		domain	=> $domain,
		number	=> $number
	);
	return;
}

sub transfer {
	my ($self, $zone, $zones, $template, $res, $price, $adninc, $registrar, %tmp);
	($self) = @_;

	if ($self->param('domain')) {
		$template = '/query/transfer';

		# get info price of zones for transfer
		$zone = $self->param('domain');
		$zone =~ s/^.*?\.//;

		$registrar = uri_unescape($self->param('reg'));
		$adninc = uri_unescape($self->param('admin'));
		$price = uri_unescape($self->param('price'));

		# check fields
		foreach (keys %{$config->{'transfer_nonauth'}}) {
			if ($self->param($_)) {
				$tmp{$_} = $self->param($_)
			}
		}

		$self->render(
			template=> $template,
			timeout	=> $config->{'conf'}->{'epp_timeout'},
			reg	=> $registrar,
			admin	=> $adninc,
			price	=> $price,
			zone	=> $zone,
			fields	=> \%tmp
		);
	}
	else {
		$self->res->code(301);
		$self->redirect_to('/500.html');
	}
}

sub trans2queue {
	my ($self, $flag, $string, $fields, $ua, $tx, $res, $auth, $domain, $domains, $find, $query, $list, %tmp);
	($self) = @_;

	# check login/pass or exists session
	if ($self->session->{'login'}) { $fields = 'transfer_auth'; }
	else { $fields = 'transfer_nonauth'; }

	# check fields
	foreach (keys %{$config->{$fields}}) {
		if ($self->param($_)) {
			$tmp{$_} = $self->param($_)
		}
		else { print "$_\n";$flag++; }
	}
	$string = join('&', map { $_.'='.$tmp{$_}; } (keys %tmp) );

	# set domain to queue if all fields are fill or try again
	if ($flag) {
		if ($self->session->{'login'}) {
			$flag = '/trans_queue?';
		}
		else {
			$flag = '/transfer?';
		}
		$self->res->code(301);
		$self->redirect_to($flag.$string);
		return;
	}
	else {
		$domain = $tmp{'domain'};

		# check exists transfer command in queue
		$domains = &dblist(
			'collection'	=> $self->{'app'}->{'domains'},
			'query'		=> {'name' => $domain}
		);
		$list = &dblist(
			'collection'	=> $self->{'app'}->{'queue_domains'},
			'query'		=> { 'request.name' => $domain, 'command' => 'domain_transfer_request' }
		);

		# check login/pass or exists session
		if ($self->session->{'login'}) {
			$auth = 1;

			if (scalar(@{$domains}) || scalar(@{$list})) {
				$self->res->code(301);
				$self->redirect_to('/added2queue.html');
				return;
			}

			# get transfer zone
			$tmp{'domain'} =~ s/^.*?\.//;

			# check balance
			if (($self->session->{'balance'} - $config->{'domains_price'}->{$tmp{'domain'}}) <= 0) {
				$self->res->code(301);
				$self->redirect_to('/empty_balance.html');
				return;
			}
		}
		else {
			if (scalar(@{$domains}) || scalar(@{$list})) {
				$self->res->code(301);
				$self->redirect_to('/add2queue.html');
				return;
			}

			$ua = Mojo::UserAgent->new;
			$tx = $ua->post(
					"http://$config->{'conf'}->{'urlauthdaemon'}:$config->{'conf'}->{'portauthdaemon'}/" => form => {
					user	=> $self->param('login'),
					pass	=> $self->param('pass')
				}
			);

			# Get & check auth response
			unless ($res = $tx->success) { $auth = 0; }
			else {
				$auth = JSON::XS->new->decode ($res->body);
				if ($auth->{'auth'}) { $auth = 1; }
				else { $auth = 0; }
			}
		}

		# hold price sum for transfer
		if ($auth) {
			# add invoice to history
			$query = {
				'detail'	=> $config->{'mesg'}->{'details_order_екфты'}.$domain,
				'owner'		=> $self->session->{'login'},
				'payment'	=> {
					'pay_way'	=> 'balance'
				},
				'date'	=> &sec2date(time(), '.'),
				'time'	=> time(),
				'type'	=> 'debet',
				'status'=> 'wait',
				'summ'	=> $config->{'domains_price'}->{$tmp{'domain'}}
			};
			&dbinsert($self->{'app'}->{'history'}, $query);

			# update balance and hold
			$self->session->{'balance'} = $self->session->{'balance'} - $config->{'domains_price'}->{$tmp{'domain'}};
			$self->session->{'hold'} = $self->session->{'hold'} + $config->{'domains_price'}->{$tmp{'domain'}};
			$find = { 'login' => $self->session->{'login'} };
			$query = {
				'balance'	=> $self->session->{'balance'},
				'hold'		=> $self->session->{'hold'}
			};
			&dbupdate($self->{'app'}->{'users'}, $find, $query);

			# set new transfer domain to queue
			if ($self->session->{'login'}) { $string = $self->session->{'login'}; }
			else { $string = $tmp{'login'}; }
			$query = {
				'request'	=> {
					'name'		=> $domain,
					'authInfo'	=> $tmp{'authinfo'},
					'period'	=> 1
				},
				'owner'		=> $string,
				'date'		=> join('', Time::HiRes::gettimeofday),
				'status'	=> 'new',
				'command'	=> 'domain_transfer_request'
			};
			&dbinsert($self->{'app'}->{'queue_domains'}, $query);
		}
	}

	$self->res->code(301);
	$self->redirect_to('/add2queue.html');
	return;
}

sub whois {
	my ($self, $domain, $result);
	($self) = @_;

	$domain = $self->param('domain');
	if ($domain) {
		$result = &whois_exists($domain);
		# $result = `whois $domain`;
		$result =~ s/(\r|\n)/<br>/go;
	}

	$self->render(
		template => '/query/whois',
		timeout => $config->{'conf'}->{'epp_timeout'},
		result => $result
	);
}

1;