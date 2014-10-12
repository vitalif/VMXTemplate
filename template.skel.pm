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
    return bless $class->SUPER::new(
        yyversion => '<<$version>>',
        yystates =>
<<$states>>,
        yyrules =>
<<$rules>>,
#line 30 "template.skel.pm"
        @_
    ), $class;
}

sub _Lexer
{
    my ($parser) = shift;
    return $parser->{__lexer}->read_token;
}

sub _error
{
    my ($self) = @_;
    $self->{__lexer}->warn('Unexpected ' . $self->YYCurtok . ($self->YYCurval ? ' ' . $self->YYCurval : ''));
    $self->{__lexer}->skip_error;
}

sub compile
{
    my ($self, $text) = @_;
    $self->{__lexer} ||= new VMXTemplate::Lexer($self, $self->{__options});
    $self->{__lexer}->set_code($text);
    $self->YYParse(yylex => \&_Lexer, yyerror => \&_error);
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
    my $charpos;
    {
        use bytes;
        $charpos = length $self->{eaten};
    }
    return ' in '.$self->{options}->{input_filename}.', line '.($self->{lineno}+1).
        ', character '.$charpos.', marked by ^^^ in '.$line;
}

sub warn
{
    my $self = shift;
    my ($text) = @_;
    $self->{options}->error($text.$self->errorinfo());
}

package VMXTemplate::Utils;

use base qw(Exporter);
our @EXPORT = qw(
    TS_UNIX TS_DB TS_DB_DATE TS_MW TS_EXIF TS_ORACLE TS_ISO_8601 TS_RFC822
    timestamp plural_ru strlimit strip_tags addcslashes requote
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

# ограниченная распознавалка дат
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

package VMXTemplate::Compiler;

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

sub fmop
{
    my $op = shift;
    return "((" . join(") $op (", @_) . "))";
}

# логические операции
sub function_or      { fmop('||', @_) }
sub function_and     { fmop('&&', @_) }
sub function_not     { "!($_[1])" }
# арифметические операции
sub function_add     { fmop('+', @_) }
sub function_sub     { fmop('-', @_) }
sub function_mul     { fmop('*', @_) }
sub function_div     { fmop('/', @_) }
sub function_mod     { fmop('%', @_) }
# логарифм
sub function_log     { "log($_[1])" }
# чётный, нечётный
sub function_even    { "!(($_[1]) & 1)" }
sub function_odd     { "(($_[1]) & 1)" }
# приведение к целому числу
sub function_int     { "int($_[1])" }
# сравнения: = != > < >= <= (типозависимые)
sub function_eq      { "(exec_cmp($_[1], $_[2]) == 0)" }
sub function_ne      { "(exec_cmp($_[1], $_[2]) != 0)" }
sub function_gt      { "(exec_cmp($_[1], $_[2]) > 0)" }
sub function_lt      { "(exec_cmp($_[1], $_[2]) < 0)" }
sub function_ge      { "(exec_cmp($_[1], $_[2]) >= 0)" }
sub function_le      { "(exec_cmp($_[1], $_[2]) <= 0)" }
# сравнения: = != > < >= <= (строковые)
sub function_seq     { "(($_[1]) eq ($_[2]))" }
sub function_sne     { "(($_[1]) ne ($_[2]))" }
sub function_sgt     { "(($_[1]) gt ($_[2]))" }
sub function_slt     { "(($_[1]) lt ($_[2]))" }
sub function_sge     { "(($_[1]) ge ($_[2]))" }
sub function_sle     { "(($_[1]) le ($_[2]))" }
# сравнения: = != > < >= <= (численные)
sub function_neq     { "(($_[1]) == ($_[2]))" }
sub function_nne     { "(($_[1]) != ($_[2]))" }
sub function_ngt     { "(($_[1]) >  ($_[2]))" }
sub function_nlt     { "(($_[1]) <  ($_[2]))" }
sub function_nge     { "(($_[1]) >= ($_[2]))" }
sub function_nle     { "(($_[1]) <= ($_[2]))" }
# тернарный оператор $1 ? $2 : $3
sub function_yesno   { "(($_[1]) ? ($_[2]) : ($_[3]))" }

## Строки

# нижний и верхний регистр
sub function_lc             { "lc($_[1])" }
sub function_uc             { "uc($_[1])" }
# нижний и верхний регистр первого символа
sub function_lcfirst        { "lcfirst($_[1])" }
sub function_ucfirst        { "ucfirst($_[1])" }
# экранировать двойные и одинарные кавычки в стиле C (добавить \)
sub function_quote          { "quotequote($_[1])" }
# экранировать двойные кавычки в стиле SQL/CSV (удвоением)
sub function_sql_quote      { "sql_quote($_[1])" }
# экранирование символов, специальных для регулярного выражения
sub function_requote        { "requote($_[1])" }
# кодировать символы в стиле URL
sub function_urlencode      { shift; "URI::Escape::uri_escape(".join(",",@_).")" }
# декодировать символы в стиле URL
sub function_urldecode      { shift; "URI::Escape::uri_unescape(".join(",",@_).")" }
# замена регэкспов
sub function_replace        { "regex_replace($_[1], $_[2], $_[3])" }
# замена подстрок (а не регэкспов)
sub function_str_replace    { "str_replace($_[1], $_[2], $_[3])" }
# длина строки в символах
sub function_strlen         { "strlen($_[1])" }
# подстрока
sub function_substr         { shift; "substr(".join(",", @_).")" }
# обрезать пробелы из начала и конца строки
sub function_trim           { shift; "trim($_[0])" }
# разделить строку $2 по регулярному выражению $1 опционально с лимитом $3
sub function_split          { shift; "split(".join(",", @_).")" }
# заменить символы & < > " ' на HTML-сущности
sub function_html           { "htmlspecialchars($_[1])" }
# удалить все HTML-теги
sub function_strip          { "strip_tags($_[1])" }
# оставить только "безопасные" HTML-теги
sub function_strip_unsafe   { "strip_unsafe_tags($_[1])" }
# заменить \n на <br />
sub function_nl2br          { "regex_replace(qr/\\n/s, '<br />', $_[1])" }
# конкатенация строк
sub function_concat         { fmop('.', @_) }
# объединяет не просто скаляры, а также все элементы массивов
sub function_join           { fearr('join', 1, @_) }
# подставляет на места $1, $2 и т.п. в строке аргументы
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
# ограничение длины строки $maxlen символами на границе пробелов и добавление '...', если что.
sub function_strlimit       { shift; "strlimit(".join(",", @_).")" }
# выбор правильной формы множественного числа для русского языка
sub function_plural_ru      { shift; "plural_ru(".join(",", @_).")" }

## Массивы и хеши

# создание хеша
sub function_hash           { shift; @_ == 1 ? "{ \@{ $_[0] } }" : "{" . join(",", @_) . "}"; }
# hash keys, values
sub function_keys           { '[ keys(%{'.$_[1].'}) ]'; }
sub function_values         { '[ values(%{'.$_[1].'}) ]'; }
# сортировка массива
sub function_sort           { '[ '.fearr('sort', 0, @_).' ]'; }
# пары { id => ключ, name => значение } для хеша
sub function_pairs          { "exec_pairs($_[1])" }
# создание массива
sub function_array          { shift; "[" . join(",", @_) . "]"; }
# диапазон значений
sub function_range          { "[ $_[1] .. $_[2] ]" }
# проверка, аргумент - массив или не массив?
sub function_is_array       { "exec_is_array($_[1])" }
# количество элементов _массива_ (не хеша)
sub function_count          { "(ref($_[1]) && $_[1] =~ /ARRAY/so ? scalar(\@{ $_[1] }) : 0)" }
# подмассив по номерам элементов
sub function_array_slice    { shift; "array_slice(" . join(",", @_) . ")"; }
# подмассив по кратности номеров элементов
sub function_array_div      { shift; "array_div(" . join(",", @_) . ")"; }
# получить элемент хеша/массива по неконстантному ключу (например get(iteration.array, rand(5)))
# по-моему, это лучше, чем Template Toolkit'овский ад - hash.key.${another.hash.key}.зюка.хрюка и т.п.
sub function_get            { shift; "exec_get(" . join(",", @_) . ")"; }
# для хеша
sub function_hget           { "($_[1])->\{$_[2]}" }
# для массива
sub function_aget           { "($_[1])->\[$_[2]]" }
# присваивание (только lvalue)
sub function_set            { "scalar(($_[1] = $_[2]), '')" }
# слияние массивов в один большой массив
sub function_array_merge    { shift; '[@{'.join('},@{',@_).'}]' }
# вынуть первый элемент массива
sub function_shift          { "shift(\@{$_[1]})"; }
# вынуть последний элемент массива
sub function_pop            { "pop(\@{$_[1]})"; }
# вставить как первый элемент массива
sub function_unshift        { shift; "unshift(\@{".shift(@_)."}, ".join(",", @_).")"; }
# вставить как последний элемент массива
sub function_push           { shift; "push(\@{".shift(@_)."}, ".join(",", @_).")"; }

## Прочее

# вычисление выражения и игнорирование результата, как в JS
sub function_void           { "scalar(($_[1]), '')" }
# дамп переменной
sub function_dump           { shift; "exec_dump(" . join(",", @_) . ")" }
# JSON-кодирование
sub function_json           { "encode_json($_[1])" }
# return the value as is, to ignore automatic escaping of "unsafe" HTML
sub function_raw            { $_[1] }
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

1;
