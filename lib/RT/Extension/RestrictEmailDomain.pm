
package RT::Extension::RestrictEmailDomain;
use strict;
use warnings;

=head1 NAME

RT::Extension::RestrictEmailDomain - Enforce allowed email domains for Requestor/Cc/AdminCc via callbacks

=head1 DESCRIPTION

Web UI callbacks call C<ValidateEmailAddresses> to block saves when
disallowed emails are present. The Email gateway callback scrubs TicketArgs.

=head1 CONFIGURATION
C<<
Set(@Plugins, qw(
    RT::Extension::RestrictEmailDomain
));

Set(%RestrictEmailDomain,
    AllowedDomains  => ['example.com'], # REQUIRED to activate
    AllowSubdomains => 0,               # 1 to accept foo.bar.example.com
);
>>

=head1 METHODS

=head2 ValidateEmailAddresses($ARGSRef)

Validate (and normalize) Requestor/Cc/AdminCc-related fields in a web request.
Returns a list of error strings; also rewrites disallowed entries out of C<$ARGSRef>.

=cut

=head1 AUTHOR

Grant Emsley, C<< <grant@emsley.ca> >>

=head1 LICENSE AND COPYRIGHT

GNU General Public License, Version 2

=head1 VERSION

Version 1.2.0

=cut

our $VERSION = '1.2.0';



# -----------------------------
# Configuration helpers
# -----------------------------

sub _config {
    my $cfg = RT->Config->Get('RestrictEmailDomain') || {};
    $cfg->{AllowedDomains} ||= [];
    return $cfg;
}

sub allowed_domains {
    my $cfg = _config();
    return @{$cfg->{AllowedDomains} || []};
}

sub allow_subdomains {
    my $cfg = _config();
    return $cfg->{AllowSubdomains} ? 1 : 0;
}

sub enabled {
    return scalar allowed_domains() ? 1 : 0;
}

# -----------------------------
# Policy logic
# -----------------------------

sub email_is_allowed {
    my ($class, $email) = @_;
    return 1 unless $email;       # nothing to validate
    return 1 unless enabled();    # no-op if not configured

    my ($domain) = ($email =~ /@([^@>\s]+)/) ? $1 : undef;
    return 0 unless $domain;

    $domain = lc $domain;
    my $allow_sub = allow_subdomains();

    for my $allowed (allowed_domains()) {
        my $a = lc $allowed;
        return 1 if $domain eq $a;
        return 1 if $allow_sub && $domain =~ /\.\Q$a\E$/;
    }
    return 0;
}

# Parse a value that might be a scalar "a@x, b@y" or an arrayref
sub _as_list {
    my ($class, $v) = @_;
    return () unless defined $v;
    my @vals = ref($v) eq 'ARRAY' ? @$v : ($v);
    my @out;
    for my $s (@vals) {
        next unless defined $s;
        for my $tok (split /[,;\s]+/, $s) {
            $tok =~ s/^\s+|\s+$//g;
            next unless length $tok;
            # strip angle bracket wrapper "Name <email@dom>"
            $tok =~ s/^.*<([^>]+)>\s*$/$1/;
            push @out, $tok;
        }
    }
    return @out;
}

# Filter a list of addresses into (allowed, disallowed)
sub filter_list {
    my ($class, @addrs) = @_;
    my (@ok, @bad);
    for my $e (@addrs) {
        if ($class->email_is_allowed($e)) { push @ok, $e; }
        else                               { push @bad, $e; }
    }
    return (\@ok, \@bad);
}

# Build a human-readable error
sub _error_for {
    my ($class, $type, $bad_list) = @_;
    my $domains = join(', ', allowed_domains());
    my $list    = join(', ', @$bad_list);
    my $suffix  = allow_subdomains() ? " (subdomains allowed)" : "";
    return sprintf(
        "%s contains disallowed domain(s): %s. Allowed: %s%s",
        $type, $list, $domains, $suffix
    );
}

# -----------------------------
# UI validator (used by Mason callbacks)
# -----------------------------
# Returns array of error strings; caller should push into $results and set a skip flag.
sub ValidateEmailAddresses {
    my ($class, $args) = @_;
    return () unless enabled();

    my @errors;

    for my $spec (
        [ 'Requestors',   'Requestor' ],
        [ 'Cc',           'Cc'        ],
        [ 'AdminCc',      'AdminCc'   ],
        # Fields commonly used when modifying people:
        [ 'AddRequestors','Requestor' ],
        [ 'AddCc',        'Cc'        ],
        [ 'AddAdminCc',   'AdminCc'   ],
    ) {
        my ($arg_key, $label) = @$spec;
        next unless exists $args->{$arg_key};
        my @list = $class->_as_list( $args->{$arg_key} );
        next unless @list;

        my ($ok, $bad) = $class->filter_list(@list);
        if (@$bad) {
            push @errors, $class->_error_for($label, $bad);
        }
    }

    return @errors;
}

# -----------------------------
# Email (mailgate) scrubber (used by Email BeforeCreate callback)
# -----------------------------
# $ticket_args is what Email Gateway will pass to Ticket->Create
sub FilterTicketArgs {
    my ($class, $ticket_args) = @_;
    return unless enabled();
    return unless $ticket_args && ref($ticket_args) eq 'HASH';

    for my $key (qw(Requestor Cc AdminCc)) {
        next unless exists $ticket_args->{$key};
        my @list = $class->_as_list( $ticket_args->{$key} );
        my ($ok, $bad) = $class->filter_list(@list);
        $ticket_args->{$key} = $ok;   # Email path expects arrayrefs
        if (@$bad) {
            RT->Logger->info("RestrictEmailDomain: removed $key disallowed: ".join(', ', @$bad));
        }
    }
    return;
}

1;

