#!/usr/bin/perl

use strict;
use Glib qw/TRUE FALSE/;
use Gtk2 '-init';
use POSIX;
use File::Basename;
use Films;
use Cwd;

## Init
my $home_folder = dirname($0);
$home_folder = getcwd() if($home_folder eq '.');

my @locations = (
	'/var/Data/Films',
	'/mnt/c/Films',
	'/mnt/d/Films',
	'/mnt/x/Films',
	'/mnt/x/Torrents/Films');
my $movies = new Films(@locations);
my $total_films = $movies->getTotal();

################################# GUI Building Part #################################
my $max_cols = 6;
my $w = new Gtk2::Window('toplevel');
$w->signal_connect(delete_event => \&deleteEvent);
$w->signal_connect(destroy => sub { Gtk2->main_quit; });
$w->set_default_size(800, 600);

my $ttip_all = Gtk2::Tooltips->new();

my $rows = POSIX::ceil($total_films / $max_cols);

my $scwin = Gtk2::ScrolledWindow->new();
$scwin->set_policy('automatic', 'automatic');

my $tab_layout = Gtk2::Table->new($rows, $max_cols, FALSE);
$scwin->add_with_viewport($tab_layout);
$w->add($scwin);

my $current_row = 0;
my $current_col = 0;

chdir($home_folder); #Or die is not needed.

while(my $ref = $movies->getFilm()) {
	my %film_details = %{$ref};
	
	my $vbox_film = Gtk2::VBox->new(FALSE);
	
	my $film = $film_details{'name'};
	
	my $but_film = Gtk2::Button->new($film);
	$ttip_all->set_tip($but_film, $film); #Set the title as the tooltip
	
	# Show the poster if the poster image file exists
	my $poster_image = 'Posters/' . $film . '.jpg';
	if(-e $poster_image
			&& ! (-l $poster_image)) { # If the image file is a link, that means no poster. Don't show the image - show the name instead.
		my $img_poster = Gtk2::Image->new();
		$img_poster->set_from_file($poster_image);
		$but_film->set_image($img_poster); #Set the Poster as the Clickable button
		$but_film->set_label('');#And remove the title - if we have a poster
	}
	
	$but_film->signal_connect(clicked => \&seeFilm, [$w, \%film_details]);
	$vbox_film->add($but_film);
	$but_film->show;
	
	my $but_film_location = Gtk2::Button->new("Open Folder");
	$ttip_all->set_tip($but_film_location, $film_details{'path'}); #Set the title as the tooltip
	$but_film_location->signal_connect(clicked => \&openContainingFolder, [$w, \%film_details]);
	$vbox_film->add($but_film_location);
	$but_film_location->show;
	
	my $lab_film_details = Gtk2::Label->new("Size: " . $film_details{'size'} . ' MB');
	$vbox_film->add($lab_film_details);
	$lab_film_details->show;
	
	my $hsep_down = Gtk2::HSeparator->new();
	$vbox_film->add($hsep_down);
	$hsep_down->show;
	
	$tab_layout->attach_defaults($vbox_film, $current_col, $current_col+1, $current_row, $current_row+1);
	$vbox_film->show;
	
	$current_col++;
	
	if($current_col == $max_cols) {
		$current_row++;
		$current_col = 0;
	}
}

$tab_layout->show;
$scwin->show;
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
	$movies->openFilm(%film);
}

sub openContainingFolder {
	my $button = shift;
	my @data = shift;
	my %film = %{$data[0][1]};
	$movies->openContainingFolder(%film);
}

###################################### TODO ###########################################
# Get rating from IMDB, show it
# Genre
# File size
# Running time
