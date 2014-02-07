#use strict;
#use Mojo::Base -strict;
use Mojo::Base;
use Test::More;
use Test::Mojo;

#plan 'no_plan';

BEGIN { 
	unshift (@INC,"/home/troll/epp/epp_client/lib");
}

use_ok 'EppClient';

my $t = Test::Mojo->new('EppClient');

# test /
&test_start();

# test /login
&test_login();
exit;
# test /singup
&test_singup();

done_testing();

### test subs ###

sub test_start {
	$t->get_ok('/');
	$t->status_is(200);
	$t->content_type_is('text/html;charset=UTF-8');
	$t->content_like(qr#Singup now#i);
}

sub test_login {
	my ($data);

	$data =  {
#		'username'	=> &create_rnd(5, 'symb'),
#		'password'	=> &create_rnd(5, 'symb')
		'username'	=> 'asde',
		'password'	=> 'asd'
	};
#	$t->post_ok('/login' => form => $data )->status_is(200);
	$t->post_ok('/login', $data) -> status_is(200) -> content_like(qr#Singup now#i);
#	$t-> post_ok('/login' => {DNT => 1} => form => $data );
#	$t -> status_is(200);
#	$t -> content_like(qr#Singup now#i);

#	$data->{'password'} = $data->{'username'} = &create_rnd(9, 'symb');
	$data =  {
		# 'username'	=> $temp,
		# 'password'	=> $temp
		'username'	=> 'asd',
		'password'	=> 'asd'
	};
	$t->post_ok('/login' => form => $data )->status_is(200);
#	$t-> post_ok('/login' => {DNT => 1} => form => $data );
	$t -> status_is(200);
	$t -> content_is(1);
#	$t->post_ok('/login', $data, qr#Singup now#i);
	$t->content_type_is('text/html;charset=UTF-8');
}

sub test_singup {
	$t->get_ok('/singup');
	$t->status_is(200);
	$t->content_type_is('text/html;charset=UTF-8');
#	$t->content_like(qr#Singup now#i);
}

### Sysyems subs

sub create_rnd {
	my ($amount, $out, $type, @chars);
	$amount = shift;
	$type = shift;

	unless ($amount) { $amount = 1; }
	unless ($type) {
		@chars = (
			"А" .. "Z", "а" .. "z", 0 .. 9, '%', '!', '', '@', '$', '%', '^', '&', '*', "\"", "'", '~', '+', '=', '-', '_', '<', '>', ',', '.', '\`', '/', "\\", "\|", "\[", "\]", "\{", "\}", ';', ':', '#', '(', ')' 
		);
	}
	elsif ($type eq 'symb') {
		@chars = ("А" .. "Z", "а" .. "z");
	}
	elsif ($type eq 'digit') {
		@chars = (0 .. 9);
	}
	else {
		@chars = (
			"А" .. "Z", "а" .. "z", 0 .. 9, '%', '!', '', '@', '$', '%', '^', '&', '*', "\"", "'", '~', '+', '=', '-', '_', '<', '>', ',', '.', '\`', '/', "\\", "\|", "\[", "\]", "\{", "\}", ';', ':', '#', '(', ')' 
		);
	}

	$out = join("", @chars[ map{ rand @chars }(1 .. $amount) ]);

	return $out;
}