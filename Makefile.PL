
use strict;
use warnings;

# Use RT's packaging helper for proper plugin install paths
use inc::Module::Install;
use Module::Install::RTx;

RTx 'RT-Extension-RestrictEmailDomain';
name 'RT-Extension-RestrictEmailDomain';
license 'gpl_2';
repository 'https://github.com/grantemsley/RT-Extension-RestrictEmailDomain';
requires_rt '6.0.2';

sign;
WriteAll;

