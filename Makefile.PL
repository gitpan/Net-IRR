use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Net::IRR',
    'VERSION_FROM'	=> 'lib/Net/IRR.pm',
    'PREREQ_PM'		=> { 
                               Test::More => 0,
                               Net::TCP   => 0,
                           },
);
