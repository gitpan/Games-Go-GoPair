use 5.002;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

eval { require Math::Libm; };   # is this module available?
if ($@) {
    print "\nMath::Libm not available\n",
          "  I'll install Games::Go::Erf, but if you install Math:Libm, I'll use that and the\n",
          "  'rats' (ratings calculations) script will run three times faster!\n\n";

}

WriteMakefile(
    NAME              => 'Games::Go::GoPair',
    # VERSION_FROM      => 'GoPair.pm', # finds $VERSION
    VERSION           => 1.001,
    PREREQ_PM         => {Tk => 804.000,
                          Games::Go::AGATourn => 1.0,
                          Algorithm::Pair::Best => 1.0,
                          Digest::SHA1 => 0}, # e.g., Module::Name => 1.1
    EXE_FILES         => [qw(tdfind aradjust gopair randresult tscore send2aga rats)],
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT       => 'Modules, widgets, and scripts for running an AGA go tournament',
       AUTHOR         => 'Reid Augustin <reid@netchip.com>') : ()),
);
