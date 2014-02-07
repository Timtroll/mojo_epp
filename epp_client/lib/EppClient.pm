package EppClient;

use strict;
use warnings;

use Mojo::Base 'Mojolicious';
use Mojolicious::Plugin::Config;

use Data::Dumper;

use common;

# Set connetctions for global use
has [qw(zones domains users balance popularzones queue_domains queue_contacts helpdesk restore new_users history)];

# This method will run once at server start
sub startup {
	my $self = shift;

	# Secret for cookie
	$self->secrets(['yfenbkec']);

	# load database config
	$config = $self->plugin(Config => { file => rel_file('../epp.conf') });

	# set life-time fo session (second)
	$self->sessions->default_expiration($config->{'conf'}->{'epp_timeout'});

	# Create Db connection to zones
	my $zones = dbconn($config->{'conf'}->{'database'}, $config->{'collection'}->{'zones'});
	$self->zones($zones);

	# Create Db connections to domains
	my $domains = dbconn($config->{'conf'}->{'database'}, $config->{'collection'}->{'domains'});
	$self->domains($domains);

	# Create list of users
	my $users = dbconn($config->{'conf'}->{'database'}, $config->{'collection'}->{'contacts'});
	$self->users($users);

	# Create list of users
	my $balance = dbconn($config->{'conf'}->{'database'}, $config->{'collection'}->{'balance'});
	$self->balance($balance);

	# Create queue for contacts
	my $queue_contacts = dbconn($config->{'conf'}->{'database'}, $config->{'collection'}->{'queue_contacts'});
	$self->queue_contacts($queue_contacts);

	# Create queue for contacts
	my $queue_domains = dbconn($config->{'conf'}->{'database'}, $config->{'collection'}->{'queue_domains'});
	$self->queue_domains($queue_domains);

	# Create queue for restore user passwords
	my $restore = dbconn($config->{'conf'}->{'database'}, $config->{'collection'}->{'restore'});
	$self->restore($restore);

	# Create temp for new users
	my $new_users = dbconn($config->{'conf'}->{'database'}, $config->{'collection'}->{'new_users'});
	$self->new_users($new_users);

	# Create payment history for new users
	my $history = dbconn($config->{'conf'}->{'database'}, $config->{'collection'}->{'history'});
	$self->history($history);

	# Create helpdesk for users
	my $helpdesk = dbconn($config->{'conf'}->{'database'}, $config->{'collection'}->{'helpdesk'});
	$self->helpdesk($helpdesk);

	# Create list of popular domains
	my $list = popular($domains);
	$self->popularzones($list);

	# load domains price for all users
	&load_domains_price($zones, 5);

	# Router
	my $r = $self->routes;

	# set main command
	$r->route('/whois')			->to('query#whois')		->name('whois');

	$r->route('/query_one')			->to('query#query_one')		->name('query_one');
	$r->route('/querydomain')		->to('query#querydomain')	->name('querydomain');
	$r->route('/transfer')			->to('query#transfer')		->name('transfer');
	$r->route('/trans_to_queue')		->to('query#trans2queue')	->name('transfer_to_queue');

	$r->route('/singup')			->to('login#singup')		->name('singup');
	$r->route('/confirm')			->to('login#confirm')		->name('confirm');
	$r->route('/repeat')			->to('login#repeat')		->name('confirm');

	$r->route('/restore')	->via('get')	->to('login#restore')		->name('restore');
	$r->route('/forgot')			->to('login#forgot')		->name('forgot');

	$r->route('/enter')			->to('login#login')		->name('login');
	my $rn = $r->bridge('/')		->to('login#check');
	$rn->route('/main')	->via('get')	->to('login#main')		->name('main');
	$rn->route('/logout')	->via('get')	->to('login#logout')		->name('logout');

	$rn->route('/query_domain')		->to('query#query_domain')	->name('query_domain');
	$rn->route('/query')	->via('post')	->to('query#query')		->name('query');
	$rn->route('/trans_queue')		->to('domains#transfer')	->name('transferauth');

	$rn->route('/cart')			->to('domains#cart')		->name('cart');

	$rn->route('/pref')			->to('pref#pref')		->name('pref');
	$rn->route('/savepref')			->to('pref#savepref')		->name('savepref');

	$rn->route('/pay')	->via('get')	->to('fin#pay')			->name('pay');
	$rn->route('/sendpay')			->to('fin#sendpay')		->name('sendpay');
	$rn->route('/payment')			->to('fin#payment')		->name('payment');
	$rn->route('/history')			->to('fin#history')		->name('history');
#	$rn->route('/mail')	->via('get')	->to('mail#mail')		->name('mail');

	$rn->route('/reg')			->to('domains#reg')		->name('reg');
#	$rn->route('/renew')	->via('get')	->to('domains#renew')		->name('renew');
#	$rn->route('/delete')	->via('get')	->to('domains#delete')		->name('delete');
#	$rn->route('/getauth')	->via('get')	->to('domains#getauth')		->name('ns');


#	$rn->route('/dns')	->via('get')	->to('domains#dns')		->name('dns');
#	$rn->route('/ns')	->via('get')	->to('domains#ns')		->name('ns');
}

1;
