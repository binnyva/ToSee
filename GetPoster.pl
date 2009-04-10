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
my %active_film;

my @locations = ('/mnt/x/Videos/Films');
my $movies = new Films(@locations);
my $total_films = $movies->getTotal();

my $w = Gtk2::Window->new('toplevel');
$w->signal_connect(delete_event => \&deleteEvent);
$w->signal_connect(destroy => sub { Gtk2->main_quit; });

my $vbox_film = Gtk2::VBox->new(FALSE);
chdir($home_folder); #Or die is not needed.

while(my $ref = $movies->getFilm()) {
	my %film_details = %{$ref};
	
	my $film = $film_details{'name'};
	
	# Show the poster if the poster image file exists
	my $poster_image = 'Posters/' . $film . '.jpg';
	if(! (-e $poster_image)
			|| (-l $poster_image)) { # If the image file is a link, that means no poster.
		
		my $hbox = Gtk2::HBox->new(FALSE);
		my $ent_film_name = Gtk2::Entry->new();
		$ent_film_name->set_text($film);
		
		my $but_get_poster  = Gtk2::Button->new("Get Poster");
		$but_get_poster->signal_connect(clicked => \&getPoster, [$w, \%film_details, $ent_film_name]);
		
		
		$hbox->add($ent_film_name);
		$ent_film_name->show;
		$hbox->add($but_get_poster);
		$but_get_poster->show;
		
		$vbox_film->add($hbox);
		$hbox->show;
	}
}

my $but_poster = Gtk2::Button->new('Poster Preview...');
my $img_poster = Gtk2::Image->new();
$but_poster->set_image($img_poster); #Set the Poster as the Clickable button
$but_poster->signal_connect(clicked => \&setPoster, [$w]);

$vbox_film->add($but_poster);
$but_poster->show;

$w->add($vbox_film);
$vbox_film->show;

$w->show;
Gtk2->main;


##################################### Functions #####################################
sub deleteEvent {
	$w->destroy;
	return TRUE;
}

sub getPoster {
	my $button = shift;
	my @data = shift;
	my %film_details = %{$data[0][1]};
	my $film_entry = $data[0][2];
	my $film_name = $film_entry->get_text();
	
	my $poster_image = $movies->getPoster($film_name, 0);
	if($poster_image) {
		$active_film{'film_name'} = $film_details{'name'};
		$active_film{'image_file'} = $poster_image;
		$img_poster->set_from_file($poster_image);
		$but_poster->set_label($film_details{'name'});
	}
}

sub setPoster {
	my $poster_folder = File::Spec->join($home_folder, 'Posters');
	my $image_file = File::Spec->join($poster_folder, $active_film{'film_name'} . ".jpg");
	
	use File::Copy;
	copy($active_film{'image_file'}, $image_file);
	
	my $msgbox = Gtk2::MessageDialog->new ($w, [], 'info','ok', "Poster for '" . $active_film{'film_name'} . "' saved");
    my $response = $msgbox->run();
    $msgbox->destroy;

}
