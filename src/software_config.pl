#!/opt/rocks/bin/perl

use warnings;
use strict;

## Really stupidly naive path autoconfig script
## for jumpstarting ergatis software.config
## settings in a Rocks (or any other) install
##
## Brett Whitty
## brett@gnomatix.com

use Cwd;
use Carp;
use File::Basename;
use File::Find::Rule;
use File::Slurp;

my $key_count = 0;
my $configured_count = 0;
my $packages = {};
my $dbs = {};
my $staging = {};

my $cwd = getcwd();
my $software_config = $cwd.'/ergatis-install/software.config';

my $staging_dir = '/state/partition1/ergatis';

my $tool_dirs = [
	'/opt/bio',
	'/share/bio',
	'/opt/ergatis/bin'
];

unless (-f $software_config) {
	croak "No 'software.config' found at '$software_config'";
}

my $tools = {};

foreach my $dir(@{$tool_dirs}) {
	my @files = `find $dir -type f -perm /g+x`;

	foreach my $file(@files) {
		chomp $file;

		my $base = basename($file);
		
		push(@{$tools->{$base}}, $file);
	}
}

my @software_config = read_file($software_config);

my $config = {};
foreach my $line(@software_config) {
	chomp $line;

	## try to guess
	my $is_db_file = 0;
	my $is_package_dir = 0;

	if ($line =~ /^[^;]+.*=[^;]+.*/) {
		my ($key, $val) = split(/=/, $line, 2);

		$key_count++;

		## strip trailing whitespace
		$key =~ s/^\s*|\s*$//g;
		$val =~ s/^\s*|\s*$//g;

		if ($val =~ /^.*\/staging\/.*/i) {
			print STDERR "## REPLACED - '$key': '$val'";
			$val =~ s/^.*\/staging\/(.*)$/$staging_dir\/$1/i;
			print STDERR " => '$val'\n";
			$line =~ s/^.*\/staging\/(.*)$/$staging_dir\/$1/i;
			$staging->{$val} = 1;
		}

		if ($val =~ /\/db(s)?\/(.*)/i) {
			$dbs->{$2} = 1;
			
			## try to recognize values pointing to database files
			if ($val =~ /(\.niaa$|\.txt$|\.fasta$|\.lib$|^nr$|\.db|\.bin$|\.dat$|\.f[nas]?a$)/i) {
				$is_db_file = 1;
			}
		}
		if ($val =~ /\/packages\/([^\/]+)\//i) {
			$packages->{$1} = 1;
		}


		my $base = basename($val);

		if (defined($tools->{$base})) {
			if (scalar @{$tools->{$base}} == 1) {

			## make sure we don't match ergatis install binaries of same name to real tool binaries
			if ($val !~ /\/ergatis\// && $tools->{$base}->[0] =~ /\/ergatis\//) {
				print $line."\n";
				next;
			}

			print STDERR "## CONFIGURED - '$key': '$val' => '$tools->{$base}->[0]'\n";
			$configured_count++;	
			print STDOUT "$key=$tools->{$base}->[0]\n";
			} elsif (scalar @{$tools->{$base}} > 1) {
				print STDERR "## WARNING - '$key' has '".scalar(@{$tools->{$base}})."' possible locations (".
					join(',', @{$tools->{$base}})
					.")\n";
				foreach my $tool_opt(@{$tools->{$base}}) {
					if ($val !~ /\/ergatis\// && $tool_opt =~ /\/ergatis\//) {
						next;
					} else {
						print STDERR "## CONFIGURED - '$key': '$val' => '$tool_opt'\n";
						$configured_count++;	
						print STDOUT "$key=$tool_opt ;;;CONFIGURED\n";
						last;
					}
				}
			} else {
				carp "This should never happen!";
			}
		
		} else {
			if ($is_db_file) {
				print $line." ;;;NO_DATABASE_FILE_FOUND\n";
			} else {
				print $line." ;;;NO_MATCH_FOUND\n";
			}
		}

	} else {
		print $line."\n";
	}
}

print STDERR "## DONE - [ $configured_count / $key_count ] config variables updated.\n";

use Data::Dumper;
print Dumper $packages;
print Dumper $dbs;
print Dumper $staging;
