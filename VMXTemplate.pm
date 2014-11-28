#!/usr/bin/perl
# Simple, powerful, fast and convenient template engine.
# This is the Perl version of VMXTemplate. There is also a PHP one.
#
# "Ох уж эти перлисты... что ни пишут - всё Template Toolkit получается!"
# "Oh, those perlists... they could write anything, and a result is another Template Toolkit"
# Rewritten 3 times: regex -> index() -> recursive descent -> Parse::Yapp LALR(1)
#
# Homepage: http://yourcmc.ru/wiki/VMX::Template
# License: GNU GPLv3 or later
# Author: Vitaliy Filippov, 2006-2014
# Version: V3 (LALR), 2014-10-14

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
# http://www.gnu.org/copyleft/gpl.html

package VMXTemplate;

use strict;
use Digest::MD5 qw(md5_hex);
use POSIX;

use VMXTemplate::Utils;
use VMXTemplate::Options;
use VMXTemplate::Parser;

# Version of code classes, saved into compiled files
use constant CODE_VERSION => 4;

sub new
{
    my $class = shift;
    $class = ref($class) || $class;
    my ($options) = @_;

    my $self = bless {
        options => VMXTemplate::Options->new($options),
        tpldata => {},
        compiler => undef,

        # current function search scope
        function_search_path => undef,
        loaded_templates => undef,

        # memory cache
        mtimes => {},           # change timestamps
        ltimes => {},           # load timestamps
        compiled_code => {},    # compiled code cache
    }, $class;

    return $self;
}

# Clear variables
# $obj->clear()
sub clear
{
    my $self;
    $self->{tpldata} = {};
    return 1;
}

# Clear memory cache
sub clear_memory_cache
{
    my $self = shift;
    %{$self->{compiled_code}} = ();
    %{$self->{mtimes}} = ();
    %{$self->{ltimes}} = ();
    return $self;
}

# Get/set template data hashref
sub vars
{
    my $self = shift;
    my ($vars) = @_;
    my $t = $self->{tpldata};
    $self->{tpldata} = $vars if $vars;
    return $t;
}

# Run template
# $page = $obj->parse($filename);
# $page = $obj->parse($filename, $tpldata);
sub parse
{
    my ($self, $fn, $vars) = @_;
    return $self->parse_real($fn, undef, undef, $vars);
}

# Call named block/function from a template
sub exec_from
{
    my ($self, $filename, $function, $vars) = @_;
    return $self->parse_real($filename, undef, $function, $vars);
}

# Parse string as a template and run it
# Not recommended, but possible
sub parse_inline
{
    my ($self, $code, $vars) = @_;
    return $self->parse_real(undef, $_[1], undef, $vars);
}

# Call function from a string parsed as a template
# Highly not recommended, but still possible
sub exec_from_inline
{
    my ($self, $code, $function, $vars) = @_;
    return $self->parse_real(undef, $code, $function, $vars);
}

# Real parse handler
# $page = $obj->parse_real(filename, inline code, function, vars)
# <inline code> means use a string instead of file. Not recommended, but possible.
sub parse_real
{
    my $self = shift;
    my ($filename, $text, $function, $vars) = @_;
    # Init function search path for outermost call
    my $is_outer = !$self->{function_search_path};
    $self->{function_search_path} ||= {};
    $self->{loaded_templates} ||= {};
    if ($is_outer)
    {
        $self->{options}->{errors} = [];
    }
    my ($code, $key) = $self->compile($text, $filename);
    if (!$self->{loaded_templates}->{$key})
    {
        # populate function_search_path
        for (keys %$code)
        {
            $self->{function_search_path}->{$_} = [ $filename, $key ] if !/^:/s;
        }
    }
    my $str = $self->_run($code, 0, $function, $filename, $vars);
    if ($is_outer)
    {
        # we can't just print errors to STDOUT in Perl, so return them all with the outer output
        if ($self->{options}->{print_error} && @{$self->{options}->{errors}})
        {
            substr($str, 0, 0, $self->{options}->get_errors . "\n");
        }
        $self->{function_search_path} = undef;
        $self->{loaded_templates} = undef;
    }
    return $str;
}

