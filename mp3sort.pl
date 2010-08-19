#!/usr/bin/perl

# mp3sort - template based mp3 sorter using ID3 tags
# Copyright 2010 by Patrick Schoenfeld <schoenfeld@debian.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

use strict;
use warnings;

use File::Find::Rule;
use Getopt::Long;
use MP3::Tag;
use File::Path qw(make_path);
use File::Copy;
use File::Spec;
use Cwd;

# Variables:
# %a = Artist
# %A = Album
# %g = Genre
# %n = Track number
# %t = Title
my $template="%a/%A";
my $dry_run=0;
my $copy_instead_of_move=1;
my $replace_spaces=0;
my $allow_missing_album_info=1;
my $base_dir=getcwd();
my $target_dir="/tmp";
my $verbose=0;
my $opt_help;
my $opt_version;

Getopt::Long::Configure ("bundling");
GetOptions(
    "h|help" => \$opt_help,
    "version" => \$opt_version,
    "v+" => \$verbose,

    "t|template=s" => \$template,
    "dry-run" => \$dry_run,
    "allow_missing_album_info" => \$allow_missing_album_info,
    "target-dir=s" => \$target_dir,
    "base-dir=s" => \$base_dir,
    "use-copy" => \$copy_instead_of_move,
    "replace-spaces", \$replace_spaces,
);

sub new_filename {
    my ($file, $shortname, $template) = @_;
    if (not -r $file) {
	print STDERR "File $file is not readable.\n";
	return undef;
    }

    my $mp3 = MP3::Tag->new($file);
    my ($title, $track, $artist, $album, undef, $year, $genre) = $mp3->autoinfo();

    # Generate the new filename
    $_ = $template;

    if ($artist and $template =~ /%a/) {
        s/%a/$artist/g;
    } elsif ($template =~ /%a/) {
	print STDERR "Ignoring $file (artist info missing)\n";
	return undef;
    }
    if (($album and $template =~ /%A/) or $allow_missing_album_info) {
        s/%A/$album/g;
    } elsif ($template =~ /%A/) {
	print STDERR "Ignoring $file (album info missing)\n";
	return undef;
    }
    if ($title and $template =~ /%t/) {
        s/%t/$title/g;
    } elsif ($template =~ /%t/) {
	print STDERR "Ignoring $file (title info missing)\n";
	return undef;
    }
    if ($genre and $template =~ /%g/) {
        s/%g/$genre/g;
    } elsif ($template =~ /%g/) {
	print STDERR "Ignoring $file (genre info missing)\n";
	return undef;
    }
    if ($track and $template =~ /%n/) {
        s/%n/$track/g;
    } elsif ($template =~ /%n/) {
	print STDERR "Ignoring $file (track info missing)\n";
	return undef;
    }

    if ($replace_spaces) {
	s/\s/_/g;
    }

    return ($_, $shortname);
}

sub create_path {
    my $path = shift;
    return if (-d $path);
    print "Creating path $path\n" if $verbose > 1;
    make_path($path) if not $dry_run;
}

sub move_file {
    my ($source, $target) = @_;

    return if ($source eq $target);
    return if $dry_run;

    if ($copy_instead_of_move) {
	copy($source, $target) or print STDERR "Copy failed: $!\n";
    }
}

sub get_source_and_target {
    my ($source, $target_path, $shortname) = @_;
    my $target;

    $target = File::Spec->join($target_path, $shortname);

    print "$source -> $target\n" if $verbose > 0;
    return ($source, $target);
}

sub act_on_file {
    my ($shortname, $path, $fullname) = @_;
    my ($new_path, $filename) = new_filename($fullname, $shortname, $template);
    if ($new_path) {
	if (not -d $target_dir) {
	    print STDERR "Target directory '$target_dir' does not exist.\n";
	    exit 1;
	}

	my $target_path = File::Spec->join($target_dir,$new_path);
	create_path($target_path);
	move_file(get_source_and_target($fullname, $target_path, $filename));
    }
}

sub find_files_and_act {
    my $find = File::Find::Rule->new;

    $find->name('*.mp3');
    $find->exec(\&act_on_file);
    $find->in(($base_dir));
}

find_files_and_act;
