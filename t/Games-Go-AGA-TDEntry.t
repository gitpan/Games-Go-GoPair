#!/usr/bin/perl -w

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Games-Go-AGA-TDEntry.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use Test::More tests => 10;
BEGIN {
    use_ok('Games::Go::TDEntry')
};

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

    eval { use Tk; };
is ($@, '',                                     'loading Tk');

    my $mw;
    eval { $mw = MainWindow->new(); };
is ($@, '',                                     'creating main window');

    my $tdEntry;
    eval { $tdEntry = $mw->TDEntry; };
ok( defined $tdEntry,                           'created new Games::Go::TDEntry object'  );
is( $@, '',                                     '   with no errors,' );
ok( $tdEntry->isa('Games::Go::TDEntry'),   '   and it\'s the right class,'  );
    eval { $tdEntry->pack(-expand => 'true',
                       -fill => 'both'); };
is ($@, '',                                     '   and it packed OK.');

    my $entry;
    eval { $entry = $tdEntry->Subwidget('entry'); };
is( $@, '',                                     'found entry subwidget' );

is( $entry->get(), '',                          'cleared' );
is( $tdEntry->case(), 1,                        'case sensitive is set' );
