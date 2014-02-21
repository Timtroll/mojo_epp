package common;

use Data::Dumper;

use MongoDB::Connection;
use MongoDB;
use MongoDB::OID;
use Net::EPP::Simple;
use JSON::XS;
use Encode qw(encode decode);
use utf8;

use Mojo::Home;
use Exporter();
use vars qw( @ISA @EXPORT @EXPORT_OK );

@ISA = qw( Exporter );
@EXPORT = qw( &rel_file &dbconn &popular &connect_epp &users_list &users_mail &update_user &dbremove &domains_list &create_rnd &domain_info &dblist &dbinsert &dbupdate &whois_exists &check_whois &format_phone &create_rnd &get_cart $config &load_domains_price &get_real_balance );

use vars qw( $config );

# Find and manage the project root directory
my $home = Mojo::Home->new;
$home->detect;

sub rel_file { $home->rel_file(shift); }

#### Database subs ####

sub dbconn {
	my ($client, $db, $collections, $database, $col);
	$database = shift;
	$col = shift;

	$client = MongoDB::Connection->new(
		host		=> $config->{'conf'}->{'mongohost'},
		query_timeout	=> 1000,
		#auto_reconnect	=> true,
		username	=> $config->{'conf'}->{'mongouser'},
		password	=> $config->{'conf'}->{'mongopass'}
	);

	$db = $client->get_database( $database );
	$collections = $db->get_collection( $col );

	return $collections;
}

