package Test::Builder2::Result;

use Carp;
use Test::Builder2::Mouse;
use Test::Builder2::Types;

with 'Test::Builder2::Event';

my $CLASS = __PACKAGE__;


=head1 NAME

Test::Builder2::Result - The result of an assert

=head1 SYNOPSIS

    use Test::Builder2::Result;

    my $result = Test::Builder2::Result->new(
        pass    => 1+1==2,
        name    => "simple addition"
    );


=head1 DESCRIPTION

An object to store the result of an assert.  Used to keep test
history, format the results of tests, and build up diagnostics about a
test.


=head2 Overloading

Result objects are overloaded to return true if the result is not a
failure, false otherwise.

=cut

use overload(
    q{bool} => sub {
        my $self = shift;
        return !$self->count_as_failure;
    },
    fallback => 1,
);


=head2 Construction

    my $result = Test::Builder2::Result->new(%args);

Creates a new result object.  %args are the L<Attributes> below with
the following additions...

If C<pass> is true, it's the same as C<< result => "pass" >>.  If it's
false, C<< result => "fail" >>.

If C<skip> is given, the test is considered a skip.  The value is the
reason for the skip.

If C<todo> is given the test is considered "todo" and the result is
ignored.  The value is the reason for being todo.

=cut

sub BUILDARGS {
    my $class = shift;
    my %args = @_;

    my @only_one = qw( result pass skip );
    my @got = grep { exists $args{$_} } @only_one;
    if( @got > 1 ) {
        croak sprintf "%s->new was given %s but can only be given one of %s",
          $class, join(" and ", @got), join(", ", @only_one);
    }

    if( !$args{result} ) {
        if( exists $args{pass} ) {
            $args{result} = delete $args{pass} ? "pass" : "fail";
        }
        elsif( exists $args{skip} ) {
            $args{result} = "skip";
            $args{directives}{skip} = delete $args{skip};
        }
    }

    if( exists $args{todo} ) {
        $args{directives}{todo} = delete $args{todo};
    }

    for my $diag (qw(have want cmp)) {
        next unless exists $args{$diag};
        $args{diag}{$diag} = delete $args{$diag};
    }

    return \%args;
}


=head2 Attributes

=head3 result

The result of the assert.

This can be "pass", "fail" or "skip" indicating the assert passed,
failed or was deliberately not run because it would make no sense in
the current environment.

This is required.

=cut

has result =>
  is            => 'rw',
  isa           => "Test::Builder2::Result::results",
  required      => 1,
;


=head3 name

The human readable name of the assert.  For example...

    # The name is "addition"
    ok( 1 + 1, "addition" );

=cut

has name =>
  is            => 'rw',
  isa           => 'Test::Builder2::Label',
  default       => '',
  coerce        => 1,
;
  

=head3 file

The file where this assert was run.

Like L<line>, this represents the top of the assert stack.

=cut

has file =>
  is            => 'rw',
  isa           => 'Str',
;


=head3 line

The line number upon which this assert was run.

Because a single result can represent a stack of actual asserts, this
is generally the location of the first assert in the stack.

=cut

has line =>
  is            => 'rw',
  isa           => 'Test::Builder2::Positive_Int'
;


=head3 have

=head3 want

=head3 cmp

This is information about the assert which generated the result
expressed as a comparison between the actual value you C<have>, the
value you C<want> and what operation was used to compare them
(C<cmp>).

Not all asserts fall into this pattern, and those will have no values,
but many do.  For example, C<like> would be

    have: "some string"
    want: (?-xism:some pattern)
    cmp:  =~

These are just convenience accessors for C<< $result->diag->{have} >>
and so on.

=cut

for my $key (qw(have want cmp)) {
    my $code = sub {
        my $self = shift;
        if( @_ ) {
            $self->diag->{$key} = shift;
            return;
        }
        else {
            return $self->diag->{$key};
        }
    };

    no strict 'refs';
    *{$key} = $code;
}


