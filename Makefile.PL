use ExtUtils::MakeMaker;
# $Id: Makefile.PL,v 1.4 2004/07/22 16:47:57 tcaine Exp $

WriteMakefile(
    'NAME'		=> 'Net::IRR',
    'VERSION_FROM'	=> 'lib/Net/IRR.pm',
    'PREREQ_PM'		=> { 
                               Test::More => 0,
                               Net::TCP   => 0,
                               Carp       => 0,
                           },
    (($] ge '5.005') ?
        (   'AUTHOR'   => 'Todd Caine <todd@pobox.com>',
            'ABSTRACT' => 'Perl interface to the Internet Route Registry daemon',
        ) : (),
    ),
);