sub popular {
	my ($collection, @list, %out);
	$collection = shift;

	@list = $collection->find( {}, { 'name' => 1 } )->all;

	map { $_->{name} =~ s/^.*?\.//; $out{$_->{name}}++; } (@list);

	return \%out;
}

sub domains_list {
	my ($collection, $user, @list);
	$collection = shift;
	$user = shift;

	# print "$user\n";
	@list = $collection->find( { 'contacts.admin' => $user }, { 'name' => 1, 'exDate' => 1, 'expires' => 1 } )->all;
	# use Data::Dumper;
	# print Dumper(\@list);
	return \@list;
}

sub dblist {
	my (@list, %hach);
	%hach = @_;

	if ($hach{'fields'}) {
		@list = $hach{'collection'}->find( $hach{'query'}, $hach{'fields'} )->all;
	}
	else {
		@list = $hach{'collection'}->find( $hach{'query'} )->all;
	}

	return \@list;
}

sub dbinsert {
	my ($collection, $query);
	$collection = shift;
	$query = shift;

	$collection->insert( $query );

	return;
}

sub dbupdate {
	my ($collection, $find, $query);
	$collection = shift;
	$find = shift;
	$query = shift;

	$collection->update( $find, { '$set' => $query } );

	return;
}

sub dbremove {
	my ($collection, $query);
	$collection = shift;
	$query = shift;

	print $collection->remove( $query );
print "\n";

	return;
}

sub users_list {
	my ($collection, $find,  @list, %out);
	$collection = shift;
	$find = shift;

	@list = $collection->find( {}, { $find => 1, 'usertype' => 1 } )->all;

	map { $out{$_->{$find}} = $_->{usertype}; } (@list);

	return \%out;
}

sub users_mail {
	my ($collection, @list, %out);
	$collection = shift;

	@list = $collection->find( {}, { 'email' => 1, 'usertype' => 1 } )->all;

	map { $out{$_->{'email'}} = $_->{usertype}; } (@list);

	return \%out;
}

sub update_user {
	my ($collection, $find, $data, @list, %out);
	$collection = shift;
	$find = shift;
	$data = shift;

	@list = $collection->update( $find, { '$set' => $data } );

	map { $out{$_->{'email'}} = $_->{'pass'}; } (@list);

	return \%out;
}

sub domain_info {
	my ($collection, $name, @list);
	$collection = shift;
	$name = shift;

	# print "$user\n";
	@list = $collection->find( { 'name' => $name } )->all;
	use Data::Dumper;
	print Dumper(\@list);
	return \@list;
}

sub get_real_balance {
	my ($self, $balance, $hold, $list, $find, $query);
	($self) = shift;
	$login = shift;

	# read paiment database
	$list = &dblist(
		'collection'	=> $self->{'app'}->{'history'},
		'query'		=> { 'owner' => $login }
	);

	# calculate balance
	foreach (@{$list}) {
		if ($_->{'type'} eq 'credit') {
			if ($_->{'status'} eq 'paid') {
				$balance = $balance + $_->{'summ'};
			}
		}
		else {
			$balance = $balance - $_->{'summ'};
			$hold = $hold + $_->{'summ'};
		}
	}

	# correct balance if need & send error message to admin
	# ???????
	if (($self->session->{'balance'} != $balance)||($self->session->{'hold'} != $hold)) {
		$self->session->{'balance'} = $balance;
		$self->session->{'hold'} = $hold;
	}

	# update balance base
	$find = { 'login' => $login};
	$query = {
		'hold'		=> $hold,
		'balance'	=> $balance
	};
	&dbupdate($self->{'app'}->{'balance'}, $find, $query);

	return;
}


######################

sub connect_epp {
	my ($epp, %answer);

	# Connect to Epp server
	$epp = Net::EPP::Simple->new(
		host	=> $config->{'conf'}->{'epp_host'},
		user	=> $config->{'conf'}->{'epp_user'},
		timeout	=> $config->{'conf'}->{'epp_timeout'},
		pass	=> $config->{'conf'}->{'epp_pass'},
		debug	=> $config->{'conf'}->{'debug_epp'}
	);

	if (($Net::EPP::Simple::Code == 2500)||($Net::EPP::Simple::Code == 2501)||($Net::EPP::Simple::Code == 2502)) {
		%answer = (
		'title'		=> $config->{'conf'}->{'epp_connection_error'},
		'path'		=> '/ '.$config->{'conf'}->{'epp_connection_error'}.' : Code '.$Net::EPP::Simple::Code,
		'messages'	=> $Net::EPP::Simple::Message."<br>".$Net::EPP::Simple::Error
		);
	}

	return $epp, \%answer;
}

sub error {
	my $self = shift;

	$self->res->code(301);
	$self->redirect_to('/500.html');
	return;
}

sub load_domains_price {
	my ($self, $zones, $discont);
	$connection = shift;
	$discont = shift;

	$zones = &dblist(
		'collection'	=> $connection,
		'query'		=> {}
	);
	map {
		$config->{'domains_price'}->{$_->{'zone'}} = $_->{'price'}[$discont];
	} (@{$zones});

	return;
}

sub whois_exists {
	my ($result, $domain, $zone, %whois);
	$domain = shift;

	%whois = (
'RU' => 'whois.ripn.net',
'SU' => 'whois.ripn.net',
'XN--P1AI' => 'whois.ripn.net',

'COM.RU' => 'whois.nic.ru',
'NET.RU' => 'whois.nic.ru',
'ORG.RU' => 'whois.nic.ru',
'PP.RU' => 'whois.nic.ru',
'RU.NET' => 'whois.nic.ru',
'INT.RU' => 'whois.int.ru',

'ABKHAZIA.SU' => 'whois.nic.ru',
'ADYGEYA.RU' => 'whois.nic.ru',
'ADYGEYA.SU' => 'whois.nic.ru',
'AKTYUBINSK.SU' => 'whois.nic.ru',
'AMURSK.RU' => 'whois.nic.ru',
'ARKHANGELSK.SU' => 'whois.nic.ru',
'ARMENIA.SU' => 'whois.nic.ru',
'ASHGABAD.SU'=> 'whois.nic.ru',
'AZERBAIJAN.SU' => 'whois.nic.ru',
'BALASHOV.SU' => 'whois.nic.ru',
'BASHKIRIA.RU' => 'whois.nic.ru',
'BASHKIRIA.SU' => 'whois.nic.ru',
'BELGOROD.RU' => 'whois.nic.ru',
'BELGOROD.SU' => 'whois.nic.ru',
'BIR.RU' => 'whois.nic.ru',
'BRYANSK.SU' => 'whois.nic.ru',
'BUKHARA.SU' => 'whois.nic.ru',
'CBG.RU' => 'whois.nic.ru',
'CHELYABINSK.RU' => 'whois.nic.ru',
'CHIMKENT.SU' => 'whois.nic.ru',
'CMW.RU' => 'whois.nic.ru',
'DAGESTAN.RU' => 'whois.nic.ru',
'DAGESTAN.SU' => 'whois.nic.ru',
'DUDINKA.RU' => 'whois.nic.ru',
'EAST-KAZAKHSTAN.SU' => 'whois.nic.ru',
'EXNET.SU' => 'whois.nic.ru',
'FAREAST.RU' => 'whois.nic.ru',
'GEORGIA.SU' => 'whois.nic.ru',
'GROZNY.RU' => 'whois.nic.ru',
'GROZNY.SU' => 'whois.nic.ru',
'IVANOVO.SU' => 'whois.nic.ru',
'JAMBYL.SU' => 'whois.nic.ru',
'JAR.RU' => 'whois.nic.ru',
'JOSHKAR-OLA.RU' => 'whois.nic.ru',
'KALMYKIA.RU' => 'whois.nic.ru',
'KALMYKIA.SU' => 'whois.nic.ru',
'KALUGA.SU' => 'whois.nic.ru',
'KARACOL.SU' => 'whois.nic.ru',
'KARAGANDA.SU' => 'whois.nic.ru',
'KARELIA.SU' => 'whois.nic.ru',
'KCHR.RU' => 'whois.nic.ru',
'KHAKASSIA.SU' => 'whois.nic.ru',
'KOMI.SU' => 'whois.nic.ru',
'KRASNODAR.SU' => 'whois.nic.ru',
'KURGAN.SU' => 'whois.nic.ru',
'KUSTANAI.RU' => 'whois.nic.ru',
'KUSTANAI.SU' => 'whois.nic.ru',
'MANGYSHLAK.SU' => 'whois.nic.ru',
'MARINE.RU' => 'whois.nic.ru',
'MORDOVIA.RU' => 'whois.nic.ru',
'MORDOVIA.SU' => 'whois.nic.ru',
'MSK.RU' => 'whois.nic.ru',
'MSK.SU' => 'whois.nic.ru',
'MURMANSK.SU' => 'whois.nic.ru',
'MYTIS.RU' => 'whois.nic.ru',
'NALCHIK.RU' => 'whois.nic.ru',
'NALCHIK.SU' => 'whois.nic.ru',
'NAVOI.SU' => 'whois.nic.ru',
'NNOV.RU' => 'whois.nnov.ru',
'NORILSK.RU' => 'whois.nic.ru',
'NORTH-KAZAKHSTAN.SU' => 'whois.nic.ru',
'NOV.RU' => 'whois.nic.ru',
'NOV.SU' => 'whois.nic.ru',
'OBNINSK.SU' => 'whois.nic.ru',
'PALANA.RU' => 'whois.nic.ru',
'PENZA.SU' => 'whois.nic.ru',
'POKROVSK.SU' => 'whois.nic.ru',
'PYATIGORSK.RU' => 'whois.nic.ru',
'RU.NET' => 'whois.nic.ru',
'SIMBIRSK.RU' => 'whois.nic.ru',
'SOCHI.SU' => 'whois.nic.ru',
'SPB.RU' => 'whois.nic.ru',
'SPB.SU' => 'whois.nic.ru',
'TASHKENT.SU' => 'whois.nic.ru',
'TERMEZ.SU' => 'whois.nic.ru',
'TOGLIATTI.SU' => 'whois.nic.ru',
'TROITSK.SU' => 'whois.nic.ru',
'TSARITSYN.RU' => 'whois.nic.ru',
'TSELINOGRAD.SU' => 'whois.nic.ru',
'TULA.SU' => 'whois.nic.ru',
'TUVA.SU' => 'whois.nic.ru',
'VLADIKAVKAZ.RU' => 'whois.nic.ru',
'VLADIKAVKAZ.SU' => 'whois.nic.ru',
'VLADIMIR.RU' => 'whois.nic.ru',
'VLADIMIR.SU' => 'whois.nic.ru',
'VOLOGDA.SU' => 'whois.nic.ru',
'YAKUTIA.SU' => 'whois.nic.ru',
'YEKATERINBURG.RU' => 'whois.nic.ru',

'AERO' => 'whois.aero',
'ARPA' => 'whois.iana.org',
'ASIA' => 'whois.nic.asia',
'BIZ' => 'whois.biz',
'CAT' => 'whois.cat',
'CC' => 'ccwhois.verisign-grs.com',

'COM' => 'whois.tucows.com',
# 'COM' => 'whois.PublicDomainRegistry.com',
# 'COM' => 'whois.crsnic.net',

'COOP' => 'whois.nic.coop',
'EDU' => 'whois.educause.edu',
'GOV' => 'whois.dotgov.gov',
'INFO' => 'whois.afilias.net',
'INT' => 'whois.iana.org',
'JOBS' => 'jobswhois.verisign-grs.com',
'MIL' => 'whois.nic.mil',
'MOBI' => 'whois.dotmobiregistry.net',
'MUSEUM' => 'whois.museum',
'NAME' => 'whois.nic.name',
'NET' => 'whois.crsnic.net',
'ORG' => 'whois.pir.org',
'PRO' => 'whois.registrypro.pro',
'TEL' => 'whois-tel.neustar.biz',
'TRAVEL' => 'whois.nic.travel',

'TV' => 'whois.nic.tv',
'WS' => 'whois.markmonitor.com',
'NF' => 'whois.nic.cx',
'AC' => 'whois.nic.ac',
'AG' => 'whois.nic.ag',
'AM' => 'whois.amnic.net',
'AS' => 'whois.nic.as',
'AT' => 'whois.nic.at',
'AU' => 'whois.aunic.net',
'BE' => 'whois.dns.be',
'BG' => 'whois.register.bg',
'BJ' => 'whois.nic.bj',
'BR' => 'whois.registro.br',
'BY' => 'whois.cctld.by',
'CA' => 'whois.cira.ca',
'CD' => 'whois.nic.cd',
'CH' => 'whois.nic.ch',
'CI' => 'whois.nic.ci',
'CL' => 'whois.nic.cl',
'CM' => 'whois.netcom.cm',
'CN' => 'whois.cnnic.net.cn',
'CO' => 'whois.nic.co',
'CX' => 'whois.nic.cx',
'CZ' => 'whois.nic.cz',
'DE' => 'whois.denic.de',
'DK' => 'whois.dk-hostmaster.dk',
'DM' => 'whois.nic.dm',
'EE' => 'whois.eenet.ee',
'EU' => 'whois.eu',
'FI' => 'whois.ficora.fi',
'FM' => 'whois.nic.fm',
'FO' => 'whois.ripe.net',
'FR' => 'whois.nic.fr',
'GD' => 'whois.adamsnames.tc',
'GG' => 'whois.channelisles.net',
'GI' => 'whois2.afilias-grs.net',
'GS' => 'whois.nic.gs',
'GY' => 'whois.registry.gy',
'HU' => 'whois.nic.hu',
'HK' => 'whois.hkirc.hk',
'HM' => 'whois.registry.hm',
'HN' => 'whois2.afilias-grs.net',
'HT' => 'whois.nic.ht',
'IE' => 'whois.domainregistry.ie',
'IL' => 'whois.isoc.org.il',
'IM' => 'whois.nic.im',
'IN' => 'whois.inregistry.net',
'IO' => 'whois.nic.io',
'IR' => 'whois.nic.ir',
'IS' => 'whois.isnic.is',
'IT' => 'whois.nic.it',
'JE' => 'whois.channelisles.net',
'JP' => 'whois.jprs.jp',
'KE' => 'whois.kenic.or.ke',
'KG' => 'whois.domain.kg',
'KI' => 'whois.nic.ki',
'KR' => 'whois.nic.or.kr',
'KZ' => 'whois.nic.kz',
'LA' => 'whois.nic.la',
'LC' => 'whois2.afilias-grs.net',
'LI' => 'whois.nic.li',
'LT' => 'whois.domreg.lt',
'LU' => 'whois.dns.lu',
'LV' => 'whois.nic.lv',
'LY' => 'whois.nic.ly',
'MA' => 'whois.iam.net.ma',
'MC' => 'whois.ripe.net',
'MD' => 'whois.nic.md',
'ME' => 'whois.nic.me',
'MG' => 'whois.nic.mg',
'MN' => 'whois2.afilias-grs.net',
'MS' => 'whois.nic.ms',
'MU' => 'whois.nic.mu',
'MX' => 'whois.nic.mx',
'MY' => 'whois.mynic.net.my',
'NA' => 'whois.na-nic.com.na',
'NL' => 'whois.domain-registry.nl',
'NO' => 'whois.norid.no',
'NU' => 'whois.nic.nu',
'NZ' => 'whois.srs.net.nz',
'PL' => 'whois.dns.pl',
'PM' => 'whois.nic.pm',
'PR' => 'whois.nic.pr',
'PT' => 'whois.dns.pt',
'PW' => 'whois.centralnic.net',
'RE' => 'whois.nic.re',
'RO' => 'whois.rotld.ro',
'RS' => 'whois.rnids.rs',
'SA' => 'whois.saudinic.net.sa',
'SB' => 'whois.nic.sb',
'SC' => 'whois2.afilias-grs.net',
'SE' => 'whois.iis.se',
'SG' => 'whois.nic.net.sg',
'SH' => 'whois.nic.sh',
'SI' => 'whois.arnes.si',
'SK' => 'whois.sk-nic.sk',
'SM' => 'whois.ripe.net',
'ST' => 'whois.nic.st',
'TC' => 'whois.adamsnames.tc',
'TF' => 'whois.nic.tf',
'TH' => 'whois.nic.uk',
'TK' => 'whois.dot.tk',
'TL' => 'whois.nic.tl',
'TM' => 'whois.nic.tm',
'TO' => 'whois.tonic.to,',
'TR' => 'whois.nic.tr',
'TW' => 'whois.twnic.net.tw',
'UA' => 'whois.com.ua',
'NET.UA' => 'whois.net.ua',
'UK' => 'whois.nic.uk',
'US' => 'whois.nic.us',
'UZ' => 'whois.cctld.uz',
'VC' => 'whois2.afilias-grs.net',
'VE' => 'whois.nic.ve',
'VG' => 'whois.adamsnames.tc',
'WF' => 'whois.nic.wf',
'YT' => 'whois.nic.yt',

'ASN.AU' => 'whois.aunic.net',
'COM.AU' => 'whois.aunic.net',
'CONF.AU' => 'whois.aunic.net',
'CSIRO.AU' => 'whois.aunic.net',
'EDU.AU' => 'whois.aunic.net',
'GOV.AU' => 'whois.aunic.net',
'ID.AU' => 'whois.aunic.net',
'INFO.AU' => 'whois.aunic.net',
'NET.AU' => 'whois.aunic.net',
'ORG.AU' => 'whois.aunic.net',
'EMU.ID.AU' => 'whois.aunic.net',
'WATTLE.ID.AU' => 'whois.aunic.net',

'ADM.BR' => 'whois.nic.br',
'ADV.BR' => 'whois.nic.br',
'AGR.BR' => 'whois.nic.br',
'AM.BR' => 'whois.nic.br',
'ARQ.BR' => 'whois.nic.br',
'ART.BR' => 'whois.nic.br',
'ATO.BR' => 'whois.nic.br',
'BIO.BR' => 'whois.nic.br',
'BMD.BR' => 'whois.nic.br',
'CIM.BR' => 'whois.nic.br',
'CNG.BR' => 'whois.nic.br',
'CNT.BR' => 'whois.nic.br',
'COM.BR' => 'whois.nic.br',
'ECN.BR' => 'whois.nic.br',
'EDU.BR' => 'whois.nic.br',
'ENG.BR' => 'whois.nic.br',
'ESP.BR' => 'whois.nic.br',
'ETC.BR' => 'whois.nic.br',
'ETI.BR' => 'whois.nic.br',
'FAR.BR' => 'whois.nic.br',
'FM.BR' => 'whois.nic.br',
'FND.BR' => 'whois.nic.br',
'FOT.BR' => 'whois.nic.br',
'FST.BR' => 'whois.nic.br',
'G12.BR' => 'whois.nic.br',
'GGF.BR' => 'whois.nic.br',
'GOV.BR' => 'whois.nic.br',
'IMB.BR' => 'whois.nic.br',
'IND.BR' => 'whois.nic.br',
'INF.BR' => 'whois.nic.br',
'JOR.BR' => 'whois.nic.br',
'LEL.BR' => 'whois.nic.br',
'MAT.BR' => 'whois.nic.br',
'MED.BR' => 'whois.nic.br',
'MIL.BR' => 'whois.nic.br',
'MUS.BR' => 'whois.nic.br',
'NET.BR' => 'whois.nic.br',
'NOM.BR' => 'whois.nic.br',
'NOT.BR' => 'whois.nic.br',
'NTR.BR' => 'whois.nic.br',
'ODO.BR' => 'whois.nic.br',
'OOP.BR' => 'whois.nic.br',
'ORG.BR' => 'whois.nic.br',
'PPG.BR' => 'whois.nic.br',
'PRO.BR' => 'whois.nic.br',
'PSC.BR' => 'whois.nic.br',
'PSI.BR' => 'whois.nic.br',
'QSL.BR' => 'whois.nic.br',
'REC.BR' => 'whois.nic.br',
'SLG.BR' => 'whois.nic.br',
'SRV.BR' => 'whois.nic.br',
'TMP.BR' => 'whois.nic.br',
'TRD.BR' => 'whois.nic.br',
'TUR.BR' => 'whois.nic.br',
'TV.BR' => 'whois.nic.br',
'VET.BR' => 'whois.nic.br',
'ZLG.BR' => 'whois.nic.br',

'AC.CN' => 'whois.cnnic.net.cn',
'AH.CN' => 'whois.cnnic.net.cn',
'BJ.CN' => 'whois.cnnic.net.cn',
'COM.CN' => 'whois.cnnic.net.cn',
'CQ.CN' => 'whois.cnnic.net.cn',
'FJ.CN' => 'whois.cnnic.net.cn',
'GD.CN' => 'whois.cnnic.net.cn',
'GOV.CN' => 'whois.cnnic.net.cn',
'GS.CN' => 'whois.cnnic.net.cn',
'GX.CN' => 'whois.cnnic.net.cn',
'GZ.CN' => 'whois.cnnic.net.cn',
'HA.CN' => 'whois.cnnic.net.cn',
'HB.CN' => 'whois.cnnic.net.cn',
'HE.CN' => 'whois.cnnic.net.cn',
'HI.CN' => 'whois.cnnic.net.cn',
'HK.CN' => 'whois.cnnic.net.cn',
'HL.CN' => 'whois.cnnic.net.cn',
'HN.CN' => 'whois.cnnic.net.cn',
'JL.CN' => 'whois.cnnic.net.cn',
'JS.CN' => 'whois.cnnic.net.cn',
'JX.CN' => 'whois.cnnic.net.cn',
'LN.CN' => 'whois.cnnic.net.cn',
'MO.CN' => 'whois.cnnic.net.cn',
'NET.CN' => 'whois.cnnic.net.cn',
'NM.CN' => 'whois.cnnic.net.cn',
'NX.CN' => 'whois.cnnic.net.cn',
'ORG.CN' => 'whois.cnnic.net.cn',
'QH.CN' => 'whois.cnnic.net.cn',
'SC.CN' => 'whois.cnnic.net.cn',
'SD.CN' => 'whois.cnnic.net.cn',
'SH.CN' => 'whois.cnnic.net.cn',
'SN.CN' => 'whois.cnnic.net.cn',
'SX.CN' => 'whois.cnnic.net.cn',
'TJ.CN' => 'whois.cnnic.net.cn',
'TW.CN' => 'whois.cnnic.net.cn',
'XJ.CN' => 'whois.cnnic.net.cn',
'XZ.CN' => 'whois.cnnic.net.cn',
'YN.CN' => 'whois.cnnic.net.cn',
'ZJ.CN' => 'whois.cnnic.net.cn',

'AC.FJ' => 'whois.domains.fj',
'BIZ.FJ' => 'whois.domains.fj',
'COM.FJ' => 'whois.domains.fj',
'INFO.FJ' => 'whois.domains.fj',
'MIL.FJ' => 'whois.domains.fj',
'NAME.FJ' => 'whois.domains.fj',
'NET.FJ' => 'whois.domains.fj',
'ORG.FJ' => 'whois.domains.fj',
'PRO.FJ' => 'whois.domains.fj',

'CO.GY' => 'whois.registry.gy',
'COM.GY' => 'whois.registry.gy',
'NET.GY' => 'whois.registry.gy',

'COM.HK' => 'whois.hknic.net.hk',
'GOV.HK' => 'whois.hknic.net.hk',
'NET.HK' => 'whois.hknic.net.hk',
'ORG.HK' => 'whois.hknic.net.hk',

'AC.JP' => 'whois.jprs.jp',
'AD.JP' => 'whois.jprs.jp',
'CO.JP' => 'whois.jprs.jp',
'GR.JP' => 'whois.jprs.jp',
'NE.JP' => 'whois.jprs.jp',
'OR.JP' => 'whois.jprs.jp',

'AC.MA' => 'whois.iam.net.ma',
'CO.MA' => 'whois.iam.net.ma',
'GOV.MA' => 'whois.iam.net.ma',
'NET.MA' => 'whois.iam.net.ma',
'ORG.MA' => 'whois.iam.net.ma',
'PRESS.MA' => 'whois.iam.net.ma',

'COM.MX' => 'whois.nic.mx',
'GOB.MX' => 'whois.nic.mx',
'NET.MX' => 'whois.nic.mx',

'COM.MT' => 'whois.nic.mt',
'ORG.MT' => 'whois.nic.mt',
'NET.MT' => 'whois.nic.mt',
'EDU.MT' => 'whois.nic.mt',

'CO.RS' => 'whois.rnids.rs',
'ORG.RS' => 'whois.rnids.rs',
'IN.RS' => 'whois.rnids.rs',
'EDU.RS' => 'whois.rnids.rs',

'COM.TW' => 'whois.twnic.net',
'IDV.TW' => 'whois.twnic.net',
'NET.TW' => 'whois.twnic.net',
'ORG.TW' => 'whois.twnic.net',

'COM.UA' => 'whois.com.ua',
'ORG.UA' => 'whois.com.ua',
'BIZ.UA' => 'whois.biz.ua',
'CO.UA' => 'whois.co.ua',
'PP.UA' => 'whois.pp.ua',
'KIEV.UA' => 'whois.com.ua',
'DN.UA' => 'whois.dn.ua',
'LG.UA' => 'whois.lg.ua',
'OD.UA' => 'whois.od.ua',
'IN.UA' => 'whois.in.ua',
'CRIMEA.UA' => 'whois.crimea.ua',
'YALTA.UA' => 'whois.crimea.ua',
'OD.UA' => 'whois.od.ua',
'ODESSA.UA' => 'whois.od.ua',
'ODESA.UA' => 'whois.od.ua',
'DN.UA' => 'whois.dn.ua',
'DONETSK.UA' => 'whois.dn.ua',
'LG.UA' => 'whois.dn.ua',
'LUGANSK.UA' => 'whois.dn.ua',
'KH.UA' => 'whois.kh.ua',
'KHARKOV.UA' => 'whois.kh.ua',
'KHARKIV.UA' => 'whois.kh.ua',
'KIROVOGRAD.UA' => 'whois.kr.ua',
'KR.UA' => 'whois.kr.ua',
'LT.UA' => 'whois.lutsk.ua',
'LUTSK.UA' => 'whois.kr.ua',
'VOLYN.UA' => 'whois.kr.ua',
'LVIV.UA' => 'whois.lviv.ua',
'SM.UA' => 'whois.sm.ua',
'SUMY.UA' => 'whois.sm.ua',
'ZP.UA' => 'whois.zp.ua',
'ZAPORIZHZHE.UA' => 'whois.zp.ua',

'AC.UK' => 'whois.ja.net',
'CO.UK' => 'whois.nic.uk',
'GOV.UK' => 'whois.ja.net',
'LTD.UK' => 'whois.nic.uk',
'NET.UK' => 'whois.nic.uk',
'ORG.UK' => 'whois.nic.uk',
'PLC.UK' => 'whois.nic.uk',

'XN--P1AG' => 'ru.whois.i-dns.net',
'XN--P1AG' => 'ru.whois.i-dns.net',
'XN--J1AEF' => 'whois.i-dns.net',
'XN--E1APQ' => 'whois.i-dns.net',
'XN--C1AVG' => 'whois.i-dns.net',

'EU.COM' => 'whois.centralnic.com',
'GB.COM' => 'whois.centralnic.com',
'KR.COM' => 'whois.centralnic.com',
'US.COM' => 'whois.centralnic.com',
'QC.COM' => 'whois.centralnic.com',
'DE.COM' => 'whois.centralnic.com',
'NO.COM' => 'whois.centralnic.com',
'HU.COM' => 'whois.centralnic.com',
'JPN.COM' => 'whois.centralnic.com',
'UY.COM' => 'whois.centralnic.com',
'ZA.COM' => 'whois.centralnic.com',
'BR.COM' => 'whois.centralnic.com',
'CN.COM' => 'whois.centralnic.com',
'SA.COM' => 'whois.centralnic.com',
'SE.COM' => 'whois.centralnic.com',
'UK.COM' => 'whois.centralnic.com',
'RU.COM' => 'whois.centralnic.com',

'GB.NET' => 'whois.centralnic.com',
'UK.NET' => 'whois.centralnic.com',
'SE.NET' => 'whois.centralnic.com',

'AE.ORG' => 'whois.centralnic.com',

'ORG.NS' => 'whois.pir.org',
'BIZ.NS' => 'whois.biz',
'NAME.NS' => 'whois.nic.name',
'SO' => 'whois.nic.so',
'BZ' => 'whois.enom.com',
'XXX' => ' whois.nic.xxx'
);

	$zone = $domain;
	$zone =~ s/^.*?\.//;
	$zone = uc($zone);
	if (exists $whois{$zone}) { $result = `whois -h $whois{$zone} $domain`; }
	else { $result = `whois $domain`; }
	$result = decode('UTF8', $result);

	return $result;
}

sub check_whois {
	my $result = shift;

	if ($result =~ /domain not in database\:/ ||
		$result =~ /No entries found for/ ||
		$result =~ /No match for/ ||
		$result =~ /not found/i ||
		$result =~ /No entries found\./ ||
		$result =~ /No records found for object/ ||
		$result =~ /No such domain/ ||
		$result =~ /$domain is free/ ||
		$result =~ /no entries found/ ||
		$result =~ /Object does not exist/ ||
		$result =~ /Status:.AVAILABLE/ ||
		$result =~ /No match record found for / ||
		$result =~ /domain deleted/
	) { return 0; }
	else { return 1; }
}

sub format_phone {
	my $phone = shift;

	$phone =~ s/[^0-9]//g;
	$phone =~ s/^(\d\d\d)/\+$1\./;

	return $phone;
}

sub create_rnd {
	my ($amount, $out, @chars);
	$amount = shift;

	$amount--;
	@chars = split('', 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz');
	$out = join("", @chars[ map{ rand @chars } (0 .. ($amount-6)) ]);
	@chars = split('', '!$_@');
	$out .= join("", @chars[ map{ rand @chars } (0 .. 1) ]);
	@chars = split('', [0 .. 9]);
	$out .= join("", @chars[ map{ rand @chars } (0 .. 1) ]);
	@chars = split('', map{ rand @chars } (0 .. $#chars));
	$out .= join("", @chars[ map{ rand @chars } (0 .. $#chars) ]);

	return $out;
}

sub get_cart {
	my ($self, $value, $val, $list, $domain, @tmp, %list, %price);
	($self) = @_;

	# read and decode list of domains for register from json
	$value = $self->{'tx'}->{'req'}->{'content'}->{'headers'}->{'headers'}->{'cookie'};
	if ($$value[0][0]) {
		my @tmp = split(';', $$value[0][0]);
		map {
			if (s/domains_storage=//) { $val = $_; }
		} (@tmp);
		if ($val) {
			$val = JSON::XS->new->decode($val);

			# Read list of domains price
			$list = dblist(
				'collection'	=> $self->{'app'}->{'zones'},
				'query'		=> { },
				'fields'	=> { 'zone' => 1, 'price' => 1 }
			);
			map {
				$price{$_->{'zone'}} = $_->{'price'}[$self->session->{'discount'}];
			} (@{$list});

			map {
				$domain = $_;
				$domain =~ s/^.*?\.//;
				if (exists $price{$domain}) {
					$list{$_} = $price{$domain};
				}
			} (@{$val});
		}
		@tmp = ();
		%price = ();
		$value = $val = $list = $domain = '';
	}

	return \%list;
}

sub translit {
	my ($text, %hash);
	$text = shift;

	%hash = (
	'а' => 'a', 'б' => 'b', 'в' => 'v', 'г' => 'g', 'д' => 'd', 'е' => 'e', 'ё' => 'jo', 'жЖ' => 'zh', 'зЗ' => 'z', 'и' => 'i', 'й' => 'j', 'к' => 'k', 'л' => 'l', 'м' => 'm', 'н' => 'n', 'о' => 'o', 'п' => 'p', 'р' => 'r', 'с' => 's', 'т' => 't', 'у' => 'u', 'ф' => 'f', 'х' => 'kh', 'ц' => 'c', 'ч' => 'ch', 'ш' => 'sh', 'щ' => 'sh', 'ъ' => '', 'ы' => 'y', 'ь' => '', 'э' => 'e', 'ю' => 'ju', 'я' => 'ja',
	'А' => 'A', 'Б' => 'B', 'В' => 'V', 'Г' => 'G', 'Д' => 'D', 'Е' => 'E', 'Ё' => 'Jo', 'Ж' => 'Zh', 'З' => 'Z', 'И' => 'I', 'Й' => 'J', 'К' => 'K', 'Л' => 'L', 'М' => 'M', 'Н' => 'N', 'О' => 'O', 'П' => 'P', 'Р' => 'R', 'С' => 'S', 'Т' => 'T', 'У' => 'U', 'Ф' => 'F', 'Х' => 'Kh', 'Ц' => 'C', 'Ч' => 'Ch', 'Ш' => 'Sh', 'Щ' => 'Sh', 'Ъ' => '', 'Ы' => 'Y', 'Ь' => '', 'Э' => 'E', 'Ю' => 'Ju', 'Я' => 'Ja'
	);

	map { $out .= $hash{$_}; } (split('', $text));

	return $out;
}

1;
