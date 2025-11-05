
use strict;
use warnings;
use RT::Test tests => 8, web => 1;

RT->Config->Set( RestrictEmailDomain => {
    AllowedDomains  => ['example.com'],
    AllowSubdomains => 0,
});

my ($baseurl, $m) = RT::Test->started_ok;
ok($m->login, 'logged in');

# Create a ticket cleanly
my $cu = RT::CurrentUser->new; $cu->LoadByName('root');
my $q  = RT::Queue->new($cu); my ($qid) = $q->Create(Name => 'People');
ok($qid, 'queue created');

my $t = RT::Ticket->new($cu);
my ($tid) = $t->Create( Queue=>$qid, Subject=>'Modify People', Requestor=>['good\@example.com'] );
ok($tid, 'ticket created');

# Try to add a bad AdminCc via ModifyPeople
$m->get_ok("$baseurl/Ticket/ModifyPeople.html?id=$tid");
$m->submit_form(
    with_fields => {
        AddAdminCc => 'x\@outside.net, y\@example.com',
    },
    button => 'Submit',
);

$m->content_like(qr/disallowed domain/i, 'blocked update on bad AdminCc');

# Fix and submit again
$m->submit_form(
    with_fields => { AddAdminCc => 'y\@example.com' },
    button => 'Submit',
);

$m->content_like(qr/Updated/i, 'update succeeded');
