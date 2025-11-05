
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'RT::Extension::RestrictEmailDomain',
    VERSION_FROM => 'lib/RT/Extension/RestrictEmailDomain.pm',
    ABSTRACT     => 'Restrict Requestor/Cc/AdminCc domains via callbacks (UI + mailgate)',
    AUTHOR       => 'IT Team <it@example.com>',
    LICENSE      => 'perl',
    PREREQ_PM    => {},
);
