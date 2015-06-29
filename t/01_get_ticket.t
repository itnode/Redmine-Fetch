use strict;
use Test::More 0.98;

use Redmine::Fetch;

done_testing unless $ENV{RF_SERVER} && $ENV{RF_API_KEY}, $ENV{RF_PROJECT_ID}, $ENV{RF_FILTER}, $ENV{RF_TICKET_ID};

use DDP;

my $rf = Redmine::Fetch->new( $ENV{RF_SERVER}, $ENV{RF_API_KEY}, $ENV{RF_PROJECT_ID}, $ENV{RF_FILTER} );

my $link_callback = sub { return "/path/to/".shift; };

my $ticket = $rf->get_ticket_by_id($ENV{RF_TICKET_ID}, $link_callback);

p $ticket;

ok($ticket->{assigned_to}, 'ticket received');


done_testing;

