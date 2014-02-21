package conf;

BEGIN { push @INC, '/home/troll/mojo_epp'; }

use strict;
use warnings;
use IO::Socket;
use Encode qw(encode);
use MIME::Base64;
use utf8;

use Exporter();
use vars qw( @ISA @EXPORT @EXPORT_OK );

@ISA = qw( Exporter );
@EXPORT = qw( &send_mail %conf );
@EXPORT_OK = qw( );

use vars qw( %conf );

%conf = (
	'robot_url'	=> 'http://127.0.0.1:6000',
	'smtp_server'	=> '217.20.175.186',
	'smtp_port'	=> 587,
	'smtp_login'	=> 'robot@milion.kiev.ua',
	'smtp_password'	=> '3Mlo8CW9',
	'robot_mail'	=> 'robot@milion.kiev.ua',
	'admin_mail'	=> 'troll@spam.net.ua',

	'error_account'			=> 'Ошибка CRON при обработке аккаунтов',
	'error_account_not_connect'	=> 'Пустой ответ сервиса ROBOT',
	'error_sending'			=> 'Ошибка при отправке email. Сервис account_cron'
);

sub send_mail {
	my ($socket, $boundary, $repl, $date, $body, @tmp, @date, @dayofweek, @monthnames, %hach, %error);
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

	$hach{'subj'} = encode_base64(encode("UTF-8", $hach{'subj'}));
	$hach{'subj'} =~ s/\n//ig;
	$hach{'subj'} =~ s/\r//ig;
	$hach{'subj'} = '=?UTF-8?B?'.$hach{'subj'}.'?=';

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