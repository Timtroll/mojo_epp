#!/usr/bin/perl -w

BEGIN { push @INC, '/home/troll/mojo_epp'; }

use strict;
use warnings;
use LWP::Simple;
use MIME::Base64;
use IO::Socket;

use Data::Dumper;
use conf;

my ($content, $resp, $text);

# check Edit accounts
$content = get("$conf{'robot_url'}/add_account");

# send message if error
unless ($content) {
	$resp = &send_mail(
		'server'=> $conf{'smtp_server'},
		'port'	=> $conf{'smtp_port'},
		'login'	=> $conf{'smtp_login'},
		'pass'	=> $conf{'smtp_password'},
		'from'	=> $conf{'robot_mail'},
		'to'	=> $conf{'admin_mail'},
		'subj'	=> $conf{'error_account'},
		'text'	=> $conf{'error_account_not_connect'}
	);

	# print error about sending mail
	if ($resp) {
		print $conf{'error_sending'};
	}
}
print "add_account\n";

exit;
