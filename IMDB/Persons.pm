=head1 NAME

IMDB::Persons - Perl extension for retrieving movies persons
from IMDB.com

=head1 SYNOPSIS

  	use IMDB::Persons;

	#
	# Retrieve a person information by IMDB code
	#
	my $person = new IMDB::Persons(crit => '0000129');

	or 
	
	#
	# Retrieve a person information by name
	#
  	my $person = new IMDB::Persons(crit => 'Tom Cruise');

	or 
	
	#
	# Process already stored HTML page from IMDB
	#
	my $person = new IMDB::Persons(file => 'imdb.html');

	if($person->status) {
		print "Name: ".$person->name."\n";
		print "Birth Date: ".$person->date_of_birth."\n";
	} else {
		print "Something wrong: ".$person->error."!\n";
	}

=head1 DESCRIPTION

IMDB::Persons allows to retrieve an information about
IMDB persons (actors, actresses, directors etc): full name,
photo, date and place of birth, mini bio and filmography.

=cut
package IMDB::Persons;

use strict;
use warnings;

use Carp;

use Data::Dumper;

use base qw(IMDB::BaseClass);

use fields qw(	_name
				_date_of_birth
				_place_of_birth
				_photo
				_mini_bio
				_filmography_types
				_filmography
				_genres
				_plot_keywords
	);

use vars qw($VERSION %FIELDS);

use constant FORCED 	=> 1;
use constant CLASS_NAME => 'IMDB::Persons';
use constant MAIN_TAG	=> 'h5';

BEGIN {
	$VERSION = '0.32';
}

{
	my %_defaults = ( 
		cache			=> 0,
		debug			=> 0,
		error			=> [],
		matched			=> [],
		cache_exp		=> '1 h',
        host			=> 'www.imdb.com',
        query			=> 'name/nm',
        search 			=> 'find?nm=on;mx=20;q=',		
		status			=> 0,		
		timeout			=> 10,
		user_agent		=> 'Mozilla/5.0',
	);

	sub _get_default_attrs { keys %_defaults }		
	sub _get_default_value {
		my($self, $attr) = @_;
		$_defaults{$attr};
	}
}

=head1 Object Private Methods

=over 4

=item _init()

Initialize a new object.

=cut
sub _init {
	my CLASS_NAME $self = shift;
	my %args = @_;	

	croak "Person IMDB ID or Name should be defined!" if !$args{crit} && !$args{file};									

	$self->SUPER::_init(%args);
	my $name = $self->name();
	
	for my $prop (grep { /^_/ && !/^_name$/ } sort keys %FIELDS) {
		($prop) = $prop =~ /^_(.*)/;
		$self->$prop();
	}
}

=item _search_person()

Implements a logic to search IMDB persons by their names.

=cut
sub _search_person {
	my CLASS_NAME $self = shift;

	return $self->SUPER::_search_results('\/name\/nm(\d+)', '/a');
}

sub fields {
	my CLASS_NAME $self = shift;
	return \%FIELDS;
}


=back

=head1 Object Public Methods

=over 4

=item name()

Retrieve a person full name

	my $person_name = $person->name();

=cut
sub name {
	my CLASS_NAME $self = shift;
	if(!defined $self->{'_name'}) {	
		my $parser = $self->_parser(FORCED);

		$parser->get_tag('title');
		my $title = $parser->get_text();

		$self->_show_message("Title=$title", 'DEBUG');
		
		if($title =~ /imdb\s+name\s+search/i) {
			$self->_show_message("Go to search page ...", 'DEBUG');
			$title = $self->_search_person();				
		} 

		if($title) {		
			$self->status(1);
			$self->retrieve_code($parser, 'pro.imdb.com/name/nm(\d+)') unless $self->code;
		} else {
			$self->status(0);
			$self->error('Not Found');
		}

		$self->{'_name'} = $title;
	}

	return $self->{'_name'};
}

=item mini_bio()

Returns a mini bio for specified IMDB person

	my $mini_bio = $person->mini_bio();

=cut
sub mini_bio {
	my CLASS_NAME $self = shift;
	if(!defined $self->{_mini_bio}) {
		my $parser = $self->_parser(FORCED);
		my $tag;
		while( $tag = $parser->get_tag(MAIN_TAG) ) {
			last if $parser->get_text() =~ /Mini biography/i;
		}
		
		#$tag = $parser->get_tag('dd');
		
		$self->{'_mini_bio'} = $parser->get_trimmed_text(MAIN_TAG, 'a');
	}
	return $self->{'_mini_bio'};
}

=item date_of_birth()

Returns a date of birth of IMDB person in format 'day' 'month caption' 'year':

	my $d_birth = $person->date_of_birth();

