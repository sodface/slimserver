package Slim::Web::Settings::Server::Behavior;


# Logitech Media Server Copyright 2001-2024 Logitech.
# Lyrion Music Server Copyright 2024 Lyrion Community.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.

use strict;
use base qw(Slim::Web::Settings);

use Slim::Utils::Prefs;
use Slim::Utils::Strings qw(string);

use constant ROLES_PER_ROW => 3;

my $prefs = preferences('server');

sub name {
	return Slim::Web::HTTP::CSRF->protectName('BEHAVIOR_SETTINGS');
}

sub page {
	return Slim::Web::HTTP::CSRF->protectURI('settings/server/behavior.html');
}

sub prefs {
	return ($prefs,
			qw(noGenreFilter noRoleFilter searchSubString ignoredarticles splitList
				browseagelimit groupdiscs persistPlaylists reshuffleOnRepeat saveShuffled composerInArtists
				conductorInArtists bandInArtists trackartistInArtists variousArtistAutoIdentification
				ignoreReleaseTypes cleanupReleaseTypes groupArtistAlbumsByReleaseType
				useTPE2AsAlbumArtist variousArtistsString ratingImplementation useUnifiedArtistsList
				skipsentinel showComposerReleasesbyAlbum showComposerReleasesbyAlbumGenres onlyAlbumYears
				artistAlbumLink albumartistAlbumLink trackartistAlbumLink composerAlbumLink conductorAlbumLink bandAlbumLink)
		   );
}

sub handler {
	my ( $class, $client, $paramRef ) = @_;

	my $userDefinedRoles = $prefs->get('userDefinedRoles');

	Slim::Schema::Album->addReleaseTypeStrings();

	$paramRef->{ratingImplementations} = Slim::Schema->ratingImplementations;

	my %releaseTypesToIgnore = map { $_ => 1 } @{ $prefs->get('releaseTypesToIgnore') || [] };

	# build list of release types, default and own
	my $ownReleaseTypes = Slim::Schema::Album->releaseTypes;
	$paramRef->{release_types} = [ map {
		my $type = $_;
		my $ucType = uc($_);

		$ownReleaseTypes = [
			grep { $_ ne $ucType } @$ownReleaseTypes
		];

		{
			id => $ucType,
			title => Slim::Schema::Album->releaseTypeName($type),
			ignore => $releaseTypesToIgnore{$ucType}
		};
	} grep {
		uc($_) ne 'ALBUM'
	} @{Slim::Schema::Album->primaryReleaseTypes} ];

	foreach (grep { $_ ne 'ALBUM' } @$ownReleaseTypes) {
		push @{$paramRef->{release_types}}, {
			id => $_,
			title => Slim::Schema::Album->releaseTypeName($_),
			ignore => $releaseTypesToIgnore{$_},
		};
	}

	if ( $paramRef->{'saveSettings'} ) {
		foreach my $releaseType (@{$paramRef->{release_types}}) {
			if ($paramRef->{'release_type_' . $releaseType->{id}}) {
				delete $releaseTypesToIgnore{$releaseType->{id}};
				delete $releaseType->{ignore};
			}
			else {
				$releaseTypesToIgnore{$releaseType->{id}} = $releaseType->{ignore} = 1;
			}
		}

		$prefs->set('releaseTypesToIgnore', [ keys %releaseTypesToIgnore ]);

		foreach my $role (Slim::Schema::Contributor::defaultContributorRoles()) {
			$prefs->set(lc($role)."AlbumLink", $paramRef->{"pref_".lc($role)."AlbumLink"});
			next if $role eq "ALBUMARTIST" || $role eq "ARTIST";
			$prefs->set(lc($role)."InArtists", $paramRef->{"pref_".lc($role)."InArtists"});
		}
		foreach my $role (Slim::Schema::Contributor::userDefinedRoles()) {
			$userDefinedRoles->{$role}->{albumLink} = $paramRef->{"pref_".lc($role)."AlbumLink"};
			$userDefinedRoles->{$role}->{include} = $paramRef->{"pref_".lc($role)."InArtists"};
		}
		$prefs->set('userDefinedRoles', $userDefinedRoles);
		$userDefinedRoles = $prefs->get('userDefinedRoles');
	}

	$paramRef->{usesFTS} = Slim::Schema->canFulltextSearch;

	my $menuDefaultRoles = {};
	my $j = 0;
	my $i = 0;
	foreach my $role (Slim::Schema::Contributor::defaultContributorRoles()) {
		next if $role eq "ALBUMARTIST" || $role eq "ARTIST";
		$j++ if !($i%ROLES_PER_ROW);
		push @{$menuDefaultRoles->{$j}}, { name => lc($role), selected => $prefs->get(lc($role)."InArtists") };
		$i++;
	}
	$paramRef->{menuDefaultRoles} = $menuDefaultRoles;

	my $menuUserRoles = {};
	my $j = 0;
	my $i = 0;
	foreach my $role (Slim::Schema::Contributor::userDefinedRoles()) {
		$j++ if !($i%ROLES_PER_ROW);
		push @{$menuUserRoles->{$j}}, { name => lc($role), selected => $userDefinedRoles->{$role}->{include} };
		$i++;
	}
	$paramRef->{menuUserRoles} = $menuUserRoles;

	my $linkRoles = {};
	my $pref;
	$j = 0;
	$i = 0;
	foreach my $role (Slim::Schema::Contributor::defaultContributorRoles(), Slim::Schema::Contributor::userDefinedRoles()) {
		$j++ if !($i%ROLES_PER_ROW);
		$pref = Slim::Schema::Contributor->isDefaultContributorRole($role) ? $prefs->get(lc($role)."AlbumLink") : $userDefinedRoles->{$role}->{albumLink};
		push @{$linkRoles->{$j}}, { name => lc($role), selected => $pref };
		$i++;
	}
	$paramRef->{linkRoles} = $linkRoles;

	return $class->SUPER::handler( $client, $paramRef );
}


1;

__END__
