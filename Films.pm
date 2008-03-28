package Films;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

use File::Spec;
use File::Basename;
use IMDB::Film;

BEGIN {
	use Exporter ();
	@Pager::ISA         = qw(Exporter);
	@Pager::EXPORT      = qw();
	@Pager::EXPORT_OK   = qw();
}
use vars qw();

my($index, @locations, @movies);

sub new {
	my ($package,@all_locations) = @_;
	my $self = bless({}, $package);
	
 	@{$self->{'locations'}} = @all_locations;
	$self->{'index'} = 0;
	$self->{'movies'} = [];
	
	$self->findMovies();
	return $self;
}

sub findMovies {
	my $self = shift;
	
	foreach my $path (@{$self->{'locations'}}) {
		$self->findMoviesInFolder($path);
		$self->findMoviesInFolder(File::Spec->join($path, 'To See'));
	}
}

sub findMoviesInFolder {
	my $self = shift;

	my $path = shift;
	return unless(-e $path);
	
	chdir($path) or return;
	
	my %allowed_extensions = ('avi'=>1,'mpg'=>1,'mpeg'=>1,'mkv'=>1,'dir'=>1, 'mp4'=>1 );
	my @files = glob("*");
	
	foreach my $f (@files) {
		my ($name,$ext);
		
		if(-d $f) {
			($name,$ext) = fileparse($f);
			$ext = 'dir';
		} elsif($f =~ /([^\/]+)\.([^\.]+)$/) {
			$name	= $1;
			$ext	= lc($2);
		}
		next if($name eq 'To See');
		
		if($allowed_extensions{$ext}) {
			$name =~ s/[_\.]/ /g; #Convert _ and . to space
			$name =~ s/(dvdrip|divx|xvid|axxo).*$//i; #Remove unwanted video details in the name
			$name =~ s/\s*[\(\[]?\d{4}[\)\]]//; #Remove year if given
			$name =~ s/\s*[\[\(\{]\s*$//g; #Remove junk that still exists
			
			if($name =~ /(.+) \- (.+)/) { # Sometimes directors name gets included in the title - like this 'Akira Kurosawa - Rashomon.avi'
				$name = $2;
			}
			
			# :TODO: Get the extact file path if the $ext is 'dir'
			
			my $details = $self->getMovieDetails($name, File::Spec->join($path, $f), $ext);
			$self->addMovie($details);
		}

	}
}

sub getMovieDetails {
	my $self = shift;
	my $name = shift;
	my $path = shift;
	my $ext  = shift;
	
	return {'name'=>$name, 'path'=>$path, 'type'=>$ext};
}

sub addMovie {
	my $self = shift;
	my $movie_details = shift;
	
	push(@{$self->{'movies'}}, $movie_details);
}

sub getTotal {
	my $self = shift;
	return scalar(@{$self->{'movies'}});
}

sub getFilm {
	my $self = shift;
	my @all_movies = @{$self->{'movies'}};
	
	if($self->{'index'} < scalar(@all_movies)) {
		$self->{'index'}++;
		
		return $all_movies[$self->{'index'}];
	}
	
	return undef;
}

sub cachePosters {
	my $self = shift;
	my $home_folder = shift;
	
	my $poster_folder = File::Spec->join($home_folder, 'Posters');
	
	use LWP::Simple;
	
	foreach my $ref (@{$self->{'movies'}}) {
		my %film_details = %{$ref};
		my $film = $film_details{'name'};
		next if(-e File::Spec->join($poster_folder, $film . ".jpg")); #If We already have the cover, skip it.
		
		my $film_details = new IMDB::Film(crit => $film,timeout => 2, cache => 1, cache_root => '/tmp/imdb_cache', cache_exp => '30 d');
		if($film_details->status) {
			my $url = $film_details->cover;	
			
			my $cover_image = get($url);
			open(IMG_OUT, ">" . File::Spec->join($poster_folder, $film . ".jpg")) or die("Cannot write image file: $!");
			print IMG_OUT $cover_image;
			close(IMG_OUT);
			
		} else {
			print "Something wrong: ".$film_details->error;
		}
	}
}

1;