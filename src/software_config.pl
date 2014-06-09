#!/opt/rocks/bin/perl

use Config::IniFiles;
use Getopt::Long;

my $inifile;
my $set;
my $get;
my $section;
my $param;
my $value;

GetOptions(
	'input|i=s'	=>	\$inifile,
	'set!'		=>	\$set,
	'get!'		=>	\$get,
	'section|s=s'	=>	\$section,
	'param|p=s'	=>	\$param,
	'value|v=s'	=>	\$value,
);

unless (defined($inifile) && -f $inifile) {
    die "Must specify an inifile that exists with --input flag!";
}

$cfg = Config::IniFiles->new( -file => $inifile );

if ($get) {
	print get($section, $param);
} elsif ($set) {
	set($section, $param, $value);
}

sub get {
	my ($section, $param) = @_;
	
	my $value = $cfg->val($section, $param);	
	
	return $value;
}

sub set {
	my ($section, $param, $value) = @_;
	
	$cfg->setval($section, $param, $value);	
	
	$cfg->RewriteConfig() or die "Failed to update config file.";
}
