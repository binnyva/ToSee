#!/usr/bin/perl
use strict;
use warnings;
use File::Spec;
use File::Basename;

my @locations = (
	'/var/Data/Films',
	'/mnt/c/Films',
	'/mnt/e/Films',
	'/mnt/m/Films',
	'/mnt/n/Films',
	'/mnt/o/Films',
	'/mnt/p/Films',
	'/mnt/p/Torrent/Films');

my @movies;

foreach my $path (@locations) {
	getMovies($path);
	getMovies(File::Spec->join($path, 'To See'));
}

sub getMovies {
	my $path = shift;
	return unless(-x $path);
	
	chdir($path) or return;
	
	my %allowed_extensions = ('avi'=>1,'mpg'=>1,'mpeg'=>1,'mkv'=>1,'dir'=>1);
	my @files = glob("*");
	
	#print $path . "\n";
	foreach my $f (@files) {
		my ($name,$ext);
		
		if(-d $f) {
			($name,$ext) = fileparse($f);
			$ext = 'dir';
		} elsif($f =~ /([^\/]+)\.([^\.]+)$/) {
			$name	= $1;
			$ext	= lc($2);
		}
		return if($name eq 'To See');
		
		if($allowed_extensions{$ext}) {
			$name =~ s/[_\.]/ /g; #Convert _ and . to space
			$name =~ s/(dvdrip|divx|xvid|axxo).*$//i; #Remove unwanted video details in the name
			$name =~ s/\s*[\(\[]?\d{4}[\)\]]//; #Remove year if given
			$name =~ s/\s*[\[\(\{]\s*$//g; #Remove junk that still exists
			
			
			print "Name: $name\n";
		}

	}
}

print "\n";