package Subs;

use Encode qw(encode);
use Time::Local;
use MongoDB;
use MIME::Base64;
use IO::Socket;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(cmp_array cmp_hash obj2utf hash2utf array2utf date2sec sec2date create_rnd send_mail);
@EXPORT_OK = qw(cmp_array cmp_hash obj2utf hash2utf array2utf date2sec sec2date create_rnd send_mail);

sub cmp_obj {
	my ($data, $target, $tmp, $skip, @tmp, %tmp);
	$data = shift; # source
	$target = shift; # target
	$skip = shift; # target

	# Set fields skiped for check
	map { $tmp{$_} = 1 } ( @{$skip} ) if (ref($skip) eq 'ARRAY');

	$tmp = &cmp_hash($data, $target);

	foreach (keys %{$tmp}) {
		# skip non checked fields
		if (exists $tmp{$_}) {
			delete ($$tmp{$_});
		}
	}
	%tmp = ();

	return $tmp;
}


sub cmp_array {
	my ($data, $target, $arrayd, $arrayt, $diff, @diff, %tmp);
	$data = shift;
	$target = shift;

	if (scalar(@{$data}) <= scalar(@{$target})) {
		$arrayt = $target;
		$arrayd = $data;
		$diff = 1;
	}
	else {
		$arrayt = $data;
		$arrayd = $target;
		$diff = -1;
	}
	map { $tmp{$_} = 1; } (@{$arrayd});

	map {
		unless (exists $tmp{$_}) {
			push @diff, $_;
		}
	}  (@{$arrayt});


	if (scalar(@diff)) {
		return $diff, \@diff;
	}
	else {
		return;
	}
}

sub cmp_hash {
	my ($data, $target, $key, $tmp, $diff, %tmp);
	$data = shift;
	$target = shift;

	foreach $key (keys %{$data}) {
		if (exists($$target{$key})) {
			if ((ref($$data{$key}) eq 'HASH') && (ref($$target{$key}) eq 'HASH')) {
				$tmp = &cmp_hash($$data{$key}, $$target{$key});
				if (ref($tmp) eq 'HASH') {
					$tmp{$key} = $tmp;
				}
			}
			elsif ((ref($$data{$key}) eq 'ARRAY') && (ref($$target{$key}) eq 'ARRAY')) {
				($diff, $tmp) = &cmp_array($$data{$key}, $$target{$key});
				if ($diff && $tmp) {
					if (ref($tmp) eq 'ARRAY') {
						$tmp{$key} = $tmp;
					}
				}
			}
			else {
				if (($$data{$key} =~ /\D/) || ($$target{$key} =~ /\D/)) {
					unless ($$data{$key} eq $$target{$key}) {
						$tmp{$key} = $$target{$key};
					}
				}
				else {
					unless ($$data{$key} == $$target{$key}) {
						$tmp{$key} = $$target{$key};
					}
				}
			}
		}
		else {
			$tmp{$key} = $$target{$key};
		}
	}
	if (scalar(keys %tmp)) {
		return \%tmp;
	}
	else {
		return;
	}
}

sub obj2utf {
	my ($obj, $key);
	$obj = shift;

	foreach $key (keys %{$obj}) {
		if (ref($obj->{$key}) eq 'HASH') {
			$obj->{$key} = &hash2utf($obj->{$key});
		}
		elsif (ref($obj->{$key}) eq 'ARRAY') {
			$obj->{$key} = &array2utf($obj->{$key});
		}
		else {
			$obj->{$key} = encode('UTF8', $obj->{$key});
		}
	}

	return $obj;
}

sub hash2utf {
	my ($hach, $key);
	$hach = shift;

	foreach $key (keys %{$hach}) {
		if (ref($hach->{$key}) eq 'HASH') {
			$hach->{$key} = &hash2utf($hach->{$key});
		}
		elsif (ref($hach->{$key}) eq 'ARRAY') {
			$hach->{$key} = &array2utf($hach->{$key});
		}
		else {
			$hach->{$key} = encode('UTF8', $hach->{$key});
		}
	}

	return $hach;
}

sub array2utf {
	my ($arr, @tmp);
	$arr = shift;

	@tmp = @{$arr};
	foreach (@tmp) {
		if (ref($_) eq 'HASH') {
			$_ = &hash2utf($_);
		}
		elsif (ref($_) eq 'ARRAY') {
			$_ = &array2utf($_);
		}
		else {
			$_ = encode('UTF8', $_);
		}
	}

	return \@tmp;
}

###############

sub checkbalance {
	my ($date, $sec);
	$date = shift;

	
}

sub date2sec {
	my ($date, $sec);
	$date = shift;

	$date =~ /(\d{4}?)\-(\d{2}?)\-(\d{2}?).(\d{2}?)\:(\d{2}?)\:(\d{2}?)/;
	$sec = timelocal($6, $5, $4, $3, ($2-1), $1);

	return $sec;
}

