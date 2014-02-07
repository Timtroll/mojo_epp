use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

BEGIN { 
	unshift (@INC,"/home/troll/epp/epp_client/lib");
#	`cd /home/troll/betterknow/betterknow/script`;
}

use_ok 'EppClient';
#use EppClient;

my $t = Test::Mojo->new('EppClient');
$t->get_ok('/')->status_is(200)->content_like(qr/Singup/i);

done_testing();
