#!/usr/bin/perl

package VMXTemplate;

# Version of code classes, saved into compiled files
use strict;
use constant CODE_VERSION => 4;

sub new
{
    my $class = shift;
    $class = ref($class) || $class;
    my ($options) = @_;

    my $self = bless {
        tpldata => {},
        failed => {},
        function_search_path => {},
        options => new VMXTemplate::Options($options),
        compiler => undef,
    }, $class;

    return $self;
}

1;
