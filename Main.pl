#!/usr/bin/perl
# ToSee is a application that will go through specified folders in your HDD and find all the movies in them. Then it displays all the movies with their poster.

use strict;
use Glib qw/TRUE FALSE/;
use Gtk2 '-init';
use POSIX;
use File::Basename;
use Films;
use Cwd;
use Storable;
use Data::Dumper;

## Init
my $home_folder = dirname($0);
$home_folder = getcwd() if($home_folder eq '.');

my $config_file = $home_folder . "/config.data";
my %opt;
if(-e $config_file) {
	%opt = %{retrieve($config_file)};
	
} else { # Default Options
	%opt = (
		'locations'	=> [],
		'show_poster' => 1,
		'get_posters' => 1,
		'max_cols' => 6,
		'video_player_app' => 'smplayer "%f"',
		'file_manager_app' => 'konqueror "%d"'
	);
}

my %app_info = (
	'name'		=> 'ToSee',
	'version'	=> '1.00.A',
	'page'		=> 'http://www.bin-co.com/perl/apps/tosee/'
);

# Fetch the data
my $movies = new Films(\%opt);
my %active_film;					# for Get Poster Part.

################################# GUI Building Part #################################
my $w = new Gtk2::Window('toplevel');
$w->signal_connect(delete_event => \&deleteEvent);
$w->signal_connect(destroy => sub { Gtk2->main_quit; });
$w->set_default_size(800, 600);

my $vbox_main = new Gtk2::VBox(0, 0);
$w->add($vbox_main);

# Creating the menu bar.
my $menubar = Gtk2::MenuBar->new();

# File Menu
my $menu_item_file = Gtk2::MenuItem->new("File");
my $sub_menu_file = Gtk2::Menu->new();
$menu_item_file->set_submenu($sub_menu_file);

my $menu_item_file_refresh = Gtk2::MenuItem->new("Refresh");
my $menu_item_file_auto_fetch_posters = Gtk2::MenuItem->new("Auto Fetch Posters");
my $menu_item_file_get_posters = Gtk2::MenuItem->new("Find Missing Posters");
my $menu_item_file_quit = Gtk2::MenuItem->new("Quit");

$sub_menu_file->append($menu_item_file_refresh);
$sub_menu_file->append($menu_item_file_auto_fetch_posters);
$sub_menu_file->append($menu_item_file_get_posters);
$sub_menu_file->append($menu_item_file_quit);

$menu_item_file_quit->signal_connect("activate", sub { Gtk2->main_quit; }, "file.quit");
$menu_item_file_refresh->signal_connect("activate", \&refreshMovieList);
$menu_item_file_auto_fetch_posters->signal_connect("activate", sub {
	$sub_menu_file->popdown;
	$movies->cachePosters($home_folder);
	refreshMovieList();
});
$menu_item_file_get_posters->signal_connect("activate", \&showGetPosterDialog );


$menubar->append($menu_item_file);

# Preferences Menu
my $menu_item_preferences = Gtk2::MenuItem->new("Preferences");
my $sub_menu_preferences = Gtk2::Menu->new();
$menu_item_preferences->set_submenu($sub_menu_preferences);

my $menu_item_preferences_folders = Gtk2::MenuItem->new("Set Folders");
my $menu_item_preferences_optinos = Gtk2::MenuItem->new("Options");

$sub_menu_preferences->append($menu_item_preferences_optinos);
$sub_menu_preferences->append($menu_item_preferences_folders);

$menu_item_preferences_folders->signal_connect("activate", \&showFolderChooser, "preferences.set-folders");
$menu_item_preferences_optinos->signal_connect("activate", \&showPreferencesDialog, "preferences.options");
$menubar->append($menu_item_preferences);

# Help Menu
my $menu_item_help = Gtk2::MenuItem->new("Help");
my $sub_menu_help = Gtk2::Menu->new();
$menu_item_help->set_submenu($sub_menu_help);

my $menu_item_help_about = Gtk2::MenuItem->new("About");
$sub_menu_help->append($menu_item_help_about);
$menu_item_help_about->signal_connect("activate", \&showAboutDialog, "help.about");
$menubar->append($menu_item_help);
# End of menu code - really, it should'nt be this hard

my $ttip_all = Gtk2::Tooltips->new();

# There might be a lot of films - so put them in a scrolled window - for people with small screens ;-P
my $scwin = Gtk2::ScrolledWindow->new();
$scwin->set_policy('automatic', 'automatic');

my $frm_main = Gtk2::Frame->new();
$scwin->add_with_viewport($frm_main);
my $tab_layout; # The table widget - make it a global variable.

loadFilms();
$frm_main->add($tab_layout);

$vbox_main->pack_start($menubar, 0, 0, 0);
$vbox_main->pack_start($scwin, 1, 1, 0);
$w->show_all;

Gtk2->main;

if($opt{'get_posters'}) {
	#Happens after the user closes the app.
	$movies->cachePosters($home_folder);
}

#Save Configuration
store \%opt, $config_file;

##################################### Functions #####################################
sub deleteEvent {
	$w->destroy;
	return TRUE;
}

sub info {
	my $message = shift;
	print $message . "\n";
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

# Creates a table and shows the current films in that area.
sub loadFilms {
	chdir($home_folder); #Or die is not needed. Even if the images are not there, show the app(movie name will appear in the button)
	
	my $total_films = $movies->getTotal();

	my $rows = POSIX::ceil($total_films / $opt{'max_cols'});
	$tab_layout = Gtk2::Table->new($rows, $opt{'max_cols'}, FALSE);
	
	my $current_row = 0;
	my $current_col = 0;
	
	while(my $ref = $movies->getFilm()) {
		my %film_details = %{$ref};
		
		my $vbox_film = Gtk2::VBox->new(FALSE);
		
		my $film = $film_details{'name'};
		#my $short_name = $film;
		my $short_name = substr($film, 0, 40);
		$short_name = $short_name . '...' if($short_name ne $film);
		
		my $but_film = Gtk2::Button->new($short_name);
		$ttip_all->set_tip($but_film, $film); #Set the title as the tooltip
		
		if($opt{'show_poster'}) {
			# Show the poster if the poster image file exists
			my $poster_image = 'Posters/' . $film . '.jpg';
			if(-e $poster_image
					&& ! (-l $poster_image)) { # If the image file is a link, that means no poster. Don't show the image - show the name instead.
				my $img_poster = Gtk2::Image->new();
				$img_poster->set_from_file($poster_image);
				$but_film->set_image($img_poster); #Set the Poster as the Clickable button
				$but_film->set_label('');#And remove the title - if we have a poster
			}
		}
		
		$but_film->signal_connect(clicked => \&seeFilm, [$w, \%film_details]);
		$vbox_film->add($but_film);
		
		my $but_film_location = Gtk2::Button->new("Open Folder");
		$ttip_all->set_tip($but_film_location, $film_details{'path'}); #Set the title as the tooltip
		$but_film_location->signal_connect(clicked => \&openContainingFolder, [$w, \%film_details]);
		$vbox_film->add($but_film_location);
		
		my $lab_film_details = Gtk2::Label->new("Size: " . $film_details{'size'} . ' MB');
		$vbox_film->add($lab_film_details);
		
		my $hsep_down = Gtk2::HSeparator->new();
		$vbox_film->add($hsep_down);
		
		$tab_layout->attach_defaults($vbox_film, $current_col, $current_col+1, $current_row, $current_row+1);
		
		$current_col++;
		
		if($current_col == $opt{'max_cols'}) {
			$current_row++;
			$current_col = 0;
		}
	}
}

sub refreshMovieList {
	$movies->resetFilmList;
	$movies->findMovies;
	
	$frm_main->remove($tab_layout);
	$tab_layout->destroy;
	loadFilms();
	$frm_main->add($tab_layout);
	$frm_main->show_all;
}

########################################## Get Poster Dialog ###############################################
sub showGetPosterDialog {
	my $dialog = Gtk2::Dialog->new('Get Missing Posters', $w, [qw/modal destroy-with-parent/], 'gtk-ok' => 'accept');

	$dialog->signal_connect(delete_event => sub { $dialog->destroy; });
	
	chdir($home_folder); #Or die is not needed.
	
	# These must be declared here - but not added.
	my $but_poster = Gtk2::Button->new('Poster Preview...');
	my $img_poster = Gtk2::Image->new();
	$but_poster->set_image($img_poster); #Set the Poster as the Clickable button
	$but_poster->signal_connect(clicked => \&setPoster, [$dialog]);

	my $response_id = 0;
	
	$movies->{'index'} = 0;
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
			$but_get_poster->signal_connect(clicked => \&getPoster, [$dialog, \%film_details, $ent_film_name, $img_poster, $but_poster]);
			
			$hbox->add($ent_film_name);
			$hbox->add($but_get_poster);
			$dialog->vbox->add($hbox);
		}
	}
	
	$dialog->vbox->add($but_poster);
	$dialog->show_all;
	$response_id = $dialog->run;
	$dialog->destroy;
}

