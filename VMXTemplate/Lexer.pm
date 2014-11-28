#!/usr/bin/perl

package VMXTemplate::Lexer;

use strict;
use VMXTemplate::Utils;

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
        skip_chars => 0,
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
    $self->{skip_chars} = $self->{last_start} = $self->{last_start_line} = 0;
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
    $self->{code} = substr($self->{eaten}, $self->{last_start}, length($self->{eaten}), '') . $self->{code};
    $self->{skip_chars} = 1;
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
        my $code_pos = index($self->{code}, $self->{options}->{begin_code}, $self->{skip_chars});
        my $subst_pos = $self->{options}->{begin_subst} ne '' ? index($self->{code}, $self->{options}->{begin_subst}, $self->{skip_chars}) : -1;
        $self->{skip_chars} = 0;
        if ($code_pos == -1 && $subst_pos == -1)
        {
            # No more directives
            $r = [ 'literal', [ "'".addcslashes($self->eat(length $self->{code}), "'")."'", 1 ] ];
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
                $r = [ 'literal', [ "'".addcslashes($str, "'")."'", 1 ] ];
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
                $r = [ 'literal', [ "'".addcslashes($self->eat($subst_pos), "'")."'", 1 ] ];
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
        (\")(?:[^\"\\]+|\\.)*\" |
        \'(?:[^\'\\]+|\\.)*\' |
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

1;
