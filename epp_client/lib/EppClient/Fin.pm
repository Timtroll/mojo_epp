package EppClient::Fin;

use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Log;
use Mojo::UserAgent;
use Digest::MD5 qw(md5_hex);
use Digest::SHA1 qw(sha1_hex);

use common;
use Subs;
use Data::Dumper;

my $log = Mojo::Log->new(path => 'log/login.log', level => 'debug');

my $months = {
	1 => { 'month' => 'Январь', 'bal' => 0, 'bal' => 0},
	2 => { 'month' => 'Февраль', 'bal' => 0 },
	3 => { 'month' => 'Март', 'bal' => 0 },
	4 => { 'month' => 'Апрель', 'bal' => 0 },
	5 => { 'month' => 'Май', 'bal' => 0 },
	6 => { 'month' => 'Июнь', 'bal' => 0 },
	7 => { 'month' => 'Июль', 'bal' => 0 },
	8 => { 'month' => 'Август', 'bal' => 0 },
	9 => { 'month' => 'Сентябрь', 'bal' => 0 },
	10 => { 'month' => 'Октябрь', 'bal' => 0 },
	11 => { 'month' => 'Ноябрь', 'bal' => 0 },
	12 => { 'month' => 'Декабрь', 'bal' => 0 },
	'max' => 0
};

sub pay {
	my ($self, $domain);
	($self) = shift;

	$domain = $self->param('domain');

	$self->render(
		template 	=> '/fin/fin',
		path		=> $config->{'mesg'}->{'pay'},
		balance 	=> $self->session->{'balance'},
		domain		=> $domain,
		amt		=> $config->{'recharge'},
		ccy		=> '',
		recharge	=> $config->{'recharge'},
		order		=> $self->session->{'login'}.'-'.time(),
		details		=> $config->{'mesg'}->{'order'},
		timeout 	=> $config->{'conf'}->{'epp_timeout'}
	);

}

sub payment {
	my ($self, $list);
	($self) = shift;

	# get list of payments fo current user
	$list = &dblist(
		'collection'	=> $self->{'app'}->{'history'},
		'query'		=> {'payment.order' => $self->param('order'), 'owner' => $self->session->{'login'}}
	);

	if (scalar(@{$list}) == 1) {
		$self->render(template => '/fin/payment', list => $list);
	}
	else {
		$self->render(template => '/fin/payment', list => $list);
	}
}

sub calc_balance {
	my ($self, $list, $zones, $tmp, $date, $max, %price);
	($self) = shift;

	# read domans list for current user
	$list = &dblist(
		'collection'	=> $self->{'app'}->{'domains'},
		'query'		=> {'contacts.admin' => $self->session->{'cunic'}}
	);
	map { $months->{$_}->{'bal'} = 0; } (1..12);

	map {
		$tmp = $_->{'name'};
		$tmp =~ s/^.*?\.//;
		$date = int($_->{'date'}/100);
		$months->{$date}->{'bal'} = $months->{$date}->{'bal'} + $config->{'domains_price'}->{$tmp};
	} (@{$list});

	# create finally object
	$max = 0;
	map {
		if ($months->{$_}->{'bal'} > $max) { $max = $months->{$_}->{'bal'}; }
	} (1..12);
	$months->{'max'} = int($max);
}

sub history {
	my ($self, $list, $domain);
	($self) = shift;

	$self->cookie('error' => '', {expires => -1} );
	$domain = $self->param('domain');

	# calculate balances for all months
	&calc_balance($self);

	# get list of payments fo current user
	$list = &dblist(
		'collection'	=> $self->{'app'}->{'history'},
		'query'		=> {'owner' => $self->session->{'login'}}
	);

	$self->render(
		template => '/fin/history',
		path	=> $config->{'mesg'}->{'history'},
		balance => $self->session->{'balance'},
		months	=> $months,
		domain	=> $domain,
		list	=> $list,
		timeout => $config->{'conf'}->{'epp_timeout'}
	);
}

sub sendpay {
	my ($self, $pass, $signature, $domain, $payment, $list, $balance, @error, @tmp, @temp, %tmp);
	($self) = shift;

	$domain = $self->param('domain');
	$pass = 'ZnE9fU0R1V6w84T3WjrR85N02kg74q16';
	if ($self->param('payment') && $self->param('signature')) {
		# $signature = sha1(md5($self->param('payment').$pass));
		$signature = sha1_hex(md5_hex(($self->param('payment').$pass))); 
		if ($signature eq $self->param('signature')) {
			# create responce from 'payment'
			@tmp = split('&', $self->param('payment'));
			foreach (@tmp) {
				@temp = ();
				@temp = split('=', $_);
				$tmp{$temp[0]} = $temp[1];
			}

			if ($tmp{'state'} eq 'test') {
				# check exists payment
				$list = &dblist(
					'collection'	=> $self->{'app'}->{'history'},
					'query'		=> {'payment.order' => $tmp{'order'}}
				);

				# check duble of payment
				unless (scalar(@{$list})) {
					# increase balance & store them to database
					$self->session->{'balance'} =  $self->session->{'balance'} + (($tmp{'amt'}/100)*(100 - $config->{'conf'}->{'primat_comiss'}));
					&dbupdate($self->{'app'}->{'balance'}, {'login' => $self->session->{'login'}}, {'balance' => $self->session->{'balance'}});

					# save payment to database
					$payment = {
						'date'	=> &sec2date(time(), '.'),
						'time'	=> time(),
						'owner'	=> $self->session->{'login'},
						'detail'=> $config->{'mesg'}->{'details_order'},
						'summ'	=> (($tmp{'amt'}/100)*(100 - $config->{'conf'}->{'primat_comiss'})),
						'type'	=> 'credit',
						'status'=> 'paid',
						'payment'=> {%tmp}
					};
					&dbinsert($self->{'app'}->{'history'}, $payment);
				}
			}
			else {
				# выслать предупреждение о попытке обмана
				# ???????????????????

				$self->res->code(301);
				$self->redirect_to('/logout');
				return;
			}

			# get list of payments fo current user
			$list = &dblist(
				'collection'	=> $self->{'app'}->{'history'},
				'query'		=> {'owner' => $self->session->{'login'}}
			);

			# check current balance
			$balance = 0;
			foreach (@{$list}) {
				if ($_->{'type'} eq 'credit') { $balance = $balance + $_->{'summ'}; }
				else { $balance = $balance - $_->{'summ'}; }
			}
			if ($self->session->{'balance'} != $balance) {
				$self->session->{'balance'} = $balance;

				# выслать предупреждение о попытке обмана
				# ???????????????????
				
				$self->res->code(301);
				$self->redirect_to('/logout');
				return;
			}

			push @error, "refush=".$config->{'mesg'}->{'success'};
			$self->cookie('error' => join('|', @error),  { domain => $config->{'mesg'}->{'url'}, expires => $config->{'mesg'}->{'url'} } );

			$self->render(
				template => '/fin/history',
				path	=> $config->{'mesg'}->{'history'},
				balance => $self->session->{'balance'},
				months	=> $months,
				domain	=> $domain,
				list	=> $list,
				timeout => $config->{'conf'}->{'epp_timeout'}
			);
			return;
		}
		else {
			push @error, "refush=".$config->{'mesg'}->{'refush'};
			$self->cookie('error' => join('|', @error),  { domain => $config->{'mesg'}->{'url'}, expires => $config->{'mesg'}->{'url'} } );

			$self->res->code(301);
			$self->redirect_to('/pay');
			return;
		}
	}
	else {
		push @error, "refush=".$config->{'mesg'}->{'refush'};
		$self->cookie('error' => join('|', @error),  { domain => $config->{'mesg'}->{'url'}, expires => $config->{'mesg'}->{'url'} } );

		$self->res->code(301);
		$self->redirect_to('/pay');
		return;
	}
}

1;