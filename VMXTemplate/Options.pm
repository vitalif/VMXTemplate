#!/usr/bin/perl

package VMXTemplate::Options;

use strict;
use VMXTemplate::Utils;

sub new
{
    my $class = shift;
    $class = ref($class) || $class;
    my ($options) = @_;

    my $self = bless {
        begin_code    => '<!--',    # instruction start
        end_code      => '-->',     # instruction end
        begin_subst   => '{',       # substitution start (set to '' to turn off)
        end_subst     => '}',       # substitution end (set to '' to turn off)
        no_code_subst => 0,         # only evaluate instructions, but ignore their results; only insert results of substitutions
        eat_code_line => 1,         # remove the "extra" lines which contain instructions only
        root          => '.',       # directory with templates
        cache_dir     => undef,     # compiled templates cache directory
        reload        => 2,         # 0 means to not check for new versions of cached templates
                                    # > 0 - check at most each <reload> seconds
        filters       => [],        # filters to run on output of every template
        use_utf8      => 1,         # templates are in UTF-8 and all template variables should be in UTF-8
        raise_error   => 0,         # die() on fatal template errors
        log_error     => 0,         # send errors to standard error output
        print_error   => 0,         # print fatal template errors
        strip_space   => 0,         # strip spaces from beginning and end of each line
        auto_escape   => undef,     # "safe mode" function name (use 's' for HTML) - automatically escapes substituted
                                    # values via this function if not escaped explicitly
        compiletime_functions => {},# custom compile-time functions (code generators)

        input_filename  => '',
        errors          => [],
    }, $class;

    $self->set($options);

    return $self;
}

sub set
{
    my ($self, $options) = @_;
    for (keys %{$options || {}})
    {
        if (exists $self->{$_} && $_ ne 'errors')
        {
            $self->{$_} = $options->{$_};
        }
    }
    $self->{filters} = [] if ref $self->{filters} ne 'ARRAY';
    if ($self->{strip_space} && !grep { $_ eq 'strip_space' } @{$self->{filters}})
    {
        push @{$self->{filters}}, 'strip_space';
    }
    if (!$self->{begin_subst} || !$self->{end_subst})
    {
        $self->{begin_subst} = undef;
        $self->{end_subst} = undef;
        $self->{no_code_subst} = 0;
    }
    $self->{cache_dir} =~ s!/*$!/!so;
    if (!-w $self->{cache_dir})
    {
        die new VMXTemplate::Exception('VMXTemplate: cache_dir='.$self->{cache_dir}.' is not writable');
    }
    $self->{root} =~ s!/*$!/!so;
}

sub get_errors
{
    my ($self) = @_;
    if ($self->{print_error} && @{$self->{errors}})
    {
        return '<div id="template-errors" style="display: block; border: 1px solid black; padding: 8px; background: #fcc">'.
            'VMXTemplate errors:<ul><li>'.
            join('</li><li>', map \&html_pbr, @{$self->{errors}}).
            '</li></ul>';
    }
    return '';
}

# Log an error or a warning
sub error
{
    my ($self, $e, $fatal) = @_;
    push @{$self->{errors}}, $e;
    if ($self->{raise_error} && $fatal)
    {
        die "VMXTemplate error: $e";
    }
    if ($self->{log_error})
    {
        print STDERR "VMXTemplate error: $e\n";
    }
}

1;
