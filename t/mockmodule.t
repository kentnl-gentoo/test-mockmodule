#!/usr/bin/perl -w
use strict;
use Test::More tests => 29;

require_ok('Test::MockModule');

package Test_Package;
our $VERSION=1;
sub listify {
    my ($lower, $upper) = @_;
    return ($lower .. $upper);
}
package main;

# new()
ok(Test::MockModule->can('new'), 'new()');
eval {Test::MockModule->new('Test::MockModule')};
like($@, qr/Cannot mock Test::MockModule/, '... cannot mock itself');
eval {Test::MockModule->new('12Monkeys')};
like($@, qr/Invalid package name/, ' ... croaks if package looks invalid');

{
    {
        Test::MockModule->new('CGI', no_auto => 1);
        ok(!$INC{'CGI.pm'}, '... no_auto prevents module being loaded');
    }
    my $mcgi = Test::MockModule->new('CGI');
    ok($INC{'CGI.pm'}, '... module loaded if !$VERSION');
    ok($mcgi->isa('Test::MockModule'), '... returns a Test::MockModule object');
    my $mcgi2 = Test::MockModule->new('CGI');
    is($mcgi, $mcgi2,
       "... returns existing object if there's already one for the package");

    # get_package()
    ok($mcgi->can('get_package'), 'get_package');
    is($mcgi->get_package, 'CGI', '... returns the package name');

    # mock()
    ok($mcgi->can('mock'), 'mock()');
    eval {$mcgi->mock(q[p-ram])};

    like($@, qr/Invalid subroutine name: /,
        '... dies if a subroutine name is invalid');

    my $orig_param = \&CGI::param;
    $mcgi->mock('param', sub {return qw(abc def)});
    my @params = CGI::param();
    is_deeply(\@params, ['abc', 'def'],
        '... replaces the subroutine with a mocked sub');

    $mcgi->mock('param');
    @params = CGI::param();
    is_deeply(\@params, [], '... which is an empty sub if !defined');

    # original()
    ok($mcgi->can('original'), 'original()');
    is($mcgi->original('param'), $orig_param,
       '... returns the original subroutine');
    my ($warn);
    local $SIG{__WARN__} = sub {$warn = shift};
    $mcgi->original('Vars');
    like($warn, qr/ is not mocked/, "... warns if a subroutine isn't mocked");

    # unmock()
    ok($mcgi->can('unmock'), 'unmock()');
    eval {$mcgi->unmock('V@rs')};
    like($@, qr/Invalid subroutine name/,
         '... dies if the subroutine is invalid');

    $warn = '';
    $mcgi->unmock('Vars');
    like($warn, qr/ was not mocked/, "... warns if a subroutine isn't mocked");

    $mcgi->unmock('param');
    is(\&{"CGI::param"}, $orig_param, '... restores the original subroutine');

    # unmock_all()
    ok($mcgi->can('unmock_all'), 'unmock_all');
    $mcgi->mock('Vars' => sub {1}, param => sub {2});
    ok(CGI::Vars() == 1 && CGI::param() == 2,
       'mock: can mock multiple subroutines');
    my @orig = ($mcgi->original('Vars'), $mcgi->original('param'));
    $mcgi->unmock_all();
    ok(\&CGI::Vars eq $orig[0] && \&CGI::param eq $orig[1],
       '... removes all mocked subroutines');

    # is_mocked()
    ok($mcgi->can('is_mocked'), 'is_mocked');
    ok(!$mcgi->is_mocked('param'), '... returns false for non-mocked sub');
    $mcgi->mock('param', sub { return 'This sub is mocked' });
    is(CGI::param(), 'This sub is mocked', '... mocked params');
    ok($mcgi->is_mocked('param'), '... returns true for non-mocked sub');
}

isnt(CGI::param(), 'This sub is mocked',
     '... params is unmocked when object goes out of scope');
