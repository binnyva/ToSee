#!/usr/bin/perl

use strict;
use Glib qw/TRUE FALSE/;
use Gtk2 '-init';
use POSIX;
use File::Basename;
use Films;
use Cwd;

## Init
my $video_player = 'smplayer';
my $file_manager = 'konqueror';
my $home_folder = dirname($0);
$home_folder = getcwd() if($home_folder eq '.');

my @locations = (
	'/var/Data/Films',
	'/mnt/c/Films',
	'/mnt/e/Films',
	'/mnt/m/Films',
	'/mnt/n/Films',
	'/mnt/o/Films',
	'/mnt/p/Films',
	'/mnt/p/Torrent/Films');
my $movies = new Films(@locations);
my $total_films = $movies->getTotal();

################################# GUI Building Part #################################
my $w = Gtk2::Window->new('toplevel');
$w->signal_connect(delete_event => \&deleteEvent);
$w->signal_connect(destroy => sub { Gtk2->main_quit; });

my $rows = POSIX::ceil($total_films / 5);
my $tab_layout = Gtk2::Table->new($rows, 5, FALSE);
$w->add($tab_layout);

my $current_row = 0;
my $current_col = 0;

chdir($home_folder); #Or die is not needed.

while(my $ref = $movies->getFilm()) {
	my %film_details = %{$ref};
	
	my $vbox_film = Gtk2::VBox->new(FALSE);
	
	my $film = $film_details{'name'};
	
	#Show the poster if the poster image file exists
	if(-e 'Posters/' . $film . '.jpg') {
		my $img_poster = Gtk2::Image->new();
		$img_poster->set_from_file('Posters/' . $film . '.jpg');
		$vbox_film->add($img_poster);
		$img_poster->show;
	}
	
	my $but_film = Gtk2::Button->new($film);
	$but_film->signal_connect(clicked => \&seeFilm, [$w, \%film_details]);
	
	$vbox_film->add($but_film);
	$but_film->show;
	
	$tab_layout->attach_defaults($vbox_film, $current_col, $current_col+1, $current_row, $current_row+1);
	$vbox_film->show;
	
	$current_col++;
	
	if($current_col == 5) {
		$current_row++;
		$current_col = 0;
	}
}

$tab_layout->show;
$w->show;

Gtk2->main;

#Happens after the user closes the app.
$movies->cachePosters($home_folder);

##################################### Functions #####################################
sub deleteEvent {
	$w->destroy;
	return TRUE;
}

sub seeFilm {
	my $button = shift;
	my @data = shift;
	my %film = %{$data[0][1]};
	$w->destroy;
	my $tiker_status = "Seeing film \"" . $film{'name'} . "\"\n";
	`tiker $tiker_status`;
	
	if($film{'type'} ne 'dir') {
		exec $video_player, $film{'path'}; 
	} else {
		exec $file_manager, $film{'path'}; 
	}
	
}

###################################### TODO ###########################################
# Get rating from IMDB, show it
# Genre
