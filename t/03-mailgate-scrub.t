
use strict;
use warnings;
use RT::Test tests => 6;

RT->Config->Set( RestrictEmailDomain => {
    AllowedDomains  => ['example.com'],
    AllowSubdomains => 0,
});

my ($baseurl, $m) = RT::Test->started_ok;

# Create queue
my $cu = RT::CurrentUser->new; $cu->LoadByName('root');
my $q  = RT::Queue->new($cu); my ($qid) = $q->Create(Name => 'Mail');
ok($qid, 'queue created');

# Send email: From (bad), Cc (mixed)
my $mail = <<'EOF';
From: badguy@bad.org
To: rt@example.com
Cc: ok@example.com, nope@elsewhere.net
Subject: Mail test

Hello.
EOF

my $tid = RT::Test->send_via_mailgate($mail, queue => 'Mail');
ok($tid, "ticket created via mailgate: $tid");

my $t = RT::Ticket->new($cu); $t->Load($tid);
ok($t->Id, 'loaded');

# Requestors should be empty (bad From removed)
my $req = $t->Requestors->UserMembersObj;
my @r; while ( my $u = $req->Next ) { push @r, $u->EmailAddress if $u->EmailAddress }
is_deeply(\@r, [], 'bad requestor removed');

# Cc should only contain ok@example.com
my $cc = $t->Cc->UserMembersObj;
my @c; while ( my $u = $cc->Next ) { push @c, $u->EmailAddress if $u->EmailAddress }
is_deeply([sort @c], ['ok@example.com'], 'Cc scrubbed correctly');
