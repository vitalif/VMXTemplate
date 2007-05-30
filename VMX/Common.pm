#!/usr/bin/perl

=head1 Некоторые простые полезные функции
=cut

package VMX::Common;

use DBI;
use Digest::MD5;
require Exporter;

@EXPORT_OK = qw(min max trim htmlspecialchars strip_tags file_get_contents fetchall_hashref ar1el filemd5);
%EXPORT_TAGS = (all => [qw(min max trim htmlspecialchars strip_tags file_get_contents ar1el filemd5)]);

##
 # Exporter-ский импорт + возможность подмены функции в DBI
 ##
sub import {
    foreach (@_) {
        if ($_ eq '!fetchall_hashref') {
            return Exporter::import(@_);
        }
    }
    *DBI::_::st::fetchall_hashref = *VMX::Common::fetchall_hashref;
    *DBI::st::fetchall_hashref = *VMX::Common::fetchall_hashref;
    $DBI::DBI_methods{st}{fetchall_hashref} = { U =>[1,2,'[ $key_field ]'] };
    $DBI::DBI_methods{db}{selectall_hashref} = { U =>[2,3,'$statement [, $keyfield [, \%attr [, @bind_params ] ] ]'], O=>0x2000 };
	$Exporter::ExportLevel = 1;
    my $r = Exporter::import(@_);
	$Exporter::ExportLevel = 0;
	return $r;
}

##
 # Функция возвращает минимальное из значений
 # $r = min (@list)
 ##
sub min {
    return undef if (@_ < 1);
    my $r = shift;
    foreach (@_) { $r = $_ if $r > $_; }
    return $r;
}

##
 # Функция возвращает максимальное из значений
 # $r = max (@list)
 ##
sub max {
    return undef if (@_ < 1);
    my $r = shift;
    foreach (@_) { $r = $_ if $r < $_; }
    return $r;
}

##
 # shift arrayref
 ##
sub ar1el {
	my $a = shift;
	return undef unless 'ARRAY' eq ref $a;
	return shift @$a;
}

##
 # Функция обрезает пробельные символы в начале и конце строки
 # $r = trim ($r)
 ##
sub trim {
    my $a = shift;
    $a =~ s/^\s+|\s+$//os;
    return $a;
}

##
 # аналог htmlspecialchars из PHP
 # $str = htmlspecialchars ($str)
 ##
sub htmlspecialchars {
    $_ = shift;
    s/&/&apos;/g;
    s/</&lt;/g;
    s/>/&gt;/g;
    s/\"/&quot;/g;
    s/\'/&apos;/g;
    return $_;
}

##
 # аналог strip_tags из PHP
 # $str = strip_tags ($str)
 ##
sub strip_tags {
    $_ = shift;
    my $ex = join '|', (shift =~ /[a-z0-9_\-]+/giso);
    s/<\/?(?!\/?($ex))([a-z0-9_\-]+)[^<>]*>//gis;
    return $_;
}

##
 # аналог file_get_contents из PHP
 # $contents = file_get_contents ($filename)
 ##
sub file_get_contents {
    my ($tmp, $res);
    open ($tmp, '<'.$_[0]);
    if ($tmp) {
		local $/ = undef;
        $res = <$tmp>;
        close ($tmp);
    }
    return $res;
}

##
 # изменённый вариант функции DBI::_::st::fetchall_hashref
 ##
sub fetchall_hashref {
    my ($sth, $key_field) = @_;
    my $hash_key_name = $sth->{FetchHashKeyName} || 'NAME';
    my $names_hash = $sth->FETCH("${hash_key_name}_hash");
    my @key_fields = (ref $key_field) ? @$key_field : $key_field ? ($key_field) : ();
    my @key_indexes;
    my $num_of_fields = $sth->FETCH('NUM_OF_FIELDS');
    foreach (@key_fields) {
       my $index = $names_hash->{$_};  # perl index not column
       $index = $_ - 1 if !defined $index && DBI::looks_like_number($_) && $_>=1 && $_ <= $num_of_fields;
       return $sth->set_err(1, "Field '$_' does not exist (not one of @{[keys %$names_hash]})")
            unless defined $index;
       push @key_indexes, $index;
    }
    my $rows = {};
    $rows = [] unless @key_indexes;
    my $NAME = $sth->FETCH($hash_key_name);
    my @row = (undef) x $num_of_fields;
    $sth->bind_columns(\(@row)) if @row;
    while ($sth->fetch) {
        my $ref;
        if (@key_indexes) {
			$ref = $rows;
            $ref = $ref->{$row[$_]} ||= {} for @key_indexes;
        } else {
            push @$rows, {};
            $ref = $rows->[@$rows-1];
        }
        @$ref{@$NAME} = @row;
    }
    return $rows;
}

sub filemd5 {
    my ($file) = @_;
    my $f;
    my $r;
    if (open $f, "<$file") {
        my $ctx = Digest::MD5->new;
        $ctx->addfile($f);
        $r = $ctx->hexdigest;
        close $f;
    }
    return $r;
}

1;