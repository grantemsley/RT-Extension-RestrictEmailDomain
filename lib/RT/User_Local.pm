# There are no good callbacks on the modify ticket pages to prevent adding watchers.
# This is an added safeguard to prevent adding outside domains from those pages.

# This alters the email address validation that's used when CREATING A NEW USER.
# Users are created automatically for every person that's ever even CC'ed on a ticket. That leads to lots of garbage in the autocomplete.
# This function prevents such users from being created, which also blocks them from being added as a watcher on a ticket.
# However, this happens AFTER the ticket has been created, and for updates after the form has been submitted, so the user doesn't get a chance to correct it.


package RT::User;

use strict;
use warnings;
no warnings qw(redefine);


use RT::User;

# Override ValidateEmailAddress
sub ValidateEmailAddress {
    my $self  = shift;
    my $Value = shift;
    RT->Logger->debug("RUNNING CUSTOM VALIDATEEMAILADDRESS");

    # null or empty is always valid
    return 1 if (!$Value || $Value eq "");

    if ( RT->Config->Get('ValidateUserEmailAddresses') ) {
        # We only allow one valid email address
        my @addresses = Email::Address->parse($Value);
        return ( 0, $self->loc('Invalid syntax for email address') ) unless ( ( scalar (@addresses) == 1 ) && ( $addresses[0]->address ) );
    }

    unless (RT::Extension::RestrictEmailDomain->email_is_allowed($Value)) {
        RT->Logger->debug("CUSTOM VALIDATEEMAILADDRESS: $Value is NOT OK");
        return ( 0, $self->loc("Email address $Value is not in the allowed domains."));
    } else {
        RT->Logger->debug("CUSTOM VALIDATEEMAILADDRESS: $Value is ok ");
    } 
   
    my $TempUser = RT::User->new(RT->SystemUser);
    $TempUser->LoadByEmail($Value);

    if ( $TempUser->id && ( !$self->id || $TempUser->id != $self->id ) )
    {    # if we found a user with that address
            # it's invalid to set this user's address to it
        return ( 0, $self->loc('Email address in use') );
    } else {    #it's a valid email address
        return (1);
    }
}

1;
