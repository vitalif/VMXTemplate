####################################################################
#
# ANY CHANGE MADE HERE WILL BE LOST !
#
# This file was generated using Parse::Yapp version <<$version>>.
# Don't edit this file, edit template.skel.pm and template.yp instead.
#
####################################################################

package VMXTemplate::Parser;

use strict;
use VMXTemplate::Compiler;
use VMXTemplate::Utils;
<<$driver>>
our @ISA = qw(Parse::Yapp::Driver VMXTemplate::Compiler);

<<$head>>
sub new
{
    my $class = shift;
    $class = ref($class) || $class;
    my ($options) = @_;
    my $self = bless $class->SUPER::new(
        yyversion => '<<$version>>',
        yystates =>
<<$states>>,
        yyrules =>
<<$rules>>,
#line 30 "template.skel.pm"
    ), $class;
    $self->{options} = $options;
    return $self;
}

1;
