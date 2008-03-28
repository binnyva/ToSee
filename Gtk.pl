#!/usr/bin/perl

use strict;
use Glib qw/TRUE FALSE/;
use Gtk2 '-init';
use POSIX;

################################# GUI Building Part #################################
my $w = Gtk2::Window->new('toplevel');
$w->signal_connect(delete_event => \&deleteEvent);
$w->signal_connect(destroy => sub { Gtk2->main_quit; });

my @films = ('One','Two','Three','Four','Five','Six','Seven','Eight','Nine','Ten','Eleven','Twelve','Thirteen','Fourteen');
my $rows = POSIX::ceil(scalar(@films) / 5);

my $tab_layout = Gtk2::Table->new($rows, 5, TRUE);
$w->add($tab_layout);

my $current_row = 0;
my $current_col = 0;
foreach my $i (0..$#films) {
	my $vbox_film = Gtk2::VBox->new(FALSE);
	
	my $img_poster = Gtk2::Image->new();
	$img_poster->set_from_file('Posters/The Sting.jpg');
	$vbox_film->add($img_poster);
	$img_poster->show;
	
	
	my $but_film = Gtk2::Button->new($films[$i]);
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

##################################### Functions #####################################
sub deleteEvent {
	$w->destroy;
	return TRUE;
}


0;