sub getPoster {
	my $button = shift;
	my @data = shift;
	my %film_details = %{$data[0][1]};
	my $film_entry = $data[0][2];
	my $img_poster = $data[0][3];
	my $but_poster = $data[0][4];
	my $film_name = $film_entry->get_text();
	
	my $poster_image = $movies->getPoster($film_name, 0);
	if($poster_image) {
		$active_film{'film_name'} = $film_details{'name'};
		$active_film{'image_file'} = $poster_image;
		$img_poster->set_from_file($poster_image);
		$but_poster->set_label("Use this poster for " . $film_details{'name'});
	}
}

sub setPoster {
	my $poster_folder = File::Spec->join($home_folder, 'Posters');
	my $image_file = File::Spec->join($poster_folder, $active_film{'film_name'} . ".jpg");
	
	use File::Copy;
	unlink($image_file) if(-e $image_file); #Just coping it don't overwrite the shortcut file for some reason.
	copy($active_film{'image_file'}, $image_file) or print "Failed: $!";
	
	my $msgbox = Gtk2::MessageDialog->new ($w, [], 'info','ok', "Poster for '" . $active_film{'film_name'} . "' saved");
    my $response = $msgbox->run();
    $msgbox->destroy;
}

###################################### Folder Choser Dialog ###########################
sub showFolderChooser {
	my $dialog = Gtk2::Dialog->new('Choose Movie Folders', $w, [qw/modal destroy-with-parent/], 'gtk-ok' => 'accept', 'gtk-cancel' => 'cancel');
	foreach my $folder (@{$opt{'locations'}}) {
		addNewFolderRow($dialog, $folder);
	}
	
	# An extra row - to add new folders
	addNewFolderRow($dialog, '');
	
	$dialog->show_all;
	my $response_id = $dialog->run;

	#User clicked ok - get all the folders in the list. And save it to the config variable.
	if ($response_id eq "accept") {
		my @new_location_list;
		
		my @hboxes = $dialog->vbox->get_children();
		for(my $i=0; $i<scalar(@hboxes)-2; $i++) {
			my @widgets = $hboxes[$i]->get_children();
			my $loc = $widgets[0]->get_text();
			next unless $loc;
			
			# Check the validity of the folder.
			if(-d $loc) { # Is it a folder?
				# See if its already in the list...
				my $found = 0;
				foreach my $location (@new_location_list) {
					if($location eq $loc) {
						$found++;
						last;
					}
				}
				
				push(@new_location_list, $loc) if(!$found);
			}
		}
 		@{$opt{'locations'}} = @new_location_list;
	}
	info "Destroying Folder Choser Dialog...";
	$dialog->destroy;
}

# Create a new 'Text Entry - Browse - Delete' row.
sub addNewFolderRow {
	my $dialog = shift;
	my $folder = shift;
	
	my $hbox = Gtk2::HBox->new(FALSE);
	my $txt_location = Gtk2::Entry->new();
	$txt_location->set_text($folder);
	my $but_browse = Gtk2::Button->new("Browse");
	my $but_delete = Gtk2::Button->new("Delete");
	
	$hbox->add($txt_location);
	$hbox->add($but_browse);
	$hbox->add($but_delete);
	
	$but_browse->signal_connect(clicked => \&selectFolder, [$dialog, $txt_location]);
	$but_delete->signal_connect(clicked => \&removeRow, [$dialog, $hbox, $txt_location]);
	
	$dialog->vbox->add($hbox);
	
	return $hbox;
}

sub removeRow {
	my $button = shift;
	my @data = shift;
	my $hbox = $data[0][1];
	my $txt_location = $data[0][2];
	
	# Don't remove the row if the user clicks the last row.
	if($txt_location->get_text() ne "") {
		$txt_location->set_text('');
		$hbox->destroy;
	}
}

sub selectFolder {
	my $button = shift;
	my @data = shift;
	my $dialog = $data[0][0];
	my $txt_location = $data[0][1];
	
	my $file_dialog = Gtk2::FileChooserDialog->new('Choose film folder...', $w, 'GTK_FILE_CHOOSER_ACTION_SELECT_FOLDER', 'gtk-ok' => 'accept');
	my $current_folder = $txt_location->get_text();
	$file_dialog->set_filename($current_folder) unless($current_folder eq "");
	my $response_id = $file_dialog->run;
	
	#User clicked ok - get all the folders in the list. And save it to the config variable.
	if ($response_id eq "accept") {
		$txt_location->set_text($file_dialog->get_filename());
		# If the folder path was empty, it was the last row. As its filled now, add a new last row...
		if($current_folder eq "") {
			my $hbox = addNewFolderRow($dialog, '');
			$hbox->show_all;
		}
	}
	$file_dialog->destroy;
}

