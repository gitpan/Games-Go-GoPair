# $Id: TDFinder.pm,v 1.17 2005/01/17 03:04:43 reid Exp $

#   TDFinder: find players in TDLIST and enter them into
#               an appropriate .tde file.  The most recent
#               TDLIST is available from the AGA at:
#                       http:www.usgo.org
#   Copyright (C) 2004, 2005 Reid Augustin reid@netchip.com
#                      1000 San Mateo Dr.
#                      Menlo Park, CA 94025 USA

#   This library is free software; you can redistribute it and/or modify it
#   under the same terms as Perl itself, either Perl version 5.8.5 or, at your
#   option, any later version of Perl 5 you may have available.
#
#   This program is distributed in the hope that it will be useful, but WITHOUT
#   ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
#   FITNESS FOR A PARTICULAR PURPOSE.
#

#
# ToDo:
#       double click match to copy into tdeText
#       drag matches into tdeText
#       add menu button with:
#               help, sort options, 

=head1 NAME

TDFinder - a widget to support preparing Go tournament registration

=head1 SYNOPSIS

use Games::Go::TDFinder;

$tdFinder = $parent-E<gt>Games::Go::TDFinder ( ? options ? );

=head1 DESCRIPTION

TDFinder is a widget to assist in preparing a Go Tournament register.tde file in AGA (American
Go Association) format.  It consists of three main parts: a TDEntry widget at the bottom, a
'match' list in the middle (which is an ROText widget), and the tde information at the top (A
TextUndo widget).

The widget opens the TDLIST file for searching.  Tournemant directors should download the most
recent TDLIST from the AGA shortly before the tournament.  The most recent TDLIST is available
from the AGA at: L<http:www.usgo.org>

Typing search keys into the TDEntry field causes the TDFinder to search through the TDLIST
looking for matches.  When the number of matches is small enough to fit into the 'match' list
ROText widget, they are posted there.  Individual TDLIST entries can be selected either by
further refining the search keys, or by using the Up/Down arrow keys.  Typing 'Enter', double
clicking a match (BUGBUG: TBD), or dragging a match to the tde text widget (BUGBUG: TBD)
transfers a match to the tde file.

The caller is responsible for make sure the final register.tde file corresponds to the
information in the tde part of the TDFinder widget.

=cut

package Games::Go::TDFinder; # composite widget for finding entries in TDLIST from AGA

use 5.005;
use strict;
use warnings;
use IO::File;
use File::stat;         # stat fields by name
use Games::Go::AGATourn;
use Tk;
use Tk::widgets qw/ Entry TextUndo ROText Adjuster /;
use Games::Go::TDEntry;
use Carp;

use base qw(Tk::Frame);      # TDFinder is a composite widget

Construct Tk::Widget 'TDFinder';

BEGIN {
    our $VERSION = sprintf "%d.%03d", '$Revision: 1.17 $' =~ /(\d+)/g;
}

# class variables:
our (@tdList);         # there should be one and only one TDLIST file

######################################################
#
#       methods
#
#####################################################

sub ClassInit {
    my ($class, $mw) = @_;

    $class->SUPER::ClassInit($mw);
}

