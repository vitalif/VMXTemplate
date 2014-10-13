#!/usr/bin/perl

package VMXTemplate::Utils;

use strict;
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

our $safe_tags = 'div|blockquote|span|a|b|i|u|p|h1|h2|h3|h4|h5|h6|strike|strong|small|big|blink'.
    '|center|ol|pre|sub|sup|font|br|table|tr|td|th|tbody|tfoot|thead|tt|ul|li|em|img|marquee|cite';

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
    $str =~ s/([$escape\\])/\\$1/gs;
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

use overload '' => sub { $_[0]->{message} };

sub new
{
    my $class = shift;
    $class = ref($class) || $class;
    my ($msg) = @_;
    return bless { message => $msg }, $class;
}

1;