###################################### Preferences Dialog #############################

sub showPreferencesDialog {
	my $dialog = Gtk2::Dialog->new('More Options', $w, [qw/modal destroy-with-parent/], 'gtk-ok' => 'accept', 'gtk-cancel' => 'cancel');
	
	my $frm_ui_options = Gtk2::Frame->new("UI Options");
	my $vbox_ui_options = Gtk2::VBox->new(FALSE);
	
	# Get poster from IMDB or not - do you have internet or no?
	my $hbox_get_poster = Gtk2::HBox->new(FALSE);
	my $chk_get_poster = Gtk2::CheckButton->new("Get Posters From IMDB");
	$chk_get_poster->set_active($opt{'get_posters'});
	$ttip_all->set_tip($chk_get_poster, "Net connection needed");
	$hbox_get_poster->add($chk_get_poster);
	$vbox_ui_options->add($hbox_get_poster);
	
	# Max number of cols.
	my $hbox_column_count = Gtk2::HBox->new(FALSE);
	my $lab_column_count = Gtk2::Label->new("Maximum Number of Columns");
	my $spin_column_count = Gtk2::SpinButton->new(Gtk2::Adjustment->new($opt{'max_cols'}, 2,15, 1,1, 5), 1, 0);
	$hbox_column_count->add($lab_column_count);
	$hbox_column_count->add($spin_column_count);
	$vbox_ui_options->add($hbox_column_count);
	
	$frm_ui_options->add($vbox_ui_options);
	$dialog->vbox->add($frm_ui_options);
	my $lab_spacer = Gtk2::Label->new("");
	$dialog->vbox->add($lab_spacer);

	my $frm_applications = Gtk2::Frame->new("Applications");
	my $vbox_application = Gtk2::VBox->new(FALSE);
	
	#Choose the video player application
	my $hbox_video_player = Gtk2::HBox->new(FALSE);
	my $lab_video_player = Gtk2::Label->new("Video Player");
	my $txt_video_player = Gtk2::Entry->new();
	$txt_video_player->set_text($opt{'video_player_app'});
	$hbox_video_player->add($lab_video_player);
	$hbox_video_player->add($txt_video_player);
	$vbox_application->add($hbox_video_player);
	
	#Choose the file manager application - for the 'Open Folder'
	my $hbox_file_manager = Gtk2::HBox->new(FALSE);
	my $lab_file_manager = Gtk2::Label->new("File Manager");
	my $txt_file_manager = Gtk2::Entry->new();
	$txt_file_manager->set_text($opt{'file_manager_app'});
	$hbox_file_manager->add($lab_file_manager);
	$hbox_file_manager->add($txt_file_manager);
	$vbox_application->add($hbox_file_manager);
	
	my $lab_variables = Gtk2::Label->new("Variables:\n%f - Full File Path.\n%d - Directory of movie\n%n - Name of the movie");
	$lab_variables->set_justify('left');
	$vbox_application->add($lab_variables);
	
	$frm_applications->add($vbox_application);
	$dialog->vbox->add($frm_applications);
	
	$dialog->show_all;
	my $response_id = $dialog->run;
	
	if ($response_id eq "accept") {
		my $get_posters = ($chk_get_poster->get_active()) ? 1 : 0;
		
		$opt{'get_posters'} = $get_posters;
		$opt{'show_poster'} = $get_posters;
		$opt{'max_cols'} = $spin_column_count->get_value_as_int();
		$opt{'file_manager_app'} = $txt_file_manager->get_text();
		$opt{'video_player_app'} = $txt_video_player->get_text();
		
		info "Saved Preferences";
	}
	info "Destroying Preferences dialog";
	$dialog->destroy;
}

sub showAboutDialog {
	my $dialog = Gtk2::Dialog->new('About ToSee', $w, [qw/modal destroy-with-parent/], 'gtk-ok' => 'accept');
	
	my $lab_info = Gtk2::Label->new("ToSee " . $app_info{'version'} . "\nBy Binny V A(http://binnyva.com/)");
	$dialog->vbox->add($lab_info);
	
	$dialog->show_all;
	$dialog->run;
	$dialog->destroy;
}

###################################### TODO ###########################################
# Get rating from IMDB, show it
# Genre
# Running time