sub Populate {
    my ($self, $args) = @_;

    $self->SUPER::Populate($args);

    $self->_initTDFinder();
    $self->ConfigSpecs(
        -tdListFile => ['PASSIVE',          'tdListFile', 'TDListFile', 'tdlist' ],
        -height     => [$self->{matchText}, 'height',     'Height',     12       ],
        -scrollbars => [$self->{tdeText},   'scrollbars', 'Scrollbars', 'osow'   ],
        -namelength => ['PASSIVE',          'namelength', 'Namelength', 20       ],
        -clublength => ['PASSIVE',          'clublength', 'Clublength', 10       ],
        DEFAULT     => [$self->{tdeText}],
        );

=head1 OPTIONS

=over 4

=item B<-tdListFile> => filename

Specify the filename of the current TDLIST file of players (from the AGA).  If
B<-tdListFile> => undef, no TDLIST file is opened (and you can't really do much of
anything), otherwise if TDLIST can't be opened, TDFinder complains and dies.

TDFinder checks the date of the tdListFile.  If it is less than two weeks old,
TDFinder presents a warning dialog box.

B<-tdListFile> may only be specified at widget creation. Configuring it later
has no effect.

Default: 'tdlist' (in the current directory - a symlink is acceptable)

=item B<-height> => height in chars

Height is passed to the matchText widget.

Default: 12

=item B<-scrollbars> => a scrollbar 'where string

The scrollbar 'where' string is passed to the tdeText widget.  See the
B<-scrollbars> option in L<Tk::Scrolled> for details.

Default: 'osow'

=item B<-namelength> => number

The starting length of names in the tdeText widget.  Lines are formatted so
that all the names take the same amount of space.  This number grows if a
longer name is entered into tdeText.

Default: 20

=item B<-clublength> => number

The starting length of club names in the tdeText widget.  Lines are formatted
so that all the club names take the same amount of space.  This number grows
if a longer name is entered into tdeText.

Default: 10

=item B<DEFAULT>

All other options are passed to the tdeText widget.

=back

=cut

    $self->Delegates(DEFAULT => $self->{tdeText}); # all unknown methods
    $self->toplevel->withdraw;
    $self->_initTdList($args);
    $self->toplevel->deiconify;
    return($self);
}

######################################################
#
#       Private methods
#
#####################################################

sub _initTDFinder {
    my $self = shift;

    # an undo-able Text widget for the register.tde file
    my $t = $self->{tdeText} = $self->Scrolled(
        'TextUndo',
        -wrap            => 'word',
        -exportselection => 'true', );
    $t->delete('1.0', 'end');

    $t->bind('Tk::TextUndo', '<Control-u>', [ 'undo']);
    $t->bind('Tk::TextUndo', '<Control-r>', [ 'redo']);

    # a read-only Text widget to show list of matches
    my $m = $self->{matchText} = $self->ROText(
        -wrap            => 'word',
        -takefocus       => 0,
        -exportselection => 'true', );
    my $a = $self->Adjuster();
    # TDEntry widget for entering search keys
    $self->{tdEntry} = $self->TDEntry(-text => 'Search:');

    # pack all the widgets
    $self->{tdEntry}->pack(
        -side   => 'bottom',
        -expand => 'false',
        -fill   => 'x');
    $m->pack(
        -side   => 'bottom',
        -expand => 'true',
        -fill   => 'both');
    $a->packAfter($m,
        -side   => 'bottom',
        -expand => 'true',
        -fill   => 'both');
    $t->pack(
        -side   => 'bottom',
        -expand => 'true',
        -fill   => 'both');

    # bindings:
    my $e = $self->{entry} = $self->{tdEntry}->Subwidget('entry');
    $e->bind('<KeyPress>'   => [$self => '_entryKeyPress', Ev('A'), ]);  # new key in search field
    $e->bind('<Up>'         => [$self => '_moveListSelection', -1]);
    $e->bind('<Down>'       => [$self => '_moveListSelection', +1]);
    $e->bind('<Shift-Up>'   => [$self => '_changeAgaRating', +1]);
    $e->bind('<Shift-Down>' => [$self => '_changeAgaRating', -1]);
    $e->bind('<Return>'     => [$self => '_addMatchSelection']);
    $e->bind('<Escape>'     => [$self => '_Escape']);

    $m->tagConfigure("match",
        -background => 'lightblue',
        -relief => 'raised',
        -underline => 'true');
    $t->tagConfigure('dup',
        -foreground => 'red');
    $m->tagConfigure('dup',
        -foreground => 'red');
    $self->Advertise(entry => $e);
    $self->Advertise(tdeText => $t);

=head1 ADVERTISED WIDGETS

=over 4

=item B<entry>

The TDEntry support widget: consists of a label, an entry widget, and a 'Case sensitive'
Checkbutton.

You might want to do something like:

    $tdFinder->Subwidget('entry')->focus(); # start with focus in entry widget.

=item B<tdeText>

The TextUndo widget which holds the current register.tde contents.  The caller is
reponsible for maintaining the on-disk file contents and making sure the tdeText content
matches the register.tde file (see L<tdfind>(1)).

Use something like:

    $register_tde = tdFinder->Subwidget('tdeText')->get('1.0', 'end')

to get the current contents of the tdeText widget.

=back

=cut

    $self->{mostRecentInsert} = 'none';
    $self->{matchForeground} = $self->{matchText}->cget('-foreground');
    $self->{tdeForeground} = $self->{tdeText}->cget('-foreground');
    $self->{agaTourn} = Games::Go::AGATourn->new(register_tde => undef,
                                                      Round        => 0);
    my $height = $m->reqheight - (2 * $m->cget('-pady'));  # pixel height
    $self->{matchFontHeight} = int($height / $self->{matchText}->cget('-height'));      # div by lines
    # initialize:
    $self->clear;
}

sub _initTdList {
    my ($self, $args) = @_;

    unless (scalar @tdList) {           # init class data once only
        my $tdListFile = exists($args->{'-tdListFile'}) ? $args->{'-tdListFile'} : 'tdlist';
        if (defined($tdListFile)) {
            my $fd = IO::File->new("<$tdListFile") or croak "can't open TDLIST $tdListFile: $!\n";
            $self->_checkTime($tdListFile);
            while (<$fd>) {
                push (@tdList, $_);
            }
            close($fd);
        }
    }
    $self->_clearListSelection;          # fake a keypress to get TDLIST count into match window
}

sub _checkTime {
    my ($self, $file, @args) = @_;

    if (-f $file) {     # seems to follow symbolic links just fine...
        my $week = 60 * 60 * 24 * 7;    # seconds in a week
        if (stat($file)->mtime < time - (2 * $week)) {       # too old?
            my $rsp = $self->Dialog(
                -text   => "$file is more than two weeks old.\n\n" .
                           "Please get the most recent TDListN.txt file from the AGA at:\n\n" .
                           "    http://usgo.org/ratings/default.asp\n",
                -buttons => ['Quit', 'Continue'],
                -default_button => 'Quit',
                )->Show;
            &Tk::exit(1) if ($rsp eq 'Quit');
        }
    } else {
        croak ("Don't know how to handle $file - doesn't seem to be a regular file\n");
    }
}

sub _getDupKeys {
    my $self = shift;

    my $t = $self->{tdeText};
    my @lines = ('dummy', split ("\n", $t->get("1.0", "end")));      # dummy line in front
    $self->{pids} = {};
    $self->{names} = {};
    for (my $ii = 1; $ii < @lines; $ii++) {
        $lines[$ii] =~ s/^\s*#.*//s;            # filter out comment only lines
        $lines[$ii] =~ s/^\s*//s;               # filter out empty lines
        next if ($lines[$ii] eq '');
        my $p = $self->{agaTourn}->ParseRegisterLine($lines[$ii]);
        my $pid = lc("$p->{country}$p->{agaNum}");
        my $name = lc($p->{name});              # lower case name to create key
        $name =~ s/\s//g;                       # and remove all whitespace
        push (@{$self->{pids}{$pid}}, $ii);
        push (@{$self->{names}{$name}}, $ii);
    }
}

sub _markTdeDups {
    my $self = shift;

    my $t = $self->{tdeText};
    my @lines = ('dummy', split ("\n", $t->get("1.0", "end")));      # dummy line in front
    $self->_getDupKeys();
    $t->tagDelete('dup');                       # remove all previous duplicate tags
    foreach my $pid (keys(%{$self->{pids}})) {
        if (scalar(@{$self->{pids}{$pid}}) > 1) {
            # uh oh, a duplicate:
            foreach my $ii (@{$self->{pids}{$pid}}) {
                $t->tagAdd('dup', "$ii.0", "$ii.8");
            }
        }
    }
    foreach my $name (keys(%{$self->{names}})) {
        if (scalar(@{$self->{names}{$name}}) > 1) {
            # uh oh, a duplicate:
            foreach my $ii (@{$self->{names}{$name}}) {
                $t->tagAdd('dup', "$ii.9", "$ii.9 + " . $self->cget('-namelength') . " chars");
            }
        }
    }
    $t->tagConfigure('dup',
        -foreground => 'red');
}

sub _rankCompare {
    my $self = shift;

    my $ratingA = ($a->{agaRating});
    $ratingA = -99 unless (defined($ratingA));
    my $ratingB = ($b->{agaRating});
    $ratingB = -99 unless (defined($ratingB));
    my $d = ($ratingB <=> $ratingA);    # reverse order to put stronger players at the top of the list
    my $s = 'R';
    if ($d == 0) {
        $s = 'n';
        $d = ($a->{name} cmp $b->{name});
    }
#    my $nameLen = 25;
# printf("%-*s %-5s %s$s %5s %*s\n",
#         $nameLen, $a->{name}, $a->{agaRating},
#         ($d > 0) ? '>' : (($d < 0) ? '<' : '='),
#         $b->{agaRating}, $nameLen, $b->{name},);
    return $d;
}

sub _Escape {
    my ($self) = @_;

    $self->sort();
    $self->_clearListSelection();
}

sub _clearListSelection {
    my ($self) = @_;

    $self->{entry}->delete(0, 'end');
    $self->_entryKeyPress('x');  # fake a key press
}

sub _parseTdListLine {
    my ($self, $td) = @_;

    my $p = ($self->{agaTourn}->ParseTdListLine($td));
    # convert from TDLIST format to TDE format
    $p->{comment} = join(' ', $p->{memType}, $p->{expire}, $p->{state});
    $p->{comment} =~ s/  */ /g;
    delete($p->{memType});
    delete($p->{expire});
    delete($p->{state});
    return $p
}

sub _parseRegisterLine {
    my ($self, $tde) = @_;

    return $self->{agaTourn}->ParseRegisterLine($tde);
}

sub _addMatchSelection {
    my ($self) = @_;

    my $m = $self->{matchText};                 # the match text widget
    if ($self->{matchListValid} > 0) {          # add the activated line to TDE
        $self->addPlayer($self->{matches}[$self->{active} - 1]);
    } elsif ($self->{matchListValid} < 0) {     # no matches, a tmp player?
        my $entry = $self->{tdEntry}->get();
        my ($rank, $name);
        if ($entry =~ s/\s+([0-9]+[dkDK])\s*$//) {
            $rank = $1;
        } else {
            $m->delete('1.0', 'end');
            $m->insert('1.0', 'Unlisted player needs rank (like 3D or 4k) at the end');
            return;
        }
        if ($entry =~ m/\s*(.+,.*)/) {
            $name = $1;
        } else {
            $m->delete('1.0', 'end');
            $m->insert('1.0', 'Unlisted player name needs last name, comma, then first name (and optional middle/honorific, etc).');
            return;
        }
        # cannonicalize the hash key
        $name =~ s/\s+/ /g;      # turn all whitespace into single space
        $name =~ s/^\s*//;       # delete preceding whitespace
        $name =~ s/\s*$//;       # delete following whitespace
        $self->{tmpNum}++;
        $self->addTDE("TMP$self->{tmpNum} $name $rank");
    } # else - need to narrow the search more, ignore...
}

sub _moveListSelection {
    my ($self, $change) = @_;

    my $m = $self->{matchText};
    my $active = $self->{active} + $change;
    return if (($active < 1) or ($active >= $m->index('end') - 1));
    $self->{active} = $active;
    $m->tagRemove('match', '1.0', 'end');
    $m->tagAdd('match', "$active.0", "$active.0 lineend");
}

sub _changeAgaRating {
    my ($self, $change) = @_;

    my $m = $self->{matchText};
    my $t = $self->{tdeEntry};
    my $active = $self->{active};
    my $p = $self->{matches}[$active - 1];
    my $pid = "$p->{country}$p->{agaNum}";
    if (($self->{ratingChanged}{$pid} == -99) and ($change > 0)) {
        $self->{ratingChanged}{$pid} = -31;      # change 99k to 30k
    }
    $self->{ratingChanged}{$pid} += $change;
    if ($self->{ratingChanged}{$pid} == 0) {
        $self->{ratingChanged}{$pid} += $change;   # skip over 0
    }
    $m->delete("$active.0", "$active.0 lineend");
    $m->insert("$active.0", $self->_format($p));
    $m->tagAdd('match', "$active.0", "$active.0 lineend");
}

sub _entryKeyPress {
    my ($self, $char) = @_;

    my $m = $self->{matchText};
    $char =~ s/\s*//g;          # turn whitespace chars to nothing
    return if ($char eq '');    # ignore whitespace and control type chars
    my $width = $m->reqwidth;   # insert changes widget back to it's original size.
    my $height = $m->reqheight;
    my $lines = $m->cget('-height');
# print("lines=$lines, height=$height, ");
    $lines = int($height / $self->{matchFontHeight});
# print("new lines=$lines\n");
    $m->configure('-height', $lines);
    $self->{matchListValid} = 0;
    $m->delete('1.0', 'end');
    $m->configure(-foreground => $self->{matchForeground});
    my $srchString = $self->{tdEntry}->get();
    $srchString =~ s/^\s*//;
    if ($srchString eq '') {
        $m->insert('end', scalar(@tdList) . " players in TDLIST\n");
    } else {
        my $matches = $self->{matches} = $self->_search($srchString);
        if (@$matches == 0) {
            $m->configure(-foreground => 'red');
            if (scalar(@tdList)) {
                $m->insert('end', "No matches\n");
            } else {
                $m->insert('end', "No TDLIST\n");
            }
            $self->{matchListValid} = -1;
        } elsif (@$matches >= $lines) {
            $m->insert('end', scalar(@$matches) . " matches\n");
        } else {        # insert the matches into the matchText widget
            foreach (@{$matches}) {
                $_ = $self->_parseTdListLine($_);        # convert TDLIST line to player
                $m->insert('end', $self->_format($_) . "\n");
            }
            $self->{active} = 1;
            $self->_moveListSelection(0);
            $self->{matchListValid} = 1;
            $self->_markMatchDups();
        }
    }
    # Restore size:
    $m->GeometryRequest($width, $height);
}

sub _markMatchDups {
    my $self = shift;

    my $m = $self->{matchText};
    my @lines = ('dummy', split ("\n", $m->get("1.0", "end")));      # dummy line in front
    $self->_getDupKeys();                        # make sure dup keys are up to date
    $m->tagDelete('dup');                       # remove all previous duplicate tags
    for (my $ii = 1; $ii < @{$self->{matches}} + 1; $ii++) {
        my $p = $self->{matches}[$ii - 1];
        my $pid = lc("$p->{country}$p->{agaNum}");
        my $name = lc($p->{name});              # lower case name to create key
        $name =~ s/\s//g;                       # and remove all whitespace
        $m->tagAdd('dup', "$ii.0", "$ii.8")
            if (exists($self->{pids}{$pid}));
        $m->tagAdd('dup', "$ii.9", "$ii.9 + " . $self->cget('-namelength') . " chars")
            if (exists($self->{names}{$name}));
    }
    $m->tagConfigure('dup',
        -foreground => 'red');
}

sub _search {
    my ($self, $srchString) = @_;

    my @keys = (split '\s+', $srchString);
    return () unless(@keys);
    my @filtered = @tdList;
    while (@keys) {
        my $re = shift(@keys);
        if ($self->{tdEntry}->case()) {
            eval { @filtered = grep(/$re/, @filtered) };
        } else {
            eval { @filtered = grep(/$re/i, @filtered) };
        }
        if ($@) {
            return ('Illegal or incomplete regular expression:', $@);
        }
    }
    return \@filtered;
}

# format a playerRef into register.tde format
sub _format {
    my ($self, $p) = @_;

    $p->{name} =~ s/\s+/ /g;            # turn all multiple whitespace into single space
    $p->{name} =~ s/ ,/,/g;             # no space in front of comma
    if (length($p->{name}) > $self->cget('-namelength')) {
        $self->configure(-namelength => length($p->{name}));
        $self->{lengthChange} = 1;
    }
    $p->{club} =~ s/^club=\s*//i;
    if ($p->{club} eq '') {
        if ($p->{name} =~ m/(.*?),/) {
            # use last name as club (reduce inter-family pairings)
            $p->{club} = $1;
            $p->{club} =~ s/\W//g;      # remove all non-word chars
        }
    }
    if (length($p->{club}) > $self->cget('-clublength')) {
        $self->configure(-clublength => length($p->{club}));
        $self->{lengthChange} = 1;
    }
    unless ($p->{club} eq '') {
        $p->{club} = "CLUB=$p->{club}"
    }
    unless (exists($p->{country})) {
        $p->{country} = 'TMP';
    }
    my $pid = "$p->{country}$p->{agaNum}";
    unless(exists($self->{ratingChanged}{$pid})) {
        $self->{ratingOrg}{$pid} =
            $self->{ratingChanged}{$pid} = int($self->{agaTourn}->RankToRating($p->{agaRating}));
    }
    my $r;
    if ($self->{ratingOrg}{$pid} == $self->{ratingChanged}{$pid}) {
        # original - use rating or a rank?
        if ((defined($p->{agaRank}) or         # always exists, but is undefined if rating is valid
            (lc($p->{country}) eq 'tmp'))) {  # TMPs always use low accuraccy D/K style
            if (defined($p->{agaRank})) {
                $r = uc($p->{agaRank});
            } else {
                $r = uc(_ratingToRank($p->{agaRating}));
            }
        } else {
            $r = $p->{agaRating};
        }
    } else {
        $r = _ratingToRank($self->{ratingChanged}{$pid});        # changes are always a rank
    }
    return sprintf("$p->{country}%05d %-*s   %5s %-*s $p->{flags} # $p->{comment}",
        $p->{agaNum}, $self->cget('-namelength'), $p->{name}, $r,
        $self->cget('-clublength'), $p->{club});
}

sub _ratingToRank {
    my ($rating) = @_;

    return sprintf("  %2d%s", ($rating > 0) ? $rating : -$rating, ($rating > 0) ? 'D' : 'K');
}

######################################################
#
#       Public methods
#
#####################################################

=head1 METHODS

=over 4

=item $tdFinder->B<clear>()

Clears the entire TDFinder, including the tdeText, matchText, and tdEntry
subwidgets.

=cut

sub clear {
    my ($self) = @_;

    $self->{matchListValid} = 0;        # doesn't contain valid TDE entries
    $self->{ratingOrg} = {};
    $self->{ratingChanged} = {};
    $self->{tmpNum} = 1;
    $self->{tdeText}->delete('1.0', 'end');
    $self->{matchText}->delete('1.0', 'end');
    $self->_clearListSelection;          # clear entry widget
}

=item $tdeFinder->B<addPlayer>($player)

Adds a player to the TDFinder.  Player should be a reference to a hash
containing the following members:

    $p->{agaNum}        required
    $p->{country}       required
    $p->{name}          required
    $p->{agaRating}     required
    $p->{club}          optional
    $p->{flags}         optional
    $p->{comment}       optional

=cut

sub addPlayer {
    my ($self, $p) = @_;

    my $t = $self->{tdeText};
    $t->tagConfigure($self->{mostRecentInsert},
        -foreground => $self->{tdeForeground});         # back to normal
    return unless (defined $p);                         # so we can un-mark by adding undef
    foreach (qw(agaNum country name agaRating)) {
        next if(defined($p->{$_}));
        carp ("No $_ defined for player\n");
        return;
    }
    foreach (qw(club flags comment)) {
        $p->{$_} = '' unless defined($p->{$_});
    }
    my $player = $self->_format($p);
    $player =~ m/^\s*(\S*)/;
    my $tag = $self->{mostRecentInsert} = lc($1);       # save most recent insertion
    # print "insert player(tag=$tag) at end: $player\n";
    $t->insert('end', "$player\n", $tag);
    $t->tagConfigure($tag,
        -foreground => 'darkgreen',);
    $t->see('end');
    $self->_markTdeDups();
    $self->eventGenerate('<<Change>>');
}

=item $tdFinder->B<addTD>('line in TDLIST format')

Parses a line from the TDLIST file and adds the player to tdeText.

=cut

sub addTD {
    my ($self, $td) = @_;

    $self->addPlayer($self->_parseTdListLine($td));
}

=item $tdFinder->B<addTDE>('line in register.tde format')

Parses a line from the register.tde file and adds the player to tdeText.

=cut

sub addTDE {
    my ($self, $tde) = @_;

    my $p = $self->_parseRegisterLine($tde);
    $self->addPlayer($p);
    if ((lc ($p->{country}) eq 'tmp') and
        ($p->{agaNum} >= $self->{tmpNum})) {
        $self->{tmpNum} = $p->{agaNum};
    }
}

=item $tdFinder->B<sort>()

Sorts the entries in tdeText.  Currently, only sorting by rank (strongest
first) is supported.  Comments lines are skipped over.

=cut


sub sort {
    my $self = shift;

    my $t = $self->{tdeText};
    my $ii;
    my @lines = ('dummy', split ("\n", $t->get("1.0", "end")));      # dummy line in front
    my @players;
    for ($ii = 1; $ii < @lines; $ii++) {
        $lines[$ii] =~ s/^\s*#.*//s;            # filter out comment only lines
        next if ($lines[$ii] eq '');
        push(@players, $self->{agaTourn}->ParseRegisterLine($lines[$ii]));
    }
    my @sortedPlayers = sort(_rankCompare @players);
    for ($ii = 1; $ii < @lines; $ii++) {
        next if ($lines[$ii] eq '');
        my $player = $self->_format(shift(@sortedPlayers));
        next if ($t->get("$ii.0", "$ii.0 lineend") eq $player);
        # print "delete line: $ii\n";
        $t->delete("$ii.0", "$ii.0 lineend");
        $player =~ m/^\s*(\S*)/;
        my $tag = lc($1);
        # print "insert player(tag=$tag) at line $ii: $player\n";
        $t->insert("$ii.0", $player, $tag);   # tag with AGA number (lower cased)
    }
    if (@sortedPlayers) {
        $self->Error('Players left over after sorting');
        while (@sortedPlayers) {
            my $player = $self->_format(shift(@sortedPlayers));
            # print "insert leftover player at end: $player\n";
            $t->insert('end', $player, 'error');
        }
        $t->tagConfigure('error',
            -foreground => 'red',
            -underline => 'true');
    }
    $self->_markTdeDups();
    $self->eventGenerate('<<Change>>');
}

1;

__END__

=head1 SEE ALSO

=over 0

=item o Games::Go::TDEntry(3)

perl/Tk entry widget support for TDFinder

=item o tdfind(1)

perl/Tk script that implements a TDLIST finder

=back

=head1 AUTHOR

Reid Augustin, E<lt>reid@netchip.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004, 2005 by Reid Augustin

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.

=cut

