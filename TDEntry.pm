# $Id: TDEntry.pm,v 1.7 2005/01/05 22:58:44 reid Exp $

#   TDEntry: find players in TDLIST and enter them into
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
#

=head1 NAME

TDEntry - small widget to support the search key entry part of a TDFinder widget

=head1 SYNOPSIS

my $tdEntry = $parent->TDEntry( ?options? );

=head1 DESCRIPTION

This is just a collection of an Entry widget, a Label, and a Checkbutton.

=cut

package Games::Go::TDEntry; # composite widget for entering search terms for TDFinder

use 5.005;
use strict;
use warnings;
use Tk;
use Tk::widgets qw/ Label Entry Checkbutton /;
use base qw(Tk::Frame);      # TDEntry is a composite widget

Construct Tk::Widget 'TDEntry';

BEGIN {
    our $VERSION = sprintf "%d.%03d", '$Revision: 1.7 $' =~ /(\d+)/g;
}

# class variables:

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

    $self->initTDEntry();
    $self->ConfigSpecs(
        -text   => [$self->{label}, 'text',       'Text',       'Search:'],
        DEFAULT => [$self->{entry}],);

=head2 OPTIONS

=over 4

=item B<-text> 'string'

Text to put into the Label part of the TDEntry widget.

Default: 'Search'

=back

=cut

    $self->Delegates(DEFAULT => $self->{entry}); # all unknown methods
    $self->Advertise(entry => $self->{entry});

=head2 ADVERTISED SUBWIDGETS

=over 4

=item B<entry>

The Entry widget.

=back

=cut

    return($self);
}

sub initTDEntry {
    my $self = shift;

    # a label widget on the far left
    $self->{label} = $self->Label(
        -text => 'Search:');
    $self->{label}->pack(
        -side => 'left',
        -expand => 'false',
        );
    $self->{entry} = $self->Entry();
    $self->{entry}->pack(
        -side => 'left',
        -expand => 'true',
        -fill => 'x');
    $self->{checkbutton} = $self->Checkbutton(-text => 'Case sensitive',
                                              -variable => \$self->{caseSensitive});
    $self->{checkbutton}->invoke;       # default to case sensitive true
    $self->{checkbutton}->pack(
        -side => 'left',
        -expand => 'false',
        -fill => 'x');
}

=head2 METHODS

=over 4

=item B<case>

Returns the current value of the caseSensitive checkbutton.

=back

=cut

sub case {
    my $self = shift;

    return($self->{caseSensitive});
}

1;

__END__

=head1 SEE ALSO

=over 0

=item o Games::Go::TDFinder

perl/Tk tdfind support widgets

=back

=head1 AUTHOR

Reid Augustin, E<lt>reid@netchip.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004, 2005 by Reid Augustin

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.

=cut

