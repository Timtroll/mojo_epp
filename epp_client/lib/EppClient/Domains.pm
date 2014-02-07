package EppClient::Domains;

use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Log;
use JSON::XS;
use URI::Escape;

use common;
use Data::Dumper;

my $log = Mojo::Log->new(path => 'log/login.log', level => 'debug');

sub cart {
	my ($self, $name, $newdomains);
	($self) = @_;

	# read list of new domains
	$newdomains = &get_cart($self);

	$name = $self->param('name');
	$self->render(
		template	=> '/domains/cart',
		path		=> 'Список доменов выбранных для регистрации',
		balance 	=> $self->session->{'balance'},
		newdomains	=> $newdomains,
		domain		=> $name,
		timeout		=> $config->{'conf'}->{'epp_timeout'}
	);
	return;
}

sub transfer {
	my ($self, $zone, $zones, $res, $price, $adninc, $registrar, %tmp);
	($self) = @_;

	if ($self->param('domain')) {
		# get info price of zones for transfer
		$zone = $self->param('domain');
		$zone =~ s/^.*?\.//;
		$price = $config->{'domains_price'}->{$zone};

		$registrar = uri_unescape($self->param('reg'));
		$adninc = uri_unescape($self->param('admin'));

		# check balance
		if (($self->session->{'balance'} - $price) <= 0) {
			$self->res->code(301);
			$self->redirect_to('/empty_balance.html');
			return;
		}

		# check fields
		foreach (keys %{$config->{'transfer_auth'}}) {
			if ($self->param($_)) {
				$tmp{$_} = $self->param($_)
			}
		}

		$self->render(
			template=> '/domains/trans_queue',
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
	return;
}

sub reg {
	my ($self, $domain, $newdomains, $list, $mess, $max, $query);
	($self) = @_;

	# read list of new domains
	$newdomains = &get_cart($self);

	$domain = $self->param('name');

	# reg one domain
	if ($domain) {
		# check exists domain in queue
		$list = &dblist(
			'collection'	=> $self->{'app'}->{'queue_domains'},
			'query'		=> { 'request.name' => $domain }
		);
# print Dumper($list);
# print "\n";
# print $self->session->{'login'};
# print "\n";
# print "\n1=";
# print $$list[0]->{'owner'};
# print "\n2=";
# print $self->session->{'login'};
		if (scalar(@{$list}) == 1) {
			if ($$list[0]->{'owner'} ne $self->session->{'login'}) {
				$mess = $config->{'mesg'}->{'domain_exists_queue'}.$domain;
			}
			else {
				$mess = $config->{'mesg'}->{'domain_double_queue'}.$domain;
			}

			# show error message
			$self->render(
				template=> '/domains/reg',
				result	=> $mess
			);
			return;
		}
		elsif (scalar(@{$list}) > 1) {
			# delete oldest request
			$max = scalar(@{$list}) - 1;
print "$max\n=======\n";
			foreach (sort {$a->{'date'} <=> $b->{'date'}} @{$list}) {
if ($max) {
	# print $_->{'date'};
	print "'date' => $_->{'date'}, 'request.name' => $domain\n";
				&dbremove($self->{'app'}->{'queue_domains'}, {'date' => $_->{'date'} });
}
$max--;
			}

			# show error message
			$self->render(
				template=> '/domains/reg',
				result	=> $config->{'mesg'}->{'domain_double_queue'}.$domain
			);
			return;
		}

		# decrease balance
		# ??????????????

		# add command 'domain_create' to domains queue
		$query = {
			owner	=> $self->session->{'login'},
			status	=> 'new',
			date	=> join('', Time::HiRes::gettimeofday),
			command	=> 'create_domain',
			request	=> {
				'name'		=> $domain,
				'period'	=> 1,
				'registrant'	=> $config->{'conf'}->{'epp_user'},
				'authInfo'	=> &create_rnd(10),
				'contacts'	=> {
					'tech'		=> $config->{'conf'}->{'admin_cunic'},
					'billing'	=> $config->{'conf'}->{'admin_cunic'},
					'admin'		=> $config->{'conf'}->{'admin_cunic'}
				}
			}
		};
		&dbinsert($self->{'app'}->{'queue_domains'}, $query);

		# delete domain from cart cookie
		# ??????

		$self->render(
			template=> '/domains/reg',
			result	=> $config->{'mesg'}->{'add_domain_queue'}.$domain
		);
	}
	# reg all domains from cart
	elsif (scalar(keys %{$newdomains})) {
		if (scalar(keys %{$newdomains})) {
			# adding new domains to queue
			foreach (keys %{$newdomains}) {
				# check exists domain in queue
				# ??????????????

				# decrease balance
				# ??????????????

				# add command 'domain_create' to domains queue
				$query = {
					owner	=> $self->session->{'login'},
					status	=> 'new',
					date	=> join('', Time::HiRes::gettimeofday),
					command	=> 'create_domain',
					request	=> {
						'name'		=> $_,
						'period'	=> 1,
						'registrant'	=> $config->{'conf'}->{'epp_user'},
						'authInfo'	=> &create_rnd(10),
						'contacts'	=> {
							'tech'		=> $config->{'conf'}->{'admin_cunic'},
							'billing'	=> $config->{'conf'}->{'admin_cunic'},
							'admin'		=> $config->{'conf'}->{'admin_cunic'}
						}
					}
				};
				&dbinsert($self->{'app'}->{'queue_domains'}, $query);

				# delete cart cookie
				$self->cookie('domains_storage' => '', {expires => -1} );
			}

			$self->render(
				template	=> '/domains/regdomains',
				balance 	=> $self->session->{'balance'},
				path		=> 'Added domains to queue',
				domain		=> $domain,
				newdomains	=> $newdomains,
				timeout		=> $config->{'conf'}->{'epp_timeout'}
			);
		}
		else {
			$self->res->code(301);
			$self->redirect_to('/main');
		}
	}
	else {
		$self->res->code(301);
		$self->redirect_to('/main');
	}
}

sub ns {
	my ($self, $name, $cunic, $list);
	($self) = @_;

	$name = $self->param('name');
	$cunic = $self->session->{'cunic'};
	$list = dblist(
		'collection'	=> $self->{'app'}->{'domains'},
		'query'		=> { 'name' => $name, 'contacts.admin' => $cunic },
		'fields'	=> { 'name' => 1, 'ns' => 1 }
	);
	if (scalar(@{$list}) == 1) {
		$self->render(
			template=> '/domains/ns',
			path	=> 'Edit name servers',
			mess	=> 'Enter your pass',
			list	=> $list
		);
	}
	elsif (scalar(@{$list}) > 1) {
		$self->render(
			template=> '/domains/error',
			mess	=> 'More than one domain <b>'.$self->param('name').'</b> exists in database',
		);
	}
	else {
		$self->render(
			template=> '/domains/error',
			mess	=> 'Not exists domain <b>'.$self->param('name').'</b> in database',
		);
	}
}

sub dns {
	my ($self, $list, $name, $cunic, $flag, $tmp);
	($self) = @_;

	$name = $self->param('name');
	$cunic = $self->session->{'cunic'};

	# check name servers
	$list = dblist(
		'collection'	=> $self->{'app'}->{'domains'},
		'query'		=> { 'name' => $name, 'contacts.admin' => $cunic },
		'fields'	=> { 'name' => 1, 'ns' => 1 }
	);
	if (scalar(@{$list}) == 1) {
		foreach (@{$$list[0]->{'ns'}}) {
			unless (/spam\.net\.ua/) {
				$flag++;
			}
			$tmp .= "<br>".$_;
		}
		# $tmp = $$list[0]->{'ns'};
$self->render(text => $tmp );
return;
	}
	elsif (scalar(@{$list}) > 1) {
		$self->render(
			template=> '/domains/error',
			mess	=> 'More than one domain <b>'.$self->param('name').'</b> exists in database',
		);
	}
	else {
		$self->render(
			template=> '/domains/error',
			mess	=> 'Not exists domain <b>'.$self->param('name').'</b> in database',
		);
	}

	# if name servers 'spam.net.ua'

	# get DNS settings for current domain
my %api = (
	'client'	=> '88162734901261803542476c4419506f',
	'apikey'	=> '74713d95559425fb0a92b3a584f87476',
	'url'		=> 'https://api.digitalocean.com/domains',
	'ip'		=> '146.185.183.148'
);
my $apis = {
	'list'		=> {
		'url'		=> $api{'url'},
		'client_id'	=> $api{'client'},
		'api_key'	=> $api{'apikey'}
	},
};
	# 'new'		=> {
		# 'url'		=> $api{'url'},
		# 'client_id'	=> $api{'client'},
		# 'api_key'	=> $api{'apikey'},
		# 'name'		=> '',
		# 'ip_address'	=> $api{'ip'}
	# },
	# 'show'		=> {
		# 'url'		=> $api{'url'}."/",
		# 'client_id'	=> $api{'client'},
		# 'api_key'	=> $api{'apikey'}
	# },
	# 'destroy'		=> {
		# 'url'		=> $api{'url'}."/destroy",
		# 'client_id'	=> $api{'client'},
		# 'api_key'	=> $api{'apikey'}
	# },
	# 'records'		=> {
		# 'url'		=> $api{'url'}."/records",
		# 'client_id'	=> $api{'client'},
		# 'api_key'	=> $api{'apikey'}
	# },
	# 'records_new'		=> {
		# 'url'		=> $api{'url'}."/records/new",
		# 'client_id'	=> $api{'client'},
		# 'api_key'	=> $api{'apikey'}
	# },
	# 'records_id'		=> {
		# 'url'		=> $api{'url'}."/records/",
		# 'client_id'	=> $api{'client'},
		# 'api_key'	=> $api{'apikey'}
	# },
	# 'records_edit'		=> {
		# 'url'		=> $api{'url'}."/records//edit",
		# 'client_id'	=> $api{'client'},
		# 'api_key'	=> $api{'apikey'}
	# },
	# 'records_destroy'		=> {
		# 'url'		=> $api{'url'}."/records//destroy",
		# 'client_id'	=> $api{'client'},
		# 'api_key'	=> $api{'apikey'}
	# }
# };

use LWP::UserAgent;
use JSON::XS;
use Data::Dumper;
my $ua = new LWP::UserAgent;
$tmp = $apis->{'list'}->{'url'}.'?client_id='.$apis->{'list'}->{'client_id'}.'&api_key='.$apis->{'list'}->{'api_key'};
my $req = HTTP::Request->new(GET => $tmp );
my $res = $ua->request($req);
my $text = $res->content;
# $text =~ s/(\n|\r)/<br>/go;

my $json_xs = JSON::XS->new();
$json_xs->utf8(1);
$text = $json_xs->decode($text);
        
$self->render(text => Dumper($text)."\n\n$tmp" );
#$self->render(text => $res->as_string."\n\n$tmp" );
# $self->render(json => $tmp );
return;

	$list = domain_info($self->{'app'}->{'domains'}, $self->param('name'));
	if (scalar(@{$list}) == 1) {
		$self->render(
			template=> '/domains/dns',
			path	=> 'Edit DNS record',
			mess	=> 'Enter your pass',
#			list	=> $list
		);
	}
	else {
		$self->render(
			template=> '/domains/error',
			mess	=> 'More than one domain <b>'.$self->param('name').'</b> exists in database',
		);
	}
}

sub getauth {
	my ($self, $list);
	($self) = @_;

#	$list = domain_info($self->{'app'}->{'domains'}, $self->param('name'));
	if ($self->param('name')) {
		$self->render(
			template=> '/domains/getauth',
			path	=> 'Get AuthCode fo domain',
			mess	=> 'Enter your pass',
			domain	=> $self->param('name')
		);
	}
	else {
		$self->render(
			template=> '/domains/error',
			mess	=> 'You did not set domain for <b>GetAuth</b>',
		);
	}
}

1;