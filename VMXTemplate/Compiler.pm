#!/usr/bin/perl

package VMXTemplate::Compiler;

use strict;
use VMXTemplate::Utils;
use VMXTemplate::Lexer;

sub _Lexer
{
    my ($parser) = shift;
    return $parser->{lexer}->read_token;
}

sub _error
{
    my ($self) = @_;
    if ($self->YYCurtok ne 'error')
    {
        $self->{lexer}->warn('Unexpected ' . $self->YYCurtok . ($self->YYCurval ? ' ' . $self->YYCurval : ''));
    }
    $self->{lexer}->skip_error;
}

sub compile
{
    my ($self, $text) = @_;
    $self->{lexer} ||= VMXTemplate::Lexer->new($self->{options});
    $self->{lexer}->set_code($text);
    $self->{functions} = {
        ':main' => {
            name => ':main',
            args => [],
            body => '',
            line => 0,
            pos => 0,
        },
    };
    $self->YYParse(yylex => \&_Lexer, yyerror => \&_error);
    if (!$self->{functions}->{':main'}->{body})
    {
        # Parse error?
        delete $self->{functions}->{':main'};
    }
    return ($self->{options}->{use_utf8} ? "use utf8;\n" : "").
        ($self->{options}->{input_filename} ? "# $self->{options}->{input_filename}\n" : '').
        "{\n':version' => ".VMXTemplate->CODE_VERSION.",\n".
        join(",\n", map { "'$_->{name}' => $_->{body}" } values %{$self->{functions}})."};\n";
}

# Function aliases
my $functions = {
    i                   => 'int',
    intval              => 'int',
    lower               => 'lc',
    lowercase           => 'lc',
    upper               => 'uc',
    uppercase           => 'uc',
    addslashes          => 'quote',
    q                   => 'quote',
    re_quote            => 'requote',
    preg_quote          => 'requote',
    uri_escape          => 'urlencode',
    uriquote            => 'urlencode',
    substring           => 'substr',
    htmlspecialchars    => 'html',
    s                   => 'html',
    strip_tags          => 'strip',
    t                   => 'strip',
    h                   => 'strip_unsafe',
    sq                  => 'sql_quote',
    implode             => 'join',
    truncate            => 'strlimit',
    hash_keys           => 'keys',
    array_keys          => 'keys',
    array_slice         => 'subarray',
    hget                => 'get',
    aget                => 'get',
    var_dump            => 'dump',
    process             => 'parse',
    include             => 'parse',
    process_inline      => 'parse_inline',
    include_inline      => 'parse_inline',
    subarray            => 'array_slice',
    subarray_divmod     => 'array_div',
};

# Function result "safeness" constants:
# N > 0 means "safe if Nth argument is safe"
use constant Q_ALWAYS => -1; # always safe
use constant Q_IF_ALL => -2; # safe if all arguments are safe
use constant Q_ALL_BUT_FIRST => -3; # safe if all arguments except first are safe; first may be safe or unsafe
use constant Q_ALWAYS_NUM => -4; # always safe, returns numeric values
use constant Q_PASS => -5; # pass safeness to function

my $functionSafeness = {
    int                 => Q_ALWAYS_NUM,
    raw                 => Q_ALWAYS,
    html                => Q_ALWAYS,
    strip               => Q_ALWAYS,
    strip_unsafe        => Q_ALWAYS,
    parse               => Q_ALWAYS,
    parse_inline        => Q_ALWAYS,
    exec                => Q_ALWAYS,
    exec_from           => Q_ALWAYS,
    exec_from_inline    => Q_ALWAYS,
    quote               => Q_ALWAYS,
    sql_quote           => Q_ALWAYS,
    requote             => Q_ALWAYS,
    urlencode           => Q_ALWAYS,
    and                 => Q_ALWAYS,
    or                  => Q_IF_ALL,
    not                 => Q_ALWAYS_NUM,
    add                 => Q_ALWAYS_NUM,
    sub                 => Q_ALWAYS_NUM,
    mul                 => Q_ALWAYS_NUM,
    div                 => Q_ALWAYS_NUM,
    mod                 => Q_ALWAYS_NUM,
    min                 => Q_IF_ALL_PASS,
    max                 => Q_IF_ALL_PASS,
    log                 => Q_ALWAYS_NUM,
    even                => Q_ALWAYS_NUM,
    odd                 => Q_ALWAYS_NUM,
    eq                  => Q_ALWAYS_NUM,
    ne                  => Q_ALWAYS_NUM,
    gt                  => Q_ALWAYS_NUM,
    lt                  => Q_ALWAYS_NUM,
    ge                  => Q_ALWAYS_NUM,
    le                  => Q_ALWAYS_NUM,
    seq                 => Q_ALWAYS_NUM,
    sne                 => Q_ALWAYS_NUM,
    sgt                 => Q_ALWAYS_NUM,
    slt                 => Q_ALWAYS_NUM,
    sge                 => Q_ALWAYS_NUM,
    sle                 => Q_ALWAYS_NUM,
    neq                 => Q_ALWAYS_NUM,
    nne                 => Q_ALWAYS_NUM,
    ngt                 => Q_ALWAYS_NUM,
    nlt                 => Q_ALWAYS_NUM,
    nge                 => Q_ALWAYS_NUM,
    nle                 => Q_ALWAYS_NUM,
    strlen              => Q_ALWAYS_NUM,
    strftime            => Q_ALWAYS,
    str_replace         => Q_ALL_BUT_FIRST,
    substr              => 1,   # parameter number to take safeness from
    trim                => 1,
    split               => 1,
    nl2br               => 1,
    concat              => Q_IF_ALL,
    join                => Q_IF_ALL,
    subst               => Q_IF_ALL,
    strlimit            => 1,
    plural_ru           => Q_ALL_BUT_FIRST,
    hash                => Q_IF_ALL,
    keys                => 1,
    values              => 1,
    sort                => 1,
    pairs               => 1,
    array               => Q_IF_ALL,
    range               => Q_ALWAYS,
    is_array            => Q_ALWAYS_NUM,
    count               => Q_ALWAYS_NUM,
    array_slice         => 1,
    array_div           => 1,
    set                 => 2,
    array_merge         => Q_IF_ALL,
    shift               => 1,
    pop                 => 1,
    unshift             => Q_ALWAYS,
    push                => Q_ALWAYS,
    void                => Q_ALWAYS,
    json                => Q_ALWAYS,
    map                 => Q_ALL_BUT_FIRST,
    yesno               => Q_ALL_BUT_FIRST,
};

my $forceSubst = {
    parse               => 1,
    parse_inline        => 1,
    exec                => 1,
    exec_from           => 1,
    exec_from_inline    => 1,
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
    my $fl = $functionSafeness->{$fn};
    my $q;
    if ($fl > 0)
    {
        $q = exists $args->[$fl-1] ? $args->[$fl-1]->[1] : 1;
    }
    elsif ($fl == Q_ALWAYS)
    {
        $q = 1;
    }
    elsif ($fl == Q_ALWAYS_NUM)
    {
        $q = 'i';
    }
    elsif ($fl != Q_PASS)
    {
        $q = 1;
        my $n = scalar @$args;
        for (my $i = ($fl == Q_ALL_BUT_FIRST ? 1 : 0); $i < $n; $i++)
        {
            $q = $q && $args->[$i]->[1];
        }
    }
    my $argv = $fl == Q_PASS ? [ map { $_->[0] } @$args ] : $argv;
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
        $r = $fl == Q_PASS ? [ "''", 1 ] : "''";
    }
    $r = [ $r, $q ] if $fl != Q_PASS;
    push @$r, 1 if $forceSubst->{$fn};
    return $r;
}

# call operator on arguments
sub fmop
{
    my $op = shift;
    my $self = shift;
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
# min, max
sub function_min     { (grep { $_->[1] ne 'i' } @_ ? 'str_' : '')."min(".join(', ', map { $_->[0] } @_).")" }
sub function_max     { (grep { $_->[1] ne 'i' } @_ ? 'str_' : '')."max(".join(', ', map { $_->[0] } @_).")" }
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
sub function_urlencode      { "urlencode($_[1])" }
# decode URL parameter
sub function_urldecode      { "urldecode($_[1])" }
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
    if ($date)
    {
        $date = "($date).' '.($time)" if $time;
        $date = "timestamp($date)";
    }
    else
    {
        $date = '';
    }
    $date = "POSIX::strftime($fmt, localtime($date))";
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
sub function_dump           { shift; "var_dump(" . join(",", @_) . ")" }
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
    return "[ map { scalar ($obj)->\$_(".join(",", @_).") } $method ]->[0]";
}
# call object method using variable name and array arguments
sub function_call_array
{
    my ($self, $obj, $method, $args) = @_;
    return "[ map { scalar ($obj)->\$_(\@\{$args}) } $method ]->[0]";
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
    $self->{lexer}->warn("include() requires at least 1 parameter"), return "''" if !$file;
    my $args = @_ > 1 ? "{ ".join(", ", @_)." }" : (@_ ? $_[0] : '');
    return "\$self->parse_real($file, undef, ':main', $args)";
}

# Run block from current template: exec('block'[, <args>])
sub function_exec
{
    my $self = shift;
    my $block = shift;
    $self->{lexer}->warn("exec() requires at least 1 parameters"), return "''" if !$block;
    my $args = @_ > 1 ? "{ ".join(", ", @_)." }" : (@_ ? $_[0] : 'undef');
    return "\$self->_call_block($block, $args, '".addcslashes($self->{lexer}->errorinfo(), "'")."')";
}

# Run block from another template: exec_from('file.tpl', 'block'[, args])
sub function_exec_from
{
    my $self = shift;
    my $file = shift;
    my $block = shift;
    $self->{lexer}->warn("exec_from() requires at least 2 parameters"), return "''" if !$file || !$block;
    my $args = @_ > 1 ? "{ ".join(", ", @_)." }" : (@_ ? $_[0] : '');
    return "\$self->parse_real($file, undef, $block, $args)";
}

# (Not recommended, but possible)
# Parse string as a template: parse_inline('code'[, args])
sub function_parse_inline
{
    my $self = shift;
    my $code = shift;
    $self->{lexer}->warn("parse_inline() requires at least 1 parameter"), return "''" if !$code;
    my $args = @_ > 1 ? "{ ".join(", ", @_)." }" : (@_ ? $_[0] : '');
    return "\$self->parse_real(undef, $code, ':main', $args)";
}

# (Highly not recommended, but still possible)
# Parse string as a template and run a named block from it: exec_from_inline('code', 'block'[, args])
sub function_exec_from_inline
{
    my $self = shift;
    my $code = shift;
    my $block = shift;
    $self->{lexer}->warn("exec_from_inline() requires at least 2 parameters"), return "''" if !$code || !$block;
    my $args = @_ > 1 ? "{ ".join(", ", @_)." }" : (@_ ? $_[0] : '');
    return "\$self->parse_real(undef, $code, $block, $args)";
}

1;