# Run a function from template object
sub _run
{
    my $self = shift;
    my ($code, $is_outer, $function, $filename, $vars) = @_;
    $function ||= ':main';
    my $str = $code->{$function};
    if (!defined $str)
    {
        $self->{options}->error("template function '$function' not found in '".($filename || 'inline template')."'");
        return $is_outer ? $self->{options}->get_errors : '';
    }
    # a template function is just a constant if not a coderef
    elsif (ref $str eq 'CODE')
    {
        local $self->{tpldata} = $vars if $vars;
        $str = eval { &$str($self) };
        if ($@)
        {
            $self->{options}->error("error running function '$function' from '".($filename || 'inline template')."': $@");
            return $is_outer ? $self->{options}->get_errors : '';
        }
    }
    for my $f (@{$self->{options}->{filters}})
    {
        $f = $self->can("filter_$f") if !ref $f;
        $f->($str) if $f;
    }
    return $str;
}

# Call block from current include scope (for internal use in templates)
sub _call_block
{
    my ($self, $block, $args, $errorinfo) = @_;
    if (my $entry = $self->{function_search_path}->{$block})
    {
        my $code = $self->{compiled_code}->{$entry->[1]};
        die "BUG: cache is empty in call_block()" if !$code;
        return $self->_run($code, 0, $block, $entry->[0], $args);
    }
    $self->{options}->error("Unknown block '$block'$errorinfo");
}

# Compile code and cache it on disk
# ($sub, $cache_key) = $self->compile($code, $filename);
# print &$sub($self);
sub compile
{
    my $self = shift;
    my ($code, $fn, $force_reload) = @_;
    Encode::_utf8_off($code); # for md5_hex
    my $key = $fn ? 'F'.$fn : 'C'.md5_hex($code);

    $force_reload = 1 if !$self->{compiled_code}->{$key};
    $force_reload = 1 if $self->{options}->{disable_cache};

    # Load code
    my $mtime;
    if ($fn)
    {
        $fn = $self->{options}->{root}.$fn if $fn !~ m!^/!so;
        if (!$force_reload && $self->{options}->{reload} && $self->{ltimes}->{$fn}+$self->{options}->{reload} < time)
        {
            $mtime = [ stat $fn ] -> [ 9 ];
            $force_reload = 1 if $mtime > $self->{mtimes}->{$fn};
        }
    }

    if (!$force_reload)
    {
        return ($self->{compiled_code}->{$key}, $key);
    }

    if ($fn)
    {
        # reload if file has changed
        my $fd;
        if (open $fd, "<", $fn)
        {
            local $/ = undef;
            $code = <$fd>;
            close $fd;
        }
        else
        {
            $self->{options}->error("couldn't load template file '$fn': $!");
            return ();
        }
    }

    # inline code
    if (!$fn)
    {
        my (undef, $f, $l) = caller(1);
        $fn = "(inline template at $f:$l)";
    }

    # try disk cache
    my $h;
    if ($self->{options}->{cache_dir})
    {
        $h = $self->{options}->{cache_dir}.md5_hex($code).'.pl';
        if (-e $h)
        {
            my $r = $self->{compiled_code}->{$key} = do $h;
            if ($@)
            {
                $self->{options}->error("error compiling '$fn': [ $@ ] in FILE: $h");
                unlink $h;
            }
            elsif (ref $r eq 'CODE' ||
                !$r->{':version'} || $r->{':version'} < CODE_VERSION)
            {
                # we got cache from older version, force recompile
            }
            else
            {
                if ($fn)
                {
                    # remember modification and load time
                    $self->{mtimes}->{$fn} = $mtime;
                    $self->{ltimes}->{$fn} = time;
                }
                return ($r, $key);
            }
        }
    }

    Encode::_utf8_on($code) if $self->{options}->{use_utf8};

    # call Compiler
    $self->{options}->{input_filename} = $fn;
    $self->{compiler} ||= VMXTemplate::Parser->new($self->{options});
    $code = $self->{compiler}->compile($code);

    # write compiled code to file
    if ($h)
    {
        my $fd;
        if (open $fd, ">$h")
        {
            no warnings 'utf8';
            print $fd $code;
            close $fd;
        }
        else
        {
            $self->warning("error caching '$fn': $! while opening $h");
        }
    }

    # load code
    $self->{compiled_code}->{$key} = eval $code;
    if ($@)
    {
        $self->{options}->error("error compiling '$fn': [$@] in CODE:\n$code");
        return ();
    }

    if ($fn)
    {
        # remember modification and load time
        $self->{mtimes}->{$fn} = $mtime;
        $self->{ltimes}->{$fn} = time;
    }

    return ($self->{compiled_code}->{$key}, $key);
}

# built-in strip_space filter
sub filter_strip_space
{
    $_[0] =~ s/^[ \t]+//gm;
    $_[0] =~ s/[ \t]+$//gm;
    $_[0] =~ s/\n{2,}/\n/gs;
}

1;
__END__

=head1 VMXTemplate template engine

This is a simple, but powerful, fast and convenient template engine.
You're looking at the Perl implementation; there is also PHP one.
Both are based on LALR(1) parsers.

Full documentation is at http://yourcmc.ru/wiki/VMX::Template

=head1 Usage

 use VMXTemplate;

 # Keep $template object alive for caching
 # DO NOT recreate it on every request!
 my $template = VMXTemplate->new({
     root => 'templates/',
     cache_dir => 'cache/',
     auto_escape => 's',
 });

 print $template->parse('site.tpl', {
     # any data passed to template...
 });

=head1 Example

 <!-- SET title = "Statistics" -->
 <!-- SET headscripts -->
     <script language="JavaScript" type="text/javascript" src="{DOMAIN}/tpldata/jquery.min.js"></script>
 <!-- END -->
 <!-- INCLUDE "admin_header.tpl" -->
 <!-- IF NOT srcid -->
     <p>Welcome to my simple OLAP. Select data source:</p>
     <form action="?" method="GET">
         <select style="width:100px" name="datasource">
         <!-- FOR s = sources -->
             <option value="{s s.id}">{s s.name}: {yesno(s.size > 1024, s.size/1024 .. ' Kb' : s.size .. 'bytes')}</option>
         <!-- END -->
         </select>
         <input type="submit" value="Continue" />
     </form>
 <!-- ELSEIF srcid == "test" || sources[srcid].mode == 'test' -->
     <p>Test mode.</p>
 <!-- END -->
 <!-- INCLUDE "admin_footer.tpl" -->

=head1 Template syntax

=head2 Markers

=over

=item "<!--" and "-->": directive start/end

=item "{" and "}": substitution start/end

=back

=head2 Expressions

Expressions consist of variables, operators, function and method calls.

=over

=item hash.key, hash['key']

=item array[index]

=item object.method(arg1, arg2, ...)

=item function(arg1, arg2, ...)

=item function single_arg

For example, INCLUDE "other_template.tpl" is a single argument function call.

=item block_name('arg' => 'value', 'arg2' => 'value2', ...)

=back

=head2 Operators

=over

=item a .. b

String concatenation (.. is like Lua).

=item a || b, a OR b

Logical OR, Perl- or JS-like: returns first true value.

=item a XOR b, a && b, a AND b, !a, NOT a

Logical XOR, AND, NOT.

=item a == b, a != b, a < b, a > b, a <= b, a >= b

Comparison operators. Numeric comparisons are used if, and only if
VMXTemplate can easily tell that one of a and b is ALWAYS numeric,
for example if it is a numeric constant or a result of int() function.

=item a+b, a-b, a*b, a/b, a%b

Arithmetic operators.

=item { 'key' => 'value', ... }

Creates a hashref.

=back

=head2 Directives

=over

=item <!--# Comment -->

=item <!-- FOR item = array --> ...code... <!-- END -->

Loop. {item_index} is the loop counter inside 'FOR item =' loop.

=item <!-- IF expression --> ...code...

=item <!-- ELSEIF expression --> ...code...

=item <!-- ELSE --> ...code...

=item <!-- END -->

=item <!-- SET var = expression -->

=item <!-- SET var --> ...code... <!-- END -->

=item <!-- BLOCK name(arg1, arg2, ...) = expression -->

=item <!-- BLOCK name(arg1, arg2, ...) --> ...code... <!-- END -->

=back

=head1 Functions

=head2 Numeric and logical

=head2 String

=head2 Arrays and hashes

=head2 Misc

=head2 Template inclusion

=cut
