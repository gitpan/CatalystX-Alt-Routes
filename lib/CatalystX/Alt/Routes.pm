#
# This file is part of CatalystX-Alt-Routes
#
# This software is Copyright (c) 2011 by Chris Weyl.
#
# This is free software, licensed under:
#
#   The GNU Lesser General Public License, Version 2.1, February 1999
#
package CatalystX::Alt::Routes;
{
  $CatalystX::Alt::Routes::VERSION = '0.001'; # TRIAL
}

# ABSTRACT: A DSL for declaring controller paths

use strict;
use warnings;

use Hash::MultiValue;
use Moose::Exporter;

Moose::Exporter->setup_import_methods(
    with_meta => [
        qw( private global public ),
        (map { "${_}_action" } qw{ default index begin end auto }),
    ],
    as_is => [
        qw(
            before_action after_action template tweak_stash
            chained args capture_args path_name path_part action_class
        ),
        (map { "menu_$_" } qw{ label parent args cond order roles title }),
    ],
);

# start-points
sub public  { _add_path([ Path    => $_[1] ], @_) }
sub private { _add_path([ Private => 1     ], @_) }
sub global  { _add_path([ Global  => 1     ], @_) }

# special actions
sub default_action(&) { _add_path([ path_name(q{})             ], shift, 'default', @_) }
sub index_action(&)   { _add_path([ path_name(q{}), args(0)    ], shift, 'index',   @_) }
sub begin_action(&)   { _add_path([                            ], shift, 'begin',   @_) }
sub end_action(&)     { _add_path([ action_class('RenderView') ], shift, 'end',     @_) }
sub auto_action(&)    { _add_path([                            ], shift, 'auto',    @_) }

# experimental - beore/after wrappers for our action method
sub before_action(&) { ( _before => $_[0] ) }
sub after_action(&)  { ( _after  => $_[0] ) }

#sub template($)    { my $t = shift; (_before => sub    { $_[1]->stash-> { template} = $t }) }
sub tweak_stash($$) { my ($k, $v) = @_; (_before => sub { $_[1]->stash-> { $k} = $v })       }
sub template($)     { tweak_stash(template => $_[0])                                         }

# standard atts
sub chained($)      { _att(Chained     => @_) }
sub args($)         { _att(Args        => @_) }
sub capture_args($) { _att(CaptureArgs => @_) }
sub path_part($)    { _att(PathPart    => @_) }
sub path_name($)    { _att(Path        => @_) }
sub action_class($) { _att(ActionClass => @_) }

# Catalyst::Plugin::Navigation specific bits
sub menu_label($)  { _att(Menu       => @_) }
sub menu_parent($) { _att(MenuParent => @_) }
sub menu_args($)   { _att(MenuArgs   => @_) }
sub menu_cond($)   { _att(MenuCond   => @_) }
sub menu_order($)  { _att(MenuOrder  => @_) }
sub menu_roles($)  { _att(MenuRoles  => @_) }
sub menu_title($)  { _att(MenuTitle  => @_) }

sub _att { ( shift(@_) => [ @_ ] ) }

sub _add_path {
    my ($path, $meta, $name, @args) = @_;
    my $sub = pop @args;

    # XXX squash them down before adding to config
    #my $action_attributes = { @$path, @args };
    my $action_attributes = Hash::MultiValue->new(@$path, @args);

    my @before = $action_attributes->get_all('_before');
    delete $action_attributes->{'_before'};
    my @after = $action_attributes->get_all('_after');
    delete $action_attributes->{'_after'};

    # so there's two ways (I know of) to proceed here...  The first (and the
    # one we use) is to poke at our class' config() and establish our actions
    # here.  The second would be to fiddle with the method's metaclass to add
    # attributes to it.  Both allow the standard action discovery to work, but
    # the config method seems a little less magical, so that's what we're
    # using right now.
    #
    # ...and by "less magical" I mean "without the additional metaclass
    # tinkering that would be necessary".

    $meta->name->config->{actions}->{$name} = $action_attributes;

    # handle either a method name or a coderef to be installed
    # XXX broken
    $meta->add_method($name => sub { goto &$sub })
        if (ref $sub || 'nope') eq 'CODE';

    $meta->add_before_method_modifier($name => $_)
        for @before;
    $meta->add_after_method_modifier($name => $_)
        for @after;

    return;
}

!!42;



=pod

=head1 NAME

CatalystX::Alt::Routes - A DSL for declaring controller paths

=head1 VERSION

version 0.001

=head1 SYNOPSIS

    package MyApp::Controller::Foo;

    use Moose;
    use namespace::autoclean;
    use CatalystX::Alt::Routes;

    extends 'Catalyst::Controller';

    # aka: sub index : Path(q{}) Args(0) { ... }
    index_action { ... do something indexy here ... };

    public list
        => args 1
        => template 'other_list.tt2'
        => sub {
            my ($self, $c) = @_;

            ... something listy here ...
    };


    private something

=head1 DESCRIPTION

This package exports sugar that allows paths to be declared
without having to hew to any of the requirements of attributes. Note that this
is an _alternate_ way to declare paths; you can still use the standard approach
without fear or reprisal.

We provide common shortcuts to common "special" actions (index, default, etc)
as well as some helpers for commonly-used packages.

=head1 SPECIAL ACTIONS

These all take one argument, a coderef; e.g.

    index_action { ... do something indexy ... };

=head2 index_action

=head2 default_action

=head2 begin_action

=head2 end_action

=head2 auto_action

=head1 ACTIONS

=head2 public

=head2 private

=head2 global

=head1 ACTION PARAMETERS

Probably not the best name for this.

=head1 NAVIGATION/MENU PARAMETERS

We also include support for defining menu attributes that can be used by
L<Catalyst::Plugin::Navigation>.

=head1 BEGIN BLOCKS

It's good practice to wrap any "extends" in your controller classes --
essential if you're using the standard approach of method attributes to define
your routes.

If you're using this package exclusively to define actions, you do not need to
use a BEGIN block.  Note I'm not recommending this, just stating that it's
possible -- and if something breaks, you get to keep all the pieces :)

=head1 SEE ALSO

This package is largely inspired by (and steals parts of) L<CatalystX::Routes>.

=head1 BUGS

All complex software has bugs lurking in it, and this module is no exception.

Please report any bugs to
"bug-CatalystX-Alt-Routes@rt.cpan.org",
or through the web interface at <http://rt.cpan.org>.

Patches and pull requests through GitHub are most welcome; our page and repo
(same URI):

    https://github.com/RsrchBoy/catalystx-alt-routes

=head1 AUTHOR

Chris Weyl <cweyl@alumni.drew.edu>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2011 by Chris Weyl.

This is free software, licensed under:

  The GNU Lesser General Public License, Version 2.1, February 1999

=cut


__END__

