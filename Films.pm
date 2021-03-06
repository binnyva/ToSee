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

sub new {
	my ($package, $option) = @_;
	my $self = bless({}, $package);
	my %opt = %{$option};
	
 	$self->{'locations'} = $opt{'locations'};
	$self->{'index'} = -1;
	$self->{'movies'} = [];
	
	$self->{'video_player'} = $opt{'video_player_app'};
	$self->{'file_manager'} = $opt{'file_manager_app'};
	
	$self->findMovies();
	return $self;
}

sub findMovies {
	my $self = shift;
	
	foreach my $path (@{$self->{'locations'}}) {
		$self->findMoviesInFolder($path);
		$self->findMoviesInFolder(File::Spec->join($path, 'To See'));
		$self->findMoviesInFolder(File::Spec->join($path, 'Give Bijoy'));
		$self->findMoviesInFolder(File::Spec->join($path, 'Written'));
	}
}

sub findMoviesInFolder {
	my $self = shift;

	my $path = shift;
	return unless(-e $path);
	
	chdir($path) or return;
	
	my %allowed_extensions = ('avi'=>1,'mpg'=>1,'mpeg'=>1,'mkv'=>1,'dir'=>1, 'mp4'=>1, 'divx'=>1 );
	my @files = glob("*");
	
	foreach my $f (@files) {
		my $full_path = File::Spec->join($path, $f);
		my ($name,$ext);
		
		if(-d $full_path) { #Its a folder - get name.
			$name = basename($f);
			$ext = 'dir';
		
		} elsif($f =~ /([^\/]+)\.([^\.]+)$/) { #Find the name and extention of the file
			$name	= $1;
			$ext	= lc($2);
		}
		next if($name eq 'To See' || $name eq 'Give Bijoy' || $name eq 'Written' || $name eq 'Problem' || $name eq 'Media Browser');
		
		if($allowed_extensions{$ext}) {
			$name =~ s/[_\.]/ /g; #Convert _ and . to space
			$name =~ s/(dvdrip|divx|xvid|axxo).*$//i; #Remove unwanted video details in the name
			$name =~ s/[\[\(].+?[\)\]]//g; #Remove Language
			$name =~ s/\s*[\[\(\{]\s*$//g; #Remove junk that still exists
			
			if($name =~ /(.+) \- (.+)/) { # Sometimes directors name gets included in the title - like this 'Akira Kurosawa - Rashomon.avi'
				$name = $2;
			}
			
			my @file_details;
			my $size = 0;
			# Get the extact file path if the $ext is 'dir'
			if($ext eq 'dir') {
				chdir($full_path);
				my @all_files = sort(glob("*"));
				my $found_videos = 0;
				my $found_video_path;
				my $found_video_ext;
				
				foreach my $vf (@all_files) {
					my($fname,$fext);
					
					if($vf =~ /([^\/]+)\.([^\.]+)$/) {
						$fname	= $1;
						$fext	= lc($2);
					}
					
					@file_details = stat($vf);
					$size = $size + $file_details[7];
					
					#Cool - we got a video file in the folder
					if($allowed_extensions{$fext}) { # Got a file with a valid extention
						$found_videos++;
						$found_video_path = File::Spec->join($full_path, $vf);
						$found_video_ext = $fext;
					}
				}
				# Set it as a file only if there is 1 video in the folder - if there is more than 1, open the folder.
				if($found_videos == 1) {
					$full_path = $found_video_path;
					$ext = $found_video_ext;
				}
			} else {
				@file_details = stat($full_path); # We need the file size of the file/folder.
				$size = $file_details[7];
			}
			
			my $details = $self->getMovieDetails($name, $full_path, int($size/(1024*1024)), $ext);
			$self->addMovie($details);
		}

	}
}

sub getMovieDetails {
	my $self = shift;
	my $name = shift;
	my $path = shift;
	my $size = shift;
	my $ext  = shift;
	
	return {'name'=>$name, 'path'=>$path, 'type'=>$ext, 'size'=>$size};
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

sub resetFilmList {
	my $self = shift;
	$self->{'movies'} = [];
	$self->{'index'} = 0;
}

sub cachePosters {
	my $self = shift;
	my $home_folder = shift;
	
	my $poster_folder = File::Spec->join($home_folder, 'Posters');
	
	foreach my $ref (@{$self->{'movies'}}) {
		my %film_details = %{$ref};
		my $film = $film_details{'name'};
		next if(-e File::Spec->join($poster_folder, $film . ".jpg")); #If We already have the cover, skip it.
		
		my $film_poster = $self->getPoster($film, $poster_folder);
	}
}

sub getPoster {
	my ($self, $film, $poster_folder) = @_;
	
	print "Fetching Movie details for '$film' ... ";
	use LWP::Simple;
	use File::Temp qw/ tempfile tempdir /;
	
	my $temp_folder = dirname(tempdir());
	my $film_details = new IMDB::Film(crit => $film, timeout => 60, 
				cache => 1, cache_root => '/tmp/imdb_cache', cache_exp => '30 d');
	if($film_details->status) {
		print "Done\n";
		my $url = $film_details->cover;
		my $image_file = '';
		
		if($poster_folder) {
			$image_file = File::Spec->join($poster_folder, $film . ".jpg");
			
			unless($url) { # Film ain't got a poster, mate!
				symlink(File::Spec->join($poster_folder, "NoPoster.jpg"), $image_file); #So, we put up a no poster image.
				next;
			}
		} else {
			$image_file = File::Spec->join($temp_folder, $film . ".jpg");
		}
		
		if($url) {
			print "Fetching Poster $url ... $image_file ... ";
			my $cover_image = get($url);
			open(IMG_OUT, ">" . $image_file) or die("Cannot write image file: $!");
			print IMG_OUT $cover_image;
			close(IMG_OUT);
			print "Done\n";
			
			my @file_stats = stat($image_file);
			unlink($image_file) if($file_stats[7] == 0); #Delete the file if the file size is 0 - its not downloaded properly.
			
			return $image_file;
		}
	} else {
		print "Something wrong: ".$film_details->error;
	}
	
	return '';
}

sub openFilm {
	my ($self, %film) = @_;
	
	my $command = $self->{'video_player'};
	
	my $directory = dirname($film{'path'});
	$command =~ s/%d/$directory/g;
	$command =~ s/%f/$film{'path'}/g;
	$command =~ s/%n/$film{'name'}/g;
	
	exec $command;
}

sub openContainingFolder {
	my ($self, %film) = @_;
	
	my $command = $self->{'file_manager'};
	
	my $directory = dirname($film{'path'});
	$command =~ s/%d/$directory/g;
	$command =~ s/%f/$film{'path'}/g;
	$command =~ s/%n/$film{'name'}/g;
	
	exec $command;
}

1;