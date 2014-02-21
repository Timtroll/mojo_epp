package Robot::Robot;

use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';
use Encode qw(decode encode);
use JSON::XS;
use Time::HiRes;
use Data::Compare;

use common;
use Data::Dumper;

sub domains_check {
	my ($self, $list, $epp);
	($self) = @_;

	$list = &dblist(
		'collection'	=> $self->{'app'}->{'domains'},
		'query'		=> { },
		'fields'	=> { }
	);

my $out = {};
my $cnt = 1;
	if (scalar(@{$list})) {
		$epp = &connect_epp();

		foreach (@{$list}) {
			my $resp = $epp->domain_info($_->{'name'});
			$out->{$cnt} = $_->{'exDate'};
			$cnt++;
print "$_->{'name'}\n";

			# check ExpDate for current domain
			if ($resp->{'exDate'} ne $_->{'exDate'}) {
				&dbupdate($self->{'app'}->{'domains'}, { 'name' => $_->{'name'} }, { 'exDate' => $resp->{'exDate'} });

				print "$resp->{'exDate'}\n";
				print "$_->{'exDate'}\n";
				print "\n";
			}

			# check 
			sleep 0.2;
		}
	}

	$self->render( json =>{ 'list' => $out } );
}

sub add_account {
	my ($self, $list, $epp, $new);
	($self) = @_;

	# get last approved raw & change it status to 'changing'
	$list = &dblist(
		'collection'	=> $self->{'app'}->{'queue_contacts'},
		'query'		=> { 'status' => 'new' },
		'fields'	=> { }
	);

	if (scalar(@{$list})) {
		$epp = &connect_epp();

#		$count = $config->{'conf'}->{'iteration'};
		foreach (sort {$a->{'date'} <=> $b->{'date'}} @{$list}) {
			# prepare update request & update via EPP
			$new = $_->{'request'};
			$new->{'id'} = '*-cunic';
			$epp->create_contact($new);
print $Net::EPP::Simple::Contact;
print "\n";
print $_->{'owner'};
print "\n";
			if ($Net::EPP::Simple::Code == 1000) {
				# insert new cunic to database
				&dbupdate($self->{'app'}->{'contacts'}, { 'login' => $_->{'owner'} }, { 'id' => $Net::EPP::Simple::Contact });

				# delete added contact from queue
				&dbremove($self->{'app'}->{'queue_contacts'}, {'date' => $_->{'date'}});
			}
		}
	}
print "add_account\n";
	# Render template with message
	$self->render( json =>{ 'auth' => $list } );
}

sub update_account {
	my ($self, $list, $sceleton, $epp, $count, $new);
	($self) = @_;

	# find & delete all of old and not approved raws
	&dbremove($self->{'app'}->{'queue_contacts'}, { 'date' => { '$gt' => (join('', (Time::HiRes::gettimeofday)) - $config->{'conf'}->{'expires_cookie'}*1000000) }} );

	# get last approved raw & change it status to 'changing'
	$list = &dblist(
		'collection'	=> $self->{'app'}->{'queue_contacts'},
		'query'		=> { 'status' => 'approved' },
		'fields'	=> { }
	);

	# Send create domain request
	if (scalar(@{$list})) {
		$epp = &connect_epp();

		$count = $config->{'conf'}->{'iteration'};
		foreach (sort {$a->{'date'} <=> $b->{'date'}} @{$list}) {
			# prepare update request & update via EPP
			$new = $_->{'request'};
			$new->{'id'} = $_->{'id'};
			$epp->update_contact($new);

print "update_account\n";
			# check success
			if ($Net::EPP::Simple::Code == 1000) {
				# update contact database row
# print Dumper($_->{'request'}->{'chg'});
				&dbupdate($self->{'app'}->{'contacts'}, { 'login' => $_->{'owner'} }, $_->{'request'}->{'chg'});

				# delete request row
				&dbremove($self->{'app'}->{'queue_contacts'}, {'date' => $_->{'date'}});
			}
			else {
				# set error status for current row
			}
# ???????????//
$count = $_->{'id'};
#			$count--;
			last;
		}
	}

	# modify user data in 'contacts' if success EPP request
print "update_account\n";
	# Render template with message
	$self->render( json =>{ 'auth' => $list } );
}

sub error {
	my $self = shift;

	# Render template "user/auth.html.ep" with message
	$self->render( json =>{auth => 0} );
}

1;
