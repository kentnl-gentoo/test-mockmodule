# $Id: MockModule.pm,v 1.2 2004/11/29 00:53:57 simonflack Exp $
package Test::MockModule;
use strict qw/subs vars/;
use vars qw/$VERSION/;
use Scalar::Util 'weaken';
use Carp;
$VERSION = '0.02';#sprintf'%d.%02d', q$Revision: 1.2 $ =~ /: (\d+)\.(\d+)/;

my %mocked;
sub new {
    my $class = shift;
    my ($package, %args) = @_;
    if (my $existing = $mocked{$package}) {
        return $existing;
    }

    croak "Cannot mock $package" if $class eq $package;
    croak "Invalid package name $package" unless _valid_package($package);

    unless ($args{no_auto} || ${"$package\::VERSION"}) {
        (my $load_package = "$package.pm") =~ s{::}{/}g;
        TRACE("$package is empty, loading $load_package");
        require $load_package;
    }

    TRACE("Creating MockModule object for $package");
    my $self = bless {
        _package => $package,
        _mocked  => {},
    }, $class;
    $mocked{$package} = $self;
    weaken $mocked{$package};
    return $self;
}

sub DESTROY {
    my $self = shift;
    $self->unmock_all;
}

sub get_package {
    my $self = shift;
    return $self->{_package};
}

sub mock {
    my $self = shift;

    while (my ($name, $code) = splice @_, 0, 2) {
        $code ||= sub {};
        TRACE("$name: $code");
        croak "Invalid subroutine name: $name" unless _valid_subname($name);
        my $sub_name = _full_name($self, $name);
        if (!$self->{_mocked}{$name}) {
            TRACE("Storing existing $sub_name");
            $self->{_mocked}{$name} = 1;
            $self->{_orig}{$name}   = $self->{_package}->can($name)
                                   || \&{$sub_name};
        }
        TRACE("Installing mocked $sub_name");
        _replace_sub($sub_name, $code);
    }
}

sub original {
    my $self = shift;
    my ($name) = @_;
    return carp _full_name($self, $name) . " is not mocked"
            unless $self->{_mocked}{$name};
    return $self->{_orig}{$name};
}

sub unmock {
    my $self = shift;
    my ($name) = @_;
    croak "Invalid subroutine name: $name" unless _valid_subname($name);

    my $sub_name = _full_name($self, $name);
    unless ($self->{_mocked}{$name}) {
        carp $sub_name . " was not mocked";
        return;
    }

    TRACE("Restoring original $sub_name");
    _replace_sub($sub_name, $self->{_orig}{$name});
    delete $self->{_mocked}{$name};
    delete $self->{_orig}{$name};
}

sub unmock_all {
    my $self = shift;
    foreach (keys %{$self->{_mocked}}) {
        $self->unmock($_);
    }
}

sub is_mocked {
    my $self = shift;
    my ($name) = shift;
    return $self->{_mocked}{$name};
}

sub _full_name {
    my ($self, $sub_name) = @_;
    sprintf "%s::%s", $self->{_package}, $sub_name;
}

sub _valid_package {
    defined($_[0]) && $_[0] =~ /^[a-z_]\w*(?:::\w+)*$/i;
}

sub _valid_subname {
    $_[0] =~ /^[a-z_]\w*$/i;
}

sub _replace_sub {
    my ($sub_name, $coderef) = @_;
    # from Test::MockObject
    local $SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };
    *{$sub_name} = $coderef;
}

sub TRACE {0 && print STDERR "@_\n"}
sub DUMP  {}

1;

=pod

=head1 NAME

Test::MockModule - Override subroutines in a module for unit testing

=head1 SYNOPSIS

   use Module::Name;
   use Test::MockModule;

   {
       my $module = new Test::MockModule('Module::Name');
       $module->mock('subroutine', sub { ... });
       Module::Name::subroutine(@args); # mocked
   }

   Module::Name::subroutine(@args); # original subroutine

=head1 DESCRIPTION

C<Test::MockModule> lets you temporarily redefine subroutines in other packages
for the purposes of unit testing.

A C<Test::MockModule> object is set up to mock subroutines for a given
module. The object remembers the original subroutine so it can be easily
restored. This happens automatically when all MockModule objects for the given
module go out of scope, or when you C<unmock()> the subroutine explicitly.

=head1 METHODS

=over 4

=item new($package[, %options])

Returns an object that will mock subroutines in the specified C<$package>.

If there is no C<$VERSION> defined in C<$package>, the module will be
automatically loaded. You can override this behaviour by setting the C<no_auto>
option:

    my $mock = new Test::MockModule('Module::Name', no_auto => 1);

=item get_package()

Returns the target package name for the mocked subroutines

=item is_mocked($subroutine)

Returns a boolean value indicating whether or not the subroutine is currently
mocked

=item mock($subroutine[, \&coderef])

Temporarily replaces C<$subroutine> with the supplied C<E<amp>coderef>. The
code reference is optional, and defaults to an empty subroutine if omitted.

You can call C<mock()> for the same subroutine many times, but when you call
C<unmock()>, the original subroutine is restored (not the last mocked
instance).

=item original($subroutine)

Returns the original (unmocked) subroutine

=item unmock($subroutine)

Restores the original C<$subroutine>

=item unmock_all()

Restores all the subroutines in the package that were mocked. This is
automatically called when all C<Test::MockObject> objects for the given package
go out of scope.

=back

=head1 SEE ALSO

L<Test::MockObject::Extends>

=head1 AUTHOR

Simon Flack E<lt>simonflk _AT_ cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2004 Simon Flack E<lt>simonflk _AT_ cpan.orgE<gt>.
All rights reserved

You may distribute under the terms of either the GNU General Public License or
the Artistic License, as specified in the Perl README file.

=cut