sub sec2date {
	my ($sec, $sep, $date, @tmp);
	$sec = shift;
	$sep = shift;

	unless ($sep) { $sep = '/'; }
	@tmp = localtime($sec);
	if ($tmp[0] < 10) { $tmp[0] ='0'.$tmp[0]; }
	if ($tmp[1] < 10) { $tmp[1] ='0'.$tmp[1]; }
	if ($tmp[2] < 10) { $tmp[2] ='0'.$tmp[2]; }
	if ($tmp[3] < 10) { $tmp[3] ='0'.$tmp[3]; }
	$tmp[4] = ($tmp[4]+1);
	if ($tmp[4] < 10) { $tmp[4] ='0'.$tmp[4]; }

	# 1101 (month+day)
	if ($sep eq 'md') {
		$tmp[4] =~ s/^0//;
		$date = $tmp[4].$tmp[3];
	}
	# 2011-12-06T08:53:24.0948Z
	elsif ($sep eq 'iso') {
		$date = ($tmp[5]+1900)."-$tmp[4]-$tmp[3]T$tmp[2]:$tmp[1]:$tmp[0].0000Z";
	}
	# 2001-12-01 (yy-mm-dd where '-' is separeator)
	elsif ($sep eq 'date') {
		$date = ($tmp[5]+1900)."-".$tmp[4]."-".$tmp[3];
	}
	# 01-02-2001 (dd-mm-yy where '-' is separeator)
	else {
		$date = $tmp[3].$sep.$tmp[4].$sep.($tmp[5]+1900);
	}
	@tmp = ();

	return $date;
}

sub create_rnd {
	my ($amount, $out, @chars);
	$amount = shift;

	$amount--;
	srand();
	@chars = split('', 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz');
	$out = join("", @chars[ map{ rand @chars } (0 .. ($amount-6)) ]);
	@chars = split('', '*_-@[]|');
	$out .= join("", @chars[ map{ rand @chars } (0 .. 1) ]);
	@chars = split('', [0 .. 9]);
	$out .= join("", @chars[ map{ rand @chars } (0 .. 1) ]);
	@chars = split('', map{ rand @chars } (0 .. $#chars));
	$out .= join("", @chars[ map{ rand @chars } (0 .. $#chars) ]);

	return $out;
}

sub send_mail {
	my ($socket, $boundary, $repl, $date, @tmp, @date, @dayofweek, @monthnames, %hach, %error);
	%hach = @_;

	# create boundary
	@tmp = ('A'..'Z', 'a'..'z', '0'..'9', '_');
	for (1..32) { $boundary .= $tmp[rand(@tmp)]; }
	$socket = IO::Socket::INET->new("$hach{'server'}:$hach{'port'}");

	$repl = &read_reply(\$socket);
	if ($repl != 220) { print "===$repl===\n"; $socket->close(); return $repl; }

	$socket->print ("ehlo lo\n");
	$repl = &read_reply(\$socket);
	if ($repl != 250) { print "===$repl===\n"; $socket->close(); return $repl; }

	$socket->print("AUTH LOGIN\n");
	$repl = &read_reply(\$socket);
	if ($repl != 334) { print "===$repl===\n"; $socket->close(); return $repl; }

	$body = encode_base64($hach{'login'}).encode_base64($hach{'pass'});
	$socket->print($body);
	$repl = &read_reply(\$socket);

	$repl = &read_reply(\$socket);
	if ($repl != 235) { print "===$repl===\n"; $socket->close(); return $repl; }

	$socket->print("mail from: Robot <$hach{'from'}>\n");
	$repl = &read_reply(\$socket);
	if ($repl != 250) { print "===$repl===\n"; $socket->close(); return $repl; }

	$socket->print("rcpt to: $hach{'to'}\n");
	$repl = &read_reply(\$socket);
	if ($repl != 250) { print "===$repl===\n"; $socket->close(); return $repl; }

	$socket->print("data\n");
	$repl = &read_reply(\$socket);
	if ($repl != 354) { print "===$repl===\n"; $socket->close(); return $repl; }

	# Create an RFC compliant time stamp
	@dayofweek = (qw(Sun Mon Tue Wed Thur Fri Sat));
	@monthnames = (qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)); 
	@date = localtime();
	$date = sprintf("%s, %02d %3s %04d %02d:%02d:%02d CST", $dayofweek[$date[6]], $date[3], $monthnames[$date[4]], ($date[5] + 1900), $date[2], $date[1], $date[0]);

	$hach{'subj'} = encode_base64($hach{'subj'});
	$hach{'subj'} =~ s/\n//ig;
	$hach{'subj'} =~ s/\r//ig;
	$hach{'subj'} = '=?Windows-1251?B?'.$hach{'subj'}.'?=';

	$hach{'text'} = encode_base64(encode("UTF-8", $hach{'text'}));
	$boundary = "Mime-Version: 1.0\nContent-Type:text/html;\n boundary=\"$boundary\"\nContent-Transfer-Encoding: base64\n".$hach{'text'};

	$hach{'text'} = "From:$hach{'from'}\n";
#	$hach{'text'} .= "X-Mailer: The Bat! (v2.00.6) Personal\n";
	$hach{'text'} .= "Reply-To:$hach{'to'}\n";
	$hach{'text'} .= "Date: $date\n";
#	$hach{'text'} .= "Organization: Robot\nX-Priority: 3 (Normal)\n";
	$hach{'text'} .= "Message-ID: 1\n";
	$hach{'text'} .= "To:$hach{'to'}\n";
	$hach{'text'} .= "Subject:$hach{'subj'}\n";
	$hach{'text'} .= "$boundary\n.\n";

	$socket->print($hach{'text'});
	$repl = &read_reply(\$socket);
	if ($repl != 250) { $socket->close(); print "===$repl===\n"; return $repl; }

	$socket->close();

	return %error;
}

sub read_reply {
	my ($val, $r, $tmp, $reply, $message, $sock);
	$sock = shift;

        $tmp = $$sock;
        $val = 1;
        while($val eq 1){
                $r = <$tmp>;
                $val = $r =~ m/^\d{3}-/g;
        }
        ($reply, $message) = split(/ /,$r,2);
        return $reply;
}

1;