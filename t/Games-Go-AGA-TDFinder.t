#!/usr/bin/perl -w

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Games-Go-TDFinder.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use Test::More tests => 18;
BEGIN {
    use_ok('Games::Go::TDFinder')
};

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

    eval { use Tk; };
is ($@, '',                                     'loading Tk');

    my $mw;
    eval { $mw = MainWindow->new(); };
is ($@, '',                                     'creating main window');

    my $tdFinder;
    eval { $tdFinder = $mw->TDFinder(-tdListFile => undef); };
ok( defined $tdFinder,                          'created new Games::Go::TDFinder object'  );
is( $@, '',                                     '   with no errors,' );
ok( $tdFinder->isa('Games::Go::TDFinder'), '   and it\'s the right class,'  );
    eval { $tdFinder->pack(-expand => 'true',
                       -fill => 'both'); };
is ($@, '',                                     '   and it packed OK.');

    my $tdeText;
    eval { $tdeText = $tdFinder->Subwidget('tdeText'); };
is( $@, '',                                     'found tdeText subwidget' );

    eval { $tdFinder->addPlayer({
                agaNum    => 4444,
                name      => 'Player, A',
                agaRating => '4d',
                club      => '',
                country   => 'ASU',
                comment   => ''}); };
is( $@, '',                                     'added player' );
is( $tdeText->get('1.0', 'end'), 'ASU04444 Player, A                 4d CLUB=Player  # 

',                                              '   correctly');

    eval { $tdFinder->addTDE('TMP02122 Player, Another -2.3 # 12/31/2004'); };
is( $@, '',                                     'added TDE line' );
is( $tdeText->get('1.0', 'end'),
'ASU04444 Player, A                 4d CLUB=Player  # 
TMP02122 Player, Another           2K CLUB=Player  # 12/31/2004

',                                              '   correctly');

    eval { $tdFinder->addTD('Augustin, Reid 2122          5.0 12/31/2004 PALO CA'); };
is( $@, '',                                     'added TDLIST line' );
is( $tdeText->get('1.0', 'end'),
'ASU04444 Player, A                 4d CLUB=Player  # 
TMP02122 Player, Another           2K CLUB=Player  # 12/31/2004
USA02122 Augustin, Reid           5.0 CLUB=PALO   #  12/31/2004 CA

',                                              '   correctly');

    eval { $tdFinder->sort(); };
is( $@, '',                                     'sorted tdeText' );
is( $tdeText->get('1.0', 'end'),
'USA02122 Augustin, Reid           5.0 CLUB=PALO   # 12/31/2004 CA
ASU04444 Player, A                 4D CLUB=Player  # 
TMP02122 Player, Another           2K CLUB=Player  # 12/31/2004

',                                              '   correctly');

    eval { $tdFinder->clear(); } ;
is( $@, '',                                     'cleared tdeText' );
is( $tdeText->get('1.0', 'end'), "\n",          '   correctly');