=head3 diag

The structured diagnostics associated with this result.

Use it to store any additional information about the assert that
doesn't fit into existing attributes.

Contains a hash ref.  Don't overwrite the hash ref, just add to it.

For convenience adding a lot of keys, see L<add_diag>.

=cut

has diag =>
  is            => 'ro',
  isa           => 'HashRef',
  lazy          => 1,
  default       => sub { {} },
;


=head3 test_number

The number associated with this test, if any.

B<NOTE> that most testing systems don't number their results.  And
even TAP tests are not required to do so.

=cut

has test_number =>
  is            => 'rw',
  isa           => 'Int'
;


=head3 directives

Directives are additional flags which might modify the meaning of the
result.

Currently the only directive is "todo" which indicates that the test
is expected to fail and should not cause the test suite to fail.

Each directive is a key indicating the type of directive and a value
which is a reason for its being applied.  For example...

    $result->directives->{todo} = "bug #1398";

By convention, all directives should be lower cased.

=cut

has directives =>
  is            => 'ro',
  isa           => 'HashRef',
  default       => sub { {} }
;


=head2 Methods

=head3 new

  my $result = Test::Builder2::Result->new(%test_data);

=head3 event_type

    my $type = $result->event_type;

Returns the type of this Event, for differenciation between other
Event objects.

The type is "result".

=cut

sub event_type { return "result" }


=head3 as_hash

    my $hash = $self->as_hash;

Returns the attributes of a result as a hash reference.

Useful for quickly dumping the contents of a result.

=cut

my @attributes = qw(result name file line diag test_number directives);
sub as_hash {
    my $self = shift;
    return {
        map {
            my $val = $self->$_();
            defined $val ? ( $_ => $val ) : ()
        } @attributes, "event_type"
    };
}


=head3 passed

Returns true if the assert passed.

Note: a skip is NOT considered to have passed.  See
L<count_as_failure>.

=cut

sub passed {
    return $_[0]->result eq 'pass';
}

=head3 failed

Returns true of the assert failed.

=cut

sub failed {
    return $_[0]->result eq 'fail';
}


=head3 skipped

Returns true if the assert was skipped.

=cut

sub skipped {
    return $_[0]->result eq 'skip';
}


=head3 count_as_failure

    my $has_failed = $result->count_as_failure;

Returns true if the result should be counted as a failure.  This is
subtly different from checking C<< $result->failed >> as some
directives, such as todo, can

=cut

sub count_as_failure {
    my $self = shift;
    my $result = $self->result;

    return 0 if $result eq 'pass' or $result eq 'skip';
    return 0 if $result eq 'fail' and $self->is_todo;
    return 1;
}


=head3 skip_reason

Returns why the test was skipped, if any.

=cut

sub skip_reason {
    return $_[0]->directive_reason("skip");
}

=head3 is_todo

Returns true if the assert is todo.

=cut

sub is_todo {
    return $_[0]->has_directive("todo");
}

=head3 todo_reason

Returns why the test is considered todo, if any.

=cut

sub todo_reason {
    return $_[0]->directive_reason("todo");
}

=head3 has_directive

    $result->has_directive($directive);

Returns true if the assert has the given $directive.

=cut

sub has_directive {
    return exists $_[0]->directives->{$_[1]};
}


=head3 directive_reason

    $result->directive_reason($directive);

Returns why the $directive applies to this assert.

=cut

sub directive_reason {
    my $reason = $_[0]->directives->{$_[1]};
    return defined $reason ? $reason : '';
}


=head3 add_diag

    $result->add_diag( \%diagnostics );

Adds diagnostics to the $result.

Any diagnostics with the same key will be overwritten.

=cut

sub add_diag {
    my $self = shift;
    my $add = shift;

    my $diag = $self->diag;
    @{$diag}{keys %$add} = values %$add;

    return;
}

no Test::Builder2::Mouse;

1;

