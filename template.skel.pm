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
use base qw(Parse::Yapp::Driver);
<<$driver>>

VMXTemplate::Utils::import();

<<$head>>
sub new
{
    my $class = shift;
    $class = ref($class) || $class;
    my ($compiler) = @_;
    return bless $class->SUPER::new(
        yyversion => '<<$version>>',
        yystates =>
<<$states>>,
        yyrules =>
<<$rules>>,
#line 30 "template.skel.pm"
        compiler => $compiler,
        lexer => undef,
        @_
    ), $class;
}

sub _Lexer
{
    my ($parser) = shift;
    return $parser->{lexer}->read_token;
}

sub _error
{
    my ($self) = @_;
    $self->{lexer}->warn('Unexpected ' . $self->YYCurtok . ($self->YYCurval ? ' ' . $self->YYCurval : ''));
    $self->{lexer}->skip_error;
}

sub compile
{
    my ($self, $text) = @_;
    $self->{lexer} ||= new VMXTemplate::Lexer($self, $self->{compiler}->{options});
    $self->{lexer}->set_code($text);
    $self->{functions} = {
        main => {
            name => 'main',
            args => [],
            body => '',
            line => 0,
            pos => 0,
        },
    };
    $self->YYParse(yylex => \&_Lexer, yyerror => \&_error);
    if (!$self->{functions}->{main}->{body})
    {
        # Parse error?
        delete $self->{functions}->{main};
    }
    return "use VMXTemplate::Utils;\n".
        "our \$FUNCTIONS = { ".join(", ", map { "$_ => 1" } keys %{$self->{functions}})." };\n".
        join("\n", map { $_->{body} } values %{$self->{functions}})
}

package VMXTemplate::Lexer;

# Possible tokens consisting of special characters
my $chartokens = '+ - = * / % ! , . < > ( ) { } [ ] & .. || && == != <= >= =>';

# Reserved keywords
my $keywords_str = 'OR XOR AND NOT IF ELSE ELSIF ELSEIF END SET FOR FOREACH FUNCTION BLOCK MACRO';

sub new
{
    my $class = shift;
    $class = ref($class) || $class;
    my ($options) = @_;

    my $self = bless {
        options => $options,

        # Input
        code => '',
        eaten => '',
        lineno => 0,

        # Preprocessed keyword tokens
        nchar => {},
        lens => [],
        keywords => { map { $_ => 1 } split / /, $keywords_str },

        # Last directive start position, directive and substitution start/end counters
        last_start => 0,
        last_start_line => 0,
        in_code => 0,
        in_subst => 0,
    }, $class;

    foreach (split(/ /, $chartokens))
    {
        $self->{nchar}{length($_)}{$_} = 1;
    }
    # Add code fragment finishing tokens
    $self->{nchar}{length($self->{options}->{end_code})}{$self->{options}->{end_code}} = 1;
    if ($self->{options}->{end_subst})
    {
        $self->{nchar}{length($self->{options}->{end_subst})}{$self->{options}->{end_subst}} = 1;
    }
    # Reverse-sort lengths
    $self->{lens} = [ sort { $b <=> $a } keys %{$self->{nchar}} ];

    return $self;
}

sub set_code
{
    my $self = shift;
    my ($code) = @_;
    $self->{code} = $code;
    $self->{eaten} = '';
    $self->{lineno} = $self->{in_code} = $self->{in_subst} = 0;
    $self->{last_start} = $self->{last_start_line} = 0;
}

sub eat
{
    my $self = shift;
    my ($len) = @_;
    my $str = substr($self->{code}, 0, $len, '');
    $self->{eaten} .= $str;
    $self->{lineno} += ($str =~ tr/\n/\n/);
    return $str;
}

sub pos
{
    my $self = shift;
    use bytes;
    return length $self->{eaten};
}

sub line
{
    my $self = shift;
    return $self->{lineno};
}

sub skip_error
{
    my ($self) = @_;
    $self->{code} = substr($self->{eaten}, $self->{last_start}+1, length($self->{eaten}), '') . $self->{code};
    $self->{lineno} = $self->{last_start_line};
    $self->{in_code} = $self->{in_subst} = 0;
}

sub read_token
{
    my $self = shift;
    if (!length $self->{code})
    {
        # End of code
        return;
    }
    if ($self->{in_code} <= 0 && $self->{in_subst} <= 0)
    {
        my $r;
        my $code_pos = index($self->{code}, $self->{options}->{begin_code});
        my $subst_pos = index($self->{code}, $self->{options}->{begin_subst});
        if ($code_pos == -1 && $subst_pos == -1)
        {
            # No more directives
            $r = [ 'literal', [ "'".addcslashes($self->eat(length $self->{code}), "'\\")."'", 1 ] ];
        }
        elsif ($subst_pos == -1 || $code_pos >= 0 && $subst_pos > $code_pos)
        {
            # Code starts closer
            if ($code_pos > 0)
            {
                # We didn't yet reach the code beginning
                my $str = $self->eat($code_pos);
                if ($self->{options}->{eat_code_line})
                {
                    $str =~ s/\n[ \t]*$/\n/s;
                }
                $r = [ 'literal', [ "'".addcslashes($str, "'\\")."'", 1 ] ];
            }
            else
            {
                # We are at the code beginning
                my $i = length $self->{options}->{begin_code};
                if ($self->{code} =~ /^.{$i}([ \t]+)/s)
                {
                    $i += length $1;
                }
                if ($i < length($self->{code}) && substr($self->{code}, $i, 1) eq '#')
                {
                    # Strip comment and retry
                    $i = index($self->{code}, $self->{options}->{end_code}, $i);
                    $i = $i >= 0 ? $i+length($self->{options}->{end_code}) : length $self->{code};
                    $self->eat($i);
                    return $self->read_token();
                }
                $r = [ '<!--', $self->{options}->{begin_code} ];
                $self->{last_start} = length $self->{eaten};
                $self->{last_start_line} = $self->{lineno};
                $self->eat(length $self->{options}->{begin_code});
                $self->{in_code} = 1;
            }
        }
        else
        {
            # Substitution is closer
            if ($subst_pos > 0)
            {
                $r = [ 'literal', [ "'".addcslashes($self->eat($subst_pos), "'\\")."'", 1 ] ];
            }
            else
            {
                $r = [ '{{', $self->{options}->{begin_subst} ];
                $self->{last_start} = length $self->{eaten};
                $self->{last_start_line} = $self->{lineno};
                $self->eat(length $self->{options}->{begin_subst});
                $self->{in_subst} = 1;
            }
        }
        return @$r;
    }
    # Skip whitespace
    if ($self->{code} =~ /^(\s+)/)
    {
        $self->eat(length $1);
    }
    if (!length $self->{code})
    {
        # End of code
        return;
    }
    if ($self->{code} =~ /^([a-z_][a-z0-9_]*)/is)
    {
        my $l = $1;
        $self->eat(length $l);
        if (exists $self->{keywords}->{uc $l})
        {
            # Keyword
            return (uc $l, $l);
        }
        # Identifier
        return ('name', $l);
    }
    elsif ($self->{code} =~ /^(
        (\")(?:[^\"\\\\]+|\\\\.)*\" |
        \'(?:[^\'\\\\]+|\\\\.)*\' |
        0\d+ | \d+(\.\d+)? | 0x\d+)/xis)
    {
        # String or numeric non-negative literal
        my $t = $1;
        $self->eat(length $t);
        if ($2)
        {
            $t =~ s/\$/\\\$/gso;
        }
        return ('literal', [ $t, $t =~ /^[\"\']/ ? 1 : 'i' ]);
    }
    else
    {
        # Special characters
        foreach my $l (@{$self->{lens}})
        {
            my $a = $self->{nchar}->{$l};
            my $t = substr($self->{code}, 0, $l);
            if (exists $a->{$t})
            {
                $self->eat($l);
                if ($self->{in_code})
                {
                    $self->{in_code}++ if $t eq $self->{options}->{begin_code};
                    $self->{in_code}-- if $t eq $self->{options}->{end_code};
                    if (!$self->{in_code})
                    {
                        if ($self->{options}->{eat_code_line} &&
                            $self->{code} =~ /^([ \t\r]+\n\r?)/so)
                        {
                            $self->eat(length $1);
                        }
                        return ('-->', $t);
                    }
                }
                elsif ($self->{in_subst})
                {
                    $self->{in_subst}++ if $t eq $self->{options}->{begin_subst};
                    $self->{in_subst}-- if $t eq $self->{options}->{end_subst};
                    if (!$self->{in_subst})
                    {
                        return ('}}', $t);
                    }
                }
                return ($t, undef);
            }
        }
        # Unknown character
        $self->warn("Unexpected character '".substr($self->{code}, 0, 1)."'");
        return ('error', undef);
    }
}

sub errorinfo
{
    my $self = shift;
    my $linestart = rindex($self->{eaten}, "\n");
    my $lineend = index($self->{code}, "\n");
    $lineend = length($self->{code}) if $lineend < 0;
    my $line = substr($self->{eaten}, $linestart+1) . '^^^' . substr($self->{code}, 0, $lineend);
    return ' in '.$self->{options}->{input_filename}.', line '.($self->{lineno}+1).
        ', byte '.$self->pos.', marked by ^^^ in '.$line;
}

sub warn
{
    my $self = shift;
    my ($text) = @_;
    $self->{options}->error($text.$self->errorinfo());
}

package VMXTemplate::Utils;

use Encode;

use base qw(Exporter);
our @EXPORT = qw(
    TS_UNIX TS_DB TS_DB_DATE TS_MW TS_EXIF TS_ORACLE TS_ISO_8601 TS_RFC822
    timestamp plural_ru strlimit htmlspecialchars strip_tags strip_unsafe_tags
    addcslashes requote quotequote sql_quote regex_replace str_replace
    array_slice array_div encode_json trim html_pbr array_items utf8on
    exec_subst exec_pairs exec_is_array exec_get exec_cmp
);

use constant {
    TS_UNIX     => 0,
    TS_DB       => 1,
    TS_DB_DATE  => 2,
    TS_MW       => 3,
    TS_EXIF     => 4,
    TS_ORACLE   => 5,
    TS_ISO_8601 => 6,
    TS_RFC822   => 7,
};

my @Mon = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
my %mon = qw(jan 0 feb 1 mar 2 apr 3 may 4 jun 5 jul 6 aug 7 sep 8 oct 9 nov 10 dec 11);
my @Wday = qw(Sun Mon Tue Wed Thu Fri Sat);

our $safe_tags = 'div|blockquote|span|a|b|i|u|p|h1|h2|h3|h4|h5|h6|strike|strong|small|big|blink|center|ol|pre|sub|sup|font|br|table|tr|td|th|tbody|tfoot|thead|tt|ul|li|em|img|marquee|cite';

# Date parser for some common formats
sub timestamp
{
    my ($ts, $format) = @_;

    require POSIX;
    if (int($ts) eq $ts)
    {
        # TS_UNIX or Epoch
        $ts = time if !$ts;
    }

    elsif ($ts =~ /^\D*(\d{4,}?)\D*(\d{2})\D*(\d{2})\D*(?:(\d{2})\D*(\d{2})\D*(\d{2})\D*([\+\- ]\d{2}\D*)?)?$/so)
    {
        # TS_DB, TS_DB_DATE, TS_MW, TS_EXIF, TS_ISO_8601
        $ts = POSIX::mktime($6||0, $5||0, $4||0, $3, $2-1, $1-1900);
    }
    elsif ($ts =~ /^\s*(\d\d?)-(...)-(\d\d(?:\d\d)?)\s*(\d\d)\.(\d\d)\.(\d\d)/so)
    {
        # TS_ORACLE
        $ts = POSIX::mktime($6, $5, $4, int($1), $mon{lc $2}, $3 < 100 ? $3 : $3-1900);
    }
    elsif ($ts =~ /^\s*..., (\d\d?) (...) (\d{4,}) (\d\d):(\d\d):(\d\d)\s*([\+\- ]\d\d)\s*$/so)
    {
        # TS_RFC822
        $ts = POSIX::mktime($6, $5, $4, int($1), $mon{lc $2}, $3-1900);
    }
    else
    {
        # Bogus value, return undef
        return undef;
    }

    if (!$format)
    {
        # TS_UNIX
        return $ts;
    }
    elsif ($format == TS_MW)
    {
        return POSIX::strftime("%Y%m%d%H%M%S", localtime($ts));
    }
    elsif ($format == TS_DB)
    {
        return POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime($ts));
    }
    elsif ($format == TS_DB_DATE)
    {
        return POSIX::strftime("%Y-%m-%d", localtime($ts));
    }
    elsif ($format == TS_ISO_8601)
    {
        return POSIX::strftime("%Y-%m-%dT%H:%M:%SZ", localtime($ts));
    }
    elsif ($format == TS_EXIF)
    {
        return POSIX::strftime("%Y:%m:%d %H:%M:%S", localtime($ts));
    }
    elsif ($format == TS_RFC822)
    {
        my @l = localtime($ts);
        return POSIX::strftime($Wday[$l[6]].", %d ".$Mon[$l[4]]." %Y %H:%M:%S %z", @l);
    }
    elsif ($format == TS_ORACLE)
    {
        my @l = localtime($ts);
        return POSIX::strftime("%d-".$Mon[$l[4]]."-%Y %H.%M.%S %p", @l);
    }
    return $ts;
}

# Select one of 3 plural forms for russian language
sub plural_ru
{
    my ($count, $one, $few, $many) = @_;
    my $sto = $count % 100;
    if ($sto >= 10 && $sto <= 20)
    {
        return $many;
    }
    my $r = $count % 10;
    if ($r == 1)
    {
        return $one;
    }
    elsif ($r >= 2 && $r <= 4)
    {
        return $few;
    }
    return $many;
}

# Limit string to $maxlen
sub strlimit
{
    my ($str, $maxlen, $dots) = @_;
    if (!$maxlen || $maxlen < 1 || length($str) <= $maxlen)
    {
        return $str;
    }
    $str = substr($str, 0, $maxlen);
    my $p = rindex($str, ' ');
    if ($p < 0 || (my $pt = rindex($str, "\t")) > $p)
    {
        $p = $pt;
    }
    if ($p > 0)
    {
        $str = substr($str, 0, $p);
    }
    return $str . (defined $dots ? $dots : '...');
}

# Escape HTML special chars
sub htmlspecialchars
{
    local $_ = $_[0];
    s/&/&amp;/gso;
    s/</&lt;/gso;
    s/>/&gt;/gso;
    s/\"/&quot;/gso;
    s/\'/&apos;/gso;
    return $_;
}

# Replace (some) tags with whitespace
sub strip_tags
{
    my ($str, $allowed) = @_;
    my $allowed = $allowed ? '(?!/?('.$allowed.'))' : '';
    $str =~ s/(<$allowed\/?[a-z][a-z0-9-]*(\s+[^<>]*)?>\s*)+/ /gis;
    return $str;
}

# Strip unsafe tags
sub strip_unsafe_tags
{
    return strip_tags($_[0], $safe_tags);
}

# Add '\' before specified chars
sub addcslashes
{
    my ($str, $escape) = @_;
    $str =~ s/([$escape])/\\$1/gs;
    return $str;
}

# Quote regexp-special characters in $_[0]
sub requote
{
    "\Q$_[0]\E";
}

# Escape quotes in C style, also \n and \r
sub quotequote
{
    my ($a) = @_;
    $a =~ s/[\\\'\"]/\\$&/gso;
    $a =~ s/\n/\\n/gso;
    $a =~ s/\r/\\r/gso;
    return $a;
}

# Escape quotes in SQL or CSV style (" --> "")
sub sql_quote
{
    my ($a) = @_;
    $a =~ s/\"/\"\"/gso;
    return $a;
}

# Replace regular expression, returning result
sub regex_replace
{
    my ($re, $repl, $s) = @_;
    $re = qr/$re/s if !ref $re;
    # Escape \ @ $ % /, but allow $n replacements ($1 $2 $3 ...)
    $repl =~ s!([\\\@\%/]|\$(?\!\d))!\\$1!gso;
    eval("\$s =~ s/\$re/$repl/gs");
    return $s;
}

# Replace strings
sub str_replace
{
    my ($str, $repl, $s) = @_;
    $s =~ s/\Q$str\E/$repl/gs;
    return $s;
}

# extract elements from array
# array_slice([], 0, 10)
# array_slice([], 2)
# array_slice([], 0, -1)
sub array_slice
{
    my ($array, $from, $to) = @_;
    return $array unless $from;
    $to ||= 0;
    $from += @$array if $from < 0;
    $to += @$array if $to <= 0;
    return [ @$array[$from..$to] ];
}

# extract each $div'th element from array, starting with $mod
# array_div([], 2)
# array_div([], 2, 1)
sub array_div
{
    my ($array, $div, $mod) = @_;
    return $array unless $div;
    $mod ||= 0;
    return [ @$array[grep { $_ % $div == $mod } 0..$#$array] ];
}

# JSON encoding
sub encode_json
{
    require JSON;
    *encode_json = *JSON::encode_json;
    goto &JSON::encode_json;
}

# Remove whitespace from the beginning and the end of the line
sub trim
{
    local $_ = $_[0];
    if ($_[1])
    {
        s/^$_[1]//s;
        s/$_[1]$//s;
    }
    else
    {
        s/^\s+//so;
        s/\s+$//so;
    }
    $_;
}

# htmlspecialchars + turn \n into <br />
sub html_pbr
{
    my ($s) = @_;
    $s = htmlspecialchars($s);
    $s =~ s/\n/<br \/>/gso;
    return $s;
}

# helper - returns array elements or just scalar, if it's not an arrayref
sub array_items
{
    ref($_[0]) && $_[0] =~ /ARRAY/ ? @{$_[0]} : (defined $_[0] ? ($_[0]) : ());
}

# recursive utf8_on and return result
sub utf8on
{
    if (ref($_[0]) && $_[0] =~ /HASH/so)
    {
        utf8on($_[0]->{$_}) for keys %{$_[0]};
    }
    elsif (ref($_[0]) && $_[0] =~ /ARRAY/so)
    {
        utf8on($_) for @{$_[0]};
    }
    else
    {
        Encode::_utf8_on($_[0]);
    }
    return $_[0];
}

# function subst()
sub exec_subst
{
    my $str = shift;
    $str =~ s/(?<!\\)((?:\\\\)*)\$(?:([1-9]\d*)|\{([1-9]\d*)\})/$_[($2||$3)-1]/gisoe;
    return $str;
}

# array of sorted key-value pairs for hash: [ { key => ..., value => ... }, ... ]
sub exec_pairs
{
    my $hash = shift;
    return [ map { { key => $_, value => $hash->{$_} } } sort keys %{ $hash || {} } ];
}

# check if the argument is an arrayref
sub exec_is_array
{
    return ref $_[1] && $_[1] =~ /ARRAY/;
}

# get array or hash element
sub exec_get
{
    defined $_[1] && ref $_[0] || return $_[0];
    $_[0] =~ /ARRAY/ && return $_[0]->[$_[1]];
    return $_[0]->{$_[1]};
}

# type-dependent comparison
sub exec_cmp
{
    my ($a, $b) = @_;
    my $n = grep /^-?\d+(\.\d+)?$/, $a, $b;
    return $n ? $a <=> $b : $a cmp $b;
}

package VMXTemplate::Exception;

sub new
{
    my $class = shift;
    $class = ref($class) || $class;
    my ($msg) = @_;
    return bless { message => $msg }, $class;
}

package VMXTemplate::Options;

VMXTemplate::Utils::import();

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
        no_code_subst => 0,         # only evaluate instructions, but ignore their results
        eat_code_line => 1,         # remove the "extra" lines which contain instructions only
        root          => '.',       # directory with templates
        cache_dir     => undef,     # compiled templates cache directory
        reload        => 1,         # 0 means to not check for new versions of cached templates
        filters       => [],        # filters to run on output of every template
        use_utf8      => 1,         # use UTF-8 for all string operations on template variables
        raise_error   => 0,         # die() on fatal template errors
        log_error     => 0,         # send errors to standard error output
        print_error   => 0,         # print fatal template errors
        strip_space   => 0,         # strip spaces from beginning and end of each line
        auto_escape   => undef,     # "safe mode" (use 's' for HTML) - automatically escapes substituted
                                    # values via this functions if not escaped explicitly
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
    for (keys %$options)
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
        print STDERR "VMXTemplate error: $e";
    }
}

package VMXTemplate;

# Version of code classes, saved into compiled files
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

package VMXTemplate::Compiler;

# Function aliases
my $functions = {
    'i'                 => 'int',
    'intval'            => 'int',
    'lower'             => 'lc',
    'lowercase'         => 'lc',
    'upper'             => 'uc',
    'uppercase'         => 'uc',
    'addslashes'        => 'quote',
    'q'                 => 'quote',
    're_quote'          => 'requote',
    'preg_quote'        => 'requote',
    'uri_escape'        => 'urlencode',
    'uriquote'          => 'urlencode',
    'substring'         => 'substr',
    'htmlspecialchars'  => 'html',
    's'                 => 'html',
    'strip_tags'        => 'strip',
    't'                 => 'strip',
    'h'                 => 'strip_unsafe',
    'sq'                => 'sql_quote',
    'implode'           => 'join',
    'truncate'          => 'strlimit',
    'hash_keys'         => 'keys',
    'array_keys'        => 'keys',
    'array_slice'       => 'subarray',
    'hget'              => 'get',
    'aget'              => 'get',
    'var_dump'          => 'dump',
    'process'           => 'parse',
    'include'           => 'parse',
    'process_inline'    => 'parse_inline',
    'include_inline'    => 'parse_inline',
    'subarray'          => 'array_slice',
    'subarray_divmod'   => 'array_div',
};

# Functions that do escape HTML, for safe mode
use constant Q_ALWAYS => -1;
use constant Q_IF_ALL => -2;
use constant Q_ALL_BUT_FIRST => -3;
use constant Q_ALWAYS_NUM => -4;

my $functionSafeness = {
    'int'               => Q_ALWAYS_NUM,
    'raw'               => Q_ALWAYS,
    'html'              => Q_ALWAYS,
    'strip'             => Q_ALWAYS,
    'strip_unsafe'      => Q_ALWAYS,
    'parse'             => Q_ALWAYS,
    'parse_inline'      => Q_ALWAYS,
    'exec'              => Q_ALWAYS,
    'exec_from'         => Q_ALWAYS,
    'exec_from_inline'  => Q_ALWAYS,
    'quote'             => Q_ALWAYS,
    'sql_quote'         => Q_ALWAYS,
    'requote'           => Q_ALWAYS,
    'urlencode'         => Q_ALWAYS,
    'and'               => Q_ALWAYS,
    'or'                => Q_IF_ALL,
    'not'               => Q_ALWAYS_NUM,
    'add'               => Q_ALWAYS_NUM,
    'sub'               => Q_ALWAYS_NUM,
    'mul'               => Q_ALWAYS_NUM,
    'div'               => Q_ALWAYS_NUM,
    'mod'               => Q_ALWAYS_NUM,
    'log'               => Q_ALWAYS_NUM,
    'even'              => Q_ALWAYS_NUM,
    'odd'               => Q_ALWAYS_NUM,
    'eq'                => Q_ALWAYS_NUM,
    'ne'                => Q_ALWAYS_NUM,
    'gt'                => Q_ALWAYS_NUM,
    'lt'                => Q_ALWAYS_NUM,
    'ge'                => Q_ALWAYS_NUM,
    'le'                => Q_ALWAYS_NUM,
    'seq'               => Q_ALWAYS_NUM,
    'sne'               => Q_ALWAYS_NUM,
    'sgt'               => Q_ALWAYS_NUM,
    'slt'               => Q_ALWAYS_NUM,
    'sge'               => Q_ALWAYS_NUM,
    'sle'               => Q_ALWAYS_NUM,
    'neq'               => Q_ALWAYS_NUM,
    'nne'               => Q_ALWAYS_NUM,
    'ngt'               => Q_ALWAYS_NUM,
    'nlt'               => Q_ALWAYS_NUM,
    'nge'               => Q_ALWAYS_NUM,
    'nle'               => Q_ALWAYS_NUM,
    'strlen'            => Q_ALWAYS_NUM,
    'strftime'          => Q_ALWAYS,
    'str_replace'       => Q_ALL_BUT_FIRST,
    'substr'            => 1,   # parameter number to take safeness from
    'trim'              => 1,
    'split'             => 1,
    'nl2br'             => 1,
    'concat'            => Q_IF_ALL,
    'join'              => Q_IF_ALL,
    'subst'             => Q_IF_ALL,
    'strlimit'          => 1,
    'plural_ru'         => Q_ALL_BUT_FIRST,
    'hash'              => Q_IF_ALL,
    'keys'              => 1,
    'values'            => 1,
    'sort'              => 1,
    'pairs'             => 1,
    'array'             => Q_IF_ALL,
    'range'             => Q_ALWAYS,
    'is_array'          => Q_ALWAYS_NUM,
    'count'             => Q_ALWAYS_NUM,
    'array_slice'       => 1,
    'array_div'         => 1,
    'set'               => 2,
    'array_merge'       => Q_IF_ALL,
    'shift'             => 1,
    'pop'               => 1,
    'unshift'           => Q_ALWAYS,
    'push'              => Q_ALWAYS,
    'void'              => Q_ALWAYS,
    'json'              => Q_ALWAYS,
    'map'               => Q_ALL_BUT_FIRST,
    'yesno'             => Q_ALL_BUT_FIRST,
};

# Generate semantic expression for template function call
sub compile_function
{
    my $self = shift;
    my ($fn, $args) = @_;
    $fn = lc $fn;
    if ($functions->{$fn})
    {
        # Function alias
        $fn = $functions->{$fn};
    }
    # Calculate HTML safeness flag
    my $q = $functionSafeness->{$fn};
    if ($q > 0)
    {
        $q = exists $args->[$q-1] ? $args->[$q-1]->[1] : 1;
    }
    elsif ($q == Q_ALWAYS)
    {
        $q = 1;
    }
    elsif ($q == Q_ALWAYS_NUM)
    {
        $q = 'i';
    }
    else
    {
        $q = 1;
        my $n = scalar @$args;
        for (my $i = ($q == Q_ALL_BUT_FIRST ? 1 : 0); $i < $n; $i++)
        {
            $q = $q && $args->[$i]->[1];
        }
    }
    my $argv = [ map { $_->[0] } @$args ];
    my $r;
    if ($self->can(my $ffn = "function_$fn"))
    {
        # Builtin function call using name
        $r = $self->$ffn(@$argv);
    }
    elsif (my $ffn = $self->{options}->{compiletime_functions}->{$fn})
    {
        # Custom compile-time function call
        $r = &$ffn($self, @$argv);
    }
    else
    {
        $self->{lexer}->warn("Unknown function: '$fn'");
        $r = "''";
    }
    return [ $r, $q ];
}

# call operator on arguments
sub fmop
{
    my $op = shift;
    return "((" . join(") $op (", @_) . "))";
}

# call function, expanding all passed arrays
sub fearr
{
    my $f = shift;
    my $n = shift;
    my $self = shift;
    my $e = "$f(";
    $e .= join(", ", splice(@_, 0, $n)) if $n;
    $e .= ", " if $n && @_;
    $e .= join(", ", map { "array_items($_)" } @_);
    $e .= ")";
    return $e;
}

### Function implementations

## Numeric/Logical

# logical
sub function_or      { fmop('||', @_) }
sub function_and     { fmop('&&', @_) }
sub function_not     { "!($_[1])" }
# arithmetic
sub function_add     { fmop('+', @_) }
sub function_sub     { fmop('-', @_) }
sub function_mul     { fmop('*', @_) }
sub function_div     { fmop('/', @_) }
sub function_mod     { fmop('%', @_) }
# logarithm
sub function_log     { "log($_[1])" }
# is the argument even/odd?
sub function_even    { "!(($_[1]) & 1)" }
sub function_odd     { "(($_[1]) & 1)" }
# cast to integer, throwing away the fractional part
sub function_int     { "int($_[1])" }
# type-dependent comparisons: = != > < >= <=
sub function_eq      { "(exec_cmp($_[1], $_[2]) == 0)" }
sub function_ne      { "(exec_cmp($_[1], $_[2]) != 0)" }
sub function_gt      { "(exec_cmp($_[1], $_[2]) > 0)" }
sub function_lt      { "(exec_cmp($_[1], $_[2]) < 0)" }
sub function_ge      { "(exec_cmp($_[1], $_[2]) >= 0)" }
sub function_le      { "(exec_cmp($_[1], $_[2]) <= 0)" }
# string comparisons: = != > < >= <=
sub function_seq     { "(($_[1]) eq ($_[2]))" }
sub function_sne     { "(($_[1]) ne ($_[2]))" }
sub function_sgt     { "(($_[1]) gt ($_[2]))" }
sub function_slt     { "(($_[1]) lt ($_[2]))" }
sub function_sge     { "(($_[1]) ge ($_[2]))" }
sub function_sle     { "(($_[1]) le ($_[2]))" }
# numeric comparisons: = != > < >= <=
sub function_neq     { "(($_[1]) == ($_[2]))" }
sub function_nne     { "(($_[1]) != ($_[2]))" }
sub function_ngt     { "(($_[1]) >  ($_[2]))" }
sub function_nlt     { "(($_[1]) <  ($_[2]))" }
sub function_nge     { "(($_[1]) >= ($_[2]))" }
sub function_nle     { "(($_[1]) <= ($_[2]))" }
# ternary operator $1 ? $2 : $3
sub function_yesno   { "(($_[1]) ? ($_[2]) : ($_[3]))" }

## String

# lowercase, uppercase
sub function_lc             { "lc($_[1])" }
sub function_uc             { "uc($_[1])" }
# lowercase, uppercase the first letter
sub function_lcfirst        { "lcfirst($_[1])" }
sub function_ucfirst        { "ucfirst($_[1])" }
# quote ', ", \, \n and \r in C-style, prepending \
sub function_quote          { "quotequote($_[1])" }
# quote " in SQL/CSV style (by doubling them)
sub function_sql_quote      { "sql_quote($_[1])" }
# escape characters special to regular expressions
sub function_requote        { "requote($_[1])" }
# encode URL parameter
sub function_urlencode      { shift; "URI::Escape::uri_escape(".join(",",@_).")" }
# decode URL parameter
sub function_urldecode      { shift; "URI::Escape::uri_unescape(".join(",",@_).")" }
# replace regexp: replace(<regex>, <replacement>, <subject>)
sub function_replace        { "regex_replace($_[1], $_[2], $_[3])" }
# replace substrings
sub function_str_replace    { "str_replace($_[1], $_[2], $_[3])" }
# character length of string
sub function_strlen         { "strlen($_[1])" }
# substring
sub function_substr         { shift; "substr(".join(",", @_).")" }
# remove starting and ending whitespace
sub function_trim           { shift; "trim($_[0])" }
# splice $2 with regexp $1, optionally maximum to $3 parts
sub function_split          { shift; "split(".join(",", @_).")" }
# replace & < > " ' with HTML entities
sub function_html           { "htmlspecialchars($_[1])" }
# remove HTML tags
sub function_strip          { "strip_tags($_[1])" }
# remove "unsafe" HTML tags
sub function_strip_unsafe   { "strip_unsafe_tags($_[1])" }
# replace \n with <br />
sub function_nl2br          { "regex_replace(qr/\\n/s, '<br />', $_[1])" }
# concatenate strings
sub function_concat         { fmop('.', @_) }
# join strings with delimiter specified as the first argument; expands all passed arrays
sub function_join           { fearr('join', 1, @_) }
# replace $1, $2 etc with passed arguments
sub function_subst          { fearr('exec_subst', 1, @_) }
# sprintf
sub function_sprintf        { fearr('sprintf', 1, @_) }
# strftime
sub function_strftime
{
    my $self = shift;
    my ($fmt, $date, $time) = @_;
    $date = "($date).' '.($time)" if $time;
    $date = "POSIX::strftime($date, localtime(timestamp($date)))";
    $date = "utf8on($date)" if $self->{use_utf8};
    return $date;
}
# limit $1 with $2 chars on whitespace boundary and add $3 (or '...' by default) if it is longer
sub function_strlimit       { shift; "strlimit(".join(",", @_).")" }
# select one of 3 russian plural forms based on first numeric argument: plural_ru($number, $one, $few, $many)
sub function_plural_ru      { shift; "plural_ru(".join(",", @_).")" }

## Arrays and hashes

# create a hash
sub function_hash           { shift; @_ == 1 ? "{ \@{ $_[0] } }" : "{" . join(",", @_) . "}"; }
# hash keys
sub function_keys           { '[ keys(%{'.$_[1].'}) ]'; }
# hash values
sub function_values         { '[ values(%{'.$_[1].'}) ]'; }
# sort array
sub function_sort           { '[ '.fearr('sort', 0, @_).' ]'; }
# extract [ { key => <key>, value => <value> }, ... ] pairs from first hash argument
sub function_pairs          { "exec_pairs($_[1])" }
# create an array
sub function_array          { shift; "[" . join(",", @_) . "]"; }
# create a numeric range array
sub function_range          { "[ $_[1] .. $_[2] ]" }
# check if the argument is an array
sub function_is_array       { "exec_is_array($_[1])" }
# count array (not hash) elements
sub function_count          { "(ref($_[1]) && $_[1] =~ /ARRAY/so ? scalar(\@{ $_[1] }) : 0)" }
# extract a contiguous slice of array
sub function_array_slice    { shift; "array_slice(" . join(",", @_) . ")"; }
# extract a regular slice of array
sub function_array_div      { shift; "array_div(" . join(",", @_) . ")"; }
# get array or hash element using a variable key (i.e. get(iteration.array, rand(5)))
sub function_get            { shift; "exec_get(" . join(",", @_) . ")"; }
# same only for hash
sub function_hget           { "($_[1])->\{$_[2]}" }
# same only for array
sub function_aget           { "($_[1])->\[$_[2]]" }
# set first argument to second (first argument must be an "lvalue")
sub function_set            { "scalar(($_[1] = $_[2]), '')" }
# merge arrays into one
sub function_array_merge    { shift; '[@{'.join('},@{',@_).'}]' }
# extract first argument of an array
sub function_shift          { "shift(\@{$_[1]})"; }
# extract last argument of an array
sub function_pop            { "pop(\@{$_[1]})"; }
# insert into beginning of an array
sub function_unshift        { shift; "unshift(\@{".shift(@_)."}, ".join(",", @_).")"; }
# insert into end of an array
sub function_push           { shift; "push(\@{".shift(@_)."}, ".join(",", @_).")"; }

## Misc

# explicitly ignore expression result (like void() in javascript)
sub function_void           { "scalar(($_[1]), '')" }
# dump variable
sub function_dump           { shift; "exec_dump(" . join(",", @_) . ")" }
# encode into JSON
sub function_json           { "encode_json($_[1])" }
# return the value as is, to ignore automatic escaping of "unsafe" HTML
sub function_raw            { $_[1] }
# call object method using variable name and inline arguments
sub function_call
{
    my $self = shift;
    my $obj = shift;
    my $method = shift;
    return "map({ ($obj)->\$_(".join(",", @_).") } $method)";
}
# call object method using variable name and array arguments
sub function_call_array
{
    my ($self, $obj, $method, $args) = @_;
    return "map({ ($obj)->\$_(\@\{$args}) } $method)";
}

# apply the function to each array element
sub function_map
{
    my $self = shift;
    my $fn = shift;
    if ($fn =~ /^[\"\'](\w+)[\"\']$/so)
    {
        return '(map { '.$self->compile_function($1, '$_').' } (@{'.join('}, @{', @_).'}))';
    }
    else
    {
        $self->{lexer}->warn("Non-constant function: unimplemented");
    }
}

## Template inclusion

# Include another template: parse('file.tpl'[, <args>])
# In all inclusion functions <args> may be a hash ref of a list of key+value pairs
# All modifications to <args> (or to current global "template vars") done
# by the included template are preserved after processing it!
sub function_parse
{
    my $self = shift;
    my $file = shift;
    my $args = @_ > 1 ? "{ ".join(", ", @_)." }" : (@_ ? $_[0] : '');
    return "\$self->{template}->parse_real($file, undef, 'main', $args)";
}

# Run block from current template: exec('block'[, <args>])
sub function_exec
{
    my $self = shift;
    my $block = shift;
    my $args = @_ > 1 ? "{ ".join(", ", @_)." }" : (@_ ? $_[0] : '');
    return "\$self->{template}->parse_real(\$FILENAME, undef, $block, $args)";
}

# Run block from another template: exec_from('file.tpl', 'block'[, args])
sub function_exec_from
{
    my $self = shift;
    my $file = shift;
    my $block = shift;
    my $args = @_ > 1 ? "{ ".join(", ", @_)." }" : (@_ ? $_[0] : '');
    return "\$self->{template}->parse_real($file, undef, $block, $args)";
}

# (Not recommended, but possible)
# Parse string as a template: parse('code'[, args])
sub function_parse_inline
{
    my $self = shift;
    my $code = shift;
    my $args = @_ > 1 ? "{ ".join(", ", @_)." }" : (@_ ? $_[0] : '');
    return "\$self->{template}->parse_real(undef, $code, 'main', $args)";
}

# (Highly not recommended, but still possible)
# Parse string as a template and run a named block from it: parse('code', 'block'[, args])
sub function_exec_from_inline
{
    my $self = shift;
    my $code = shift;
    my $block = shift;
    my $args = @_ > 1 ? "{ ".join(", ", @_)." }" : (@_ ? $_[0] : '');
    return "\$self->{template}->parse_real(undef, $code, $block, $args)";
}

1;
