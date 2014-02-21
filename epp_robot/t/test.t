use LWP::UserAgent;
use Test::More;
use Data::Dumper;
use MongoDB;

my $url = 'http://localhost:5000';
my $ua = LWP::UserAgent->new;

my $conn = &connect();
foreach (1..100) {
	# $ua->header('content-type' => 'application/x-www-form-urlencoded');
	$got = &login('troll','');
	ok($got eq '{"auth":0,"cunic":0,"type":0}', "Test 1 $got");
	$got = &login('','troll');
	ok($got eq '{"auth":0,"cunic":0,"type":0}', "Test 2 $got");
	$got = &login('qwe','qwe');
	ok($got eq '{"auth":0,"cunic":0,"type":0}', "Test 3 $got");
	$got = &login('troll','troll');
	ok($got eq '{"auth":1,"cunic":"trol-cunic","type":"admin"}', "Test 4 $got");
	$got = &reload();
	ok($got eq '{"rel":0}', "Test 5 $got");
	#exit;

	&create_user('test', 'test');
	$got = &reload();
	ok($got eq '{"rel":1}', "Test 6 $got");

	$got = &login('user','');
	ok($got eq '{"auth":0,"cunic":0,"type":0}', "Test 7 $got");
	$got = &login('','user');
	ok($got eq '{"auth":0,"cunic":0,"type":0}', "Test 8 $got");
	$got = &login('troll','troll');
	ok($got eq '{"auth":1,"cunic":"trol-cunic","type":"admin"}', "Test 9 $got");
	$got = &login('test','test');
	ok($got eq '{"auth":1,"cunic":"test","type":"user"}', "Test 10 $got");

	$got = &reload();
	ok($got eq '{"rel":0}', "Test 11 $got");
	&remove_test('test');
	$got = &reload();
	$got = '';
	sleep(0.5);
}
exit;

sub remove_test {
	my ($client, $db, $collections);

	# $client = MongoDB::Connection->new(
		# host		=> 'mongodb://localhost,licalhost;27017',
		# query_timeout	=> 1000,
		# username	=> 'troll',
		# password	=> 'yfenbkec'
	# );
	# $db = $client->get_database( 'domains' );
	# $collections = $db->get_collection( 'user_list' );

	$conn->remove( { 'login' => 'test'} );
}

sub create_user {
	my ($login, $pass, $client, $db, $collections);
	$login = shift;
	$pass = shift;

	# $client = MongoDB::Connection->new(
		# host		=> 'mongodb://localhost,licalhost;27017',
		# query_timeout	=> 1000,
		# username	=> 'troll',
		# password	=> 'yfenbkec'
	# );
	# $db = $client->get_database( 'domains' );
	# $collections = $db->get_collection( 'user_list' );

	$conn->insert( { 'login' => $login, 'pass' => $pass , 'id' => $login, 'usertype' => 'user' } );
}

sub login {
	my ($login, $pass, $out);
	$login = shift;
	$pass = shift;

	# add POST data to HTTP request body
	my $resp = $ua->post($url, { 'user' => $login, 'pass' => $pass});

	# my $resp = $ua->request($req);
	if ($resp->is_success) {
	#	print Dumper($resp);
		print $resp->content;
		print "\n";
		$out = $resp->content;
		$resp = '';
		return $out;
	}
	else {
		print "HTTP POST error code: ", $resp->code, "\n";
		print "HTTP POST error message: ", $resp->message, "\n";
		$resp = '';
		return 0;
	}
}

sub reload {
	my ($resp);

	# add POST data to HTTP request body
	$resp = $ua->get($url."/rel");

	# my $resp = $ua->request($req);
	if ($resp->is_success) {
	#	print Dumper($resp);
		print $resp->content;
		print "\n";
		$out = $resp->content;
		$resp = '';
		return $out;
	}
	else {
		print "HTTP POST error code: ", $resp->code, "\n";
		print "HTTP POST error message: ", $resp->message, "\n";
		$resp = '';
		return 0;
	}
}

sub connect {
	my ($client, $db, $collections);

	$client = MongoDB::Connection->new(
		host		=> 'mongodb://localhost,licalhost;27017',
		query_timeout	=> 1000,
		username	=> 'troll',
		password	=> 'yfenbkec'
	);
	$db = $client->get_database( 'domains' );
	$collections = $db->get_collection( 'user_list' );

	return $collections;
}