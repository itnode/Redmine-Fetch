package Redmine::Fetch;
use 5.008001;
use strict;
use warnings;

our $VERSION = "0.01";

use DateTime;

use Mojo::UserAgent;
use DDP;

my $_config;

sub new {

    my ( $self, $server, $api_key, $project_id, $filter ) = @_;

    $_config = {
        server     => $server,
        api_key    => $api_key,
        project_id => $project_id,
        filter     => $filter,
    };

    return $self;
}

sub ua_config {

    my ( $self ) = @_;

    return $_config;
}

sub redmine_ua {

    my ( $self, $mode, $call, $payload ) = @_;

    my $config = $self->ua_config;

    my $response = '';

    eval {

        my $header = { "X-Redmine-API-Key" => $config->{api_key} };

        my $ua = Mojo::UserAgent->new;

        my $tx = '';

        if ( $mode eq 'put' ) {

            $tx = $ua->put( $config->{server} . '/' . $call . '.json' => $header => json => $payload );

        } elsif ( $mode eq 'delete' ) {

            $tx = $ua->delete( $config->{server} . '/' . $call . '.json' => $header );

        } elsif ( $mode eq 'post' ) {

            my $params = { project_id => $config->{project_id}, };

            my $combined_payload = { %$payload, %$params };

            $tx = $ua->post( $config->{server} . '/' . $call . '.json' => $header => form => $combined_payload );

        } else {

            my $params = { project_id => $config->{project_id}, };

            my $combined_payload = { %$payload, %$params };

            $tx = $ua->get( $config->{server} . '/' . $call . '.json' => $header => form => $combined_payload );
        }

        if ( my $res = $tx->success ) {
            $response = $res->json;
        } else {
            warn 'fail';
            p $tx->body;
            my $err = $tx->error;
            die "$err->{code} response: $err->{message}" if $err->{code};
            die "Connection error: $err->{message}";
        }

    };

    return $response;
}

sub update_or_create_wiki_page {

    my ( $self, $project_name, $path, $name, $content, $parent_title, $comment ) = @_;
    $parent_title ||= '';

    my $attach = { wiki_page => { title => $name, text => $content, comments => $comment || "automaticly generated by Redmine::Fetch", parent_title => $parent_title } };

    my $call = 'projects/' . $project_name . '/wiki/' . $path;

    my $response = $self->redmine_ua( 'put', $call, $attach );

    return $response;

}

sub delete_wiki_page {

    my ( $self, $project_name, $path ) = @_;

    my $call = 'projects/' . $project_name . '/wiki/' . $path;

    my $response = $self->redmine_ua( 'delete', $call, '' );

    return $response;
}

sub get_tickets {

    my ( $self, $params ) = @_;

    $params->{tracker_id} ||= 1;
    $params->{limit}      ||= 500;
    $params->{sort}       ||= 'created_on:desc';

    if ( my $filter = $self->ua_config->{filter} ) {
        $params->{cf_3} = $filter;
    }

    my $tickets = { issues => [] };

    $params->{status_id} = join( "|", @{ $params->{states} } );

    $tickets = $self->redmine_ua( 'get', 'issues', $params );

    return $tickets->{issues};
}

sub create_ticket {

    my ( $self, $subject, $description, $payload ) = @_;

    my $default_payload = { subject => $subject, description => $description };

    $payload = { %$default_payload, %$payload };

    my $response = $self->redmine_ua( 'post', 'issues', $payload );

    return $response;

}


sub get_ticket_by_id {

    my ( $self, $ticket_id, $build_link_callback ) = @_;

    my $params = {

        include => 'relations',
    };

    my $ticket = $self->redmine_ua( 'get', 'issues/' . $ticket_id, $params );

    $ticket = $ticket->{issue};

    $ticket->{description} =~ s/(\#)(\d+)/'<a href="' . $build_link_callback->($2) . '">'.$1.$2.'<\/a>'/ge;

    $ticket->{related_tickets} = [];

    if ( $ticket->{relations} ) {

        foreach my $relation ( @{ $ticket->{relations} } ) {

            next if $relation->{relation_type} ne 'relates';

            my $relation_id = ( $ticket->{id} == $relation->{issue_id} ) ? $relation->{issue_to_id} : $relation->{issue_id};

            my $related_ticket = $self->redmine_ua( 'get', 'issues/' . $relation_id, {} );

            push @{ $ticket->{related_tickets} }, $related_ticket->{issue};
        }
    }

    return $ticket;
}


1;

__END__

=encoding utf-8

=head1 NAME

Redmine::Fetch - It's new $module

=head1 SYNOPSIS

    use Redmine::Fetch;

    my $rf = Redmine::Fetch->new( $server_uri, $api_key, $project_id, $filter);
    my $ticket = $rf->get_ticket_by_id(555);

=head1 DESCRIPTION

This module provides API access to the Redmine REST API

Please reference the Redmine API docs to determine Parameters for Filters etc.

You can find the docs here: http://www.redmine.org/projects/redmine/wiki/Rest_api

=head2 new

Creates a new Object. Handle over the Redmine Config

=over

=item * param: $api_key String - API Key for Redmine

=item * param: $project_id Integer - Redmine Project ID

=item * param: $filter String - Redmine filter string

=item * returns: $self Object - Redmine::Fetch object

=back

=head2 ua_config

Returns a config hashref for the Redmine REST API.

=over

=item * returns: $c Hash - Config Hash for the Redmine REST API

=back

=head2 redmine_ua

Redmine Useragent. Abstracts PUT und GET Requests for the Redmine Rest API. Will dump errors per Data::Printer

=over

=item * param: $mode String - 'get' || 'put' || 'delete' || 'post'

=item * param: $call String - calling API path

=item * param: $payload Hash || JSON - payload for PUT or GET request

=item * returns: $response Mojo::UserAgent Response - Antwort Objekt der Transaktion oder leerer String

=back

=head2 update_or_create_wiki_page

Update or create Wiki pages in Redmine Wiki

=over

=item * param: $path String - Path to Wiki page

=item * param: $name String - name of Wiki page

=item * param: $content String - Content of the Wiki Page in Textile Markup

=item * param: $parent_titel - Title of the parent Wiki Page

=item * returns: $response Mojo::UserAgent Response - Server answer, for further processing or empty String

=back

=head2 delete_wiki_page

deletes Wiki Page

=over

=item * param: $path String - path to delete

=item * returns: $response Mojo::UserAgent Response - Server answer, for further processing or empty String

=back

=head2 create_ticket

create ticker in Redmine Tracker

=over

=item * param: $subject String - Subject of the Ticket

=item * param: $description String - Description of the Ticket

=item * param: $payload String - additional Ticket parameters as a hash (e.g. tracker_id, priority, etc.)

=item * returns: $response Mojo::UserAgent Response - Server answer, for further processing or empty String

=back

=head2 get_tickets

get list of Tickets

=over

=item * param: $type String - Tracker Typ - e.g. [ bugs, features, updates, faq ]

=item * param: $limit Scalar - maximal number of Listitems - default 500

=item * param: $sort String - sort for Redmine API as String

=item * returns: $ticket Hash - From json decoded hashref with ticket_data

=back

=head2 get_ticket_by_id

gets a Ticket by ID including the related Tickets

=over

=item * param: $ticket_id Scalar - Ticket ID in Redmine

=item * param: $build_link_callback - Anonymus function for URI generating

=item * returns: $ticket Hash - From json decoded hashref with ticket_data

=back

=head1 LICENSE

Copyright (C) Jens Gassmann Software Entwicklung.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

=over

=item * Jens Gassmann E<lt>jg@itnode.deE<gt>

=item * Patrick Simon E<lt>ps@itnode.deE<gt>

=back

=cut

