
use strict;
use warnings;
use RT::Test tests => 7, web => 1;

RT->Config->Set( RestrictEmailDomain => {
    AllowedDomains  => ['example.com'],
    AllowSubdomains => 0,
});

my ($baseurl, $m) = RT::Test->started_ok;
ok($m->login, 'logged in');

# Create Queue
my $cu = RT::CurrentUser->new; $cu->LoadByName('root');
my $q = RT::Queue->new($cu); my ($qid) = $q->Create(Name => 'General');
ok($qid, 'queue created');

# Attempt create with bad CC
$m->get_ok("$baseurl/Ticket/Create.html?Queue=$qid");
$m->submit_form(
    with_fields => {
        Subject    => 'Bad watchers',
        Requestors => 'alice\@example.com',
        Cc         => 'bob\@bad.org, carol\@example.com',
    },
    button => 'Create',
);

$m->content_like(qr/disallowed domain/i, 'blocked save with error');
$m->content_contains('Allowed: example.com', 'error lists allowed domain');

# Now fix CC and create
$m->submit_form(
    with_fields => {
        Subject    => 'Good watchers',
        Requestors => 'alice\@example.com',
        Cc         => 'carol\@example.com',
    },
    button => 'Create',
);

$m->content_like(qr/Ticket \#\d+ created/i, 'ticket created');