=cut
#TODO: add date convertion in different formats.
sub date_of_birth {
	my CLASS_NAME $self = shift;
	if(!defined $self->{'_date_of_birth'}) {
		my $parser = $self->_parser(FORCED);
		while(my $tag = $parser->get_tag(MAIN_TAG)) {
			my $text = $parser->get_text;
			last if $text =~ /Date of birth/i;
		}

		my $date = '';
		my $year = '';
		my $place = '';
		while(my $tag = $parser->get_tag('a')) {
			last if !$tag->[1]->{href} or $tag->[1]->{href} !~ /(OnThisDay|BornInYear|BornWhere)/i;

			my $text = $parser->get_text();
			next unless $text;
			SWITCH: for($tag->[1]->{href}) {
				/OnThisDay/i && do { $date = $text; last SWITCH; };
				/BornInYear/i && do { $year = $text; last SWITCH; };
				/BornWhere/i && do { $place = $text; last SWITCH; };
			}			
		}

		$self->{'_date_of_birth'} = {date => "$date $year", place => $place};
	} 

	return $self->{'_date_of_birth'}{'date'};
}

=item place_of_birth()

Returns a name of place of the birth

	my $place = $person->place_of_birth();

=cut
sub place_of_birth {
	my CLASS_NAME $self = shift;
	return $self->{'_date_of_birth'}{'place'};
}

=item photo()

Return a path to the person's photo

	my $photo = $person->photo();

=cut
sub photo {
	my CLASS_NAME $self = shift;
	if(!defined $self->{'_photo'}) {
		my $tag;
		my $parser = $self->_parser(FORCED);
		while($tag = $parser->get_tag('a')) {
			last if defined $tag->[1]{name} && $tag->[1]{name} eq 'headshot';
		}

		$tag = $parser->get_tag('img');
		$self->{'_photo'} = $tag->[1]{src};
	}

	return $self->{'_photo'};
}

=item filmography()

Returns a person's filmography as array of hashes with a following
structure: 

	my $fg = $person->filmography();

	__DATA__
	$fg = [
			{ 	title 	=> 'movie title', 
				role 	=> 'person role', 
				year 	=> 'year of movie production',
				code	=> 'IMDB code of movie',	
			}
	];

=cut
sub filmography {
	my CLASS_NAME $self = shift;
	
	my $films;
	if(!$self->{'_filmography'}) {
		my $parser = $self->_parser(FORCED);
		while(my $tag = $parser->get_tag('h3')) {

			my $text = $parser->get_text;
			last if $text && $text =~ /filmography/i;
		}	

		while(my $tag = $parser->get_tag()) {
		
			last if $tag->[0] eq '/ol';
			
			if($tag->[0] eq 'a' && $tag->[1]->{href} && $tag->[1]{href} =~ m!title\/tt(\d+)!) {
				my $title = $parser->get_text();
				my $text = $parser->get_trimmed_text('br', '/li');
				
				my $code = $1;
				my($year, $role) = $text =~ m!\((\d+)\)\s.+\.+\s(.+)!;
				push @$films, {	title 	=> $title, 
								code 	=> $code,
								year	=> $year,
								role	=> $role,
							};
			} 
		}

		$self->{'_filmography'} = $films;

	} else {
		$self->_show_message("filmography defined!", 'DEBUG');
	}
	
	return $self->{'_filmography'};
}

=item genres()

Retrieve a list of movie genres for specified person:

	my $genres = $persons->genres;

=cut
sub genres {
	my CLASS_NAME $self = shift;

	unless($self->{_genres}) {
		my @genres = $self->_get_common_array_propery('genres');	
		$self->{_genres} = \@genres;
	}

	$self->{_genres};
}

=item plot_keywords()

Retrieve a list of keywords for movies where specified person plays:

	my $keywords = $persons->plot_keywords;

=cut
sub plot_keywords {
	my CLASS_NAME $self = shift;

	unless($self->{_plot_keywords}) {
		my @keywords = $self->_get_common_array_propery('plot keywords');	
		$self->{_plot_keywords} = \@keywords;
	}

	$self->{_plot_keywords};
}

sub _get_common_array_propery {
	my CLASS_NAME $self = shift;
	my $target = shift || '';

	my $parser = $self->_parser(FORCED);
	while(my $tag = $parser->get_tag(MAIN_TAG)) {
		my $text = $parser->get_text();
		last if $text =~ /$target/i;
	}
		
	my @res = ();
	while(my $tag = $parser->get_tag('a')) {
		last if $tag->[1]->{class} && $tag->[1]->{class} =~ /tn15more/i;
		push @res, $parser->get_text;
	}
	
	return @res;
}

sub filmography_types {
	my CLASS_NAME $self = shift;
}

sub DESTROY {
	my $self = shift;
}

1;

__END__

=head1 EXPORTS

Nothing

=head1 BUGS

Please, send me any found bugs by email: stepanov.michael@gmail.com. 

=head1 SEE ALSO

IMDB::Film
IMDB::BaseClass
WWW::Yahoo::Movies
HTML::TokeParser

=head1 AUTHOR

Mikhail Stepanov AKA nite_man (stepanov.michael@gmail.com)

=head1 COPYRIGHT

Copyright (c) 2004 - 2007, Mikhail Stepanov.
This module is free software. It may be used, redistributed and/or 
modified under the same terms as Perl itself.

=cut
