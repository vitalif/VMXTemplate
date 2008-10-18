#!/usr/bin/perl
# Некоторые простые полезные функции

package VMX::Common;

use strict;
use utf8;
use Encode;

use DBI;
use Digest::MD5;
use Date::Parse;

require Exporter;

our @EXPORT_OK = qw(
    quotequote min max trim htmlspecialchars strip_tags strip_unsafe_tags
    file_get_contents dbi_hacks ar1el filemd5 mysql_quote updaterow_hashref
    insertall_hashref dumper_no_lf multiselectall_hashref str2time
);
our %EXPORT_TAGS = (all => [ @EXPORT_OK ]);

our $allowed_html = [qw/
    div span a b i u p h\d+ strike strong small big blink center ol pre sub
    sup font br table tr td th tbody tfoot thead tt ul li em img marquee
/];

# Exporter-ский импорт + подмена функции в DBI
sub import
{
    foreach (@_)
    {
        if ($_ eq '!dbi_hacks')
        {
            return Exporter::import(@_);
        }
        elsif ($_ eq 'dbi_hacks')
        {
            $_ = '!dbi_hacks';
        }
    }
    *DBI::_::st::fetchall_hashref = *VMX::Common::fetchall_hashref;
    *DBI::st::fetchall_hashref = *VMX::Common::fetchall_hashref;
    $DBI::DBI_methods{st}{fetchall_hashref} = { U =>[1,2,'[ $key_field ]'] };
    $DBI::DBI_methods{db}{selectall_hashref} = { U =>[2,0,'$statement [, $keyfield [, \%attr [, @bind_params ] ] ]'], O=>0x2000 };
	$Exporter::ExportLevel = 1;
    my $r = Exporter::import(@_);
	$Exporter::ExportLevel = 0;
	return $r;
}

# Функция возвращает минимальное из значений
# $r = min (@list)
sub min
{
    return undef if (@_ < 1);
    my $r = shift;
    foreach (@_) { $r = $_ if $r > $_; }
    return $r;
}

# Функция возвращает максимальное из значений
# $r = max (@list)
sub max
{
    return undef if (@_ < 1);
    my $r = shift;
    foreach (@_) { $r = $_ if $r < $_; }
    return $r;
}

# ar1el($a) - аналог ($a || [])->[0], только ещё проверяет, что $a есть arrayref
sub ar1el
{
	return undef unless 'ARRAY' eq ref $_[0];
	return shift @{$_[0]};
}

# Функция обрезает пробельные символы в начале и конце строки
# trim ($r) in-place
sub trim
{
    $_ = $_[0];
    s/^\s+//so;
    s/\s+$//so;
    $_;
}

# аналог HTML::Entities::encode_entities
# $str = htmlspecialchars ($str)
sub htmlspecialchars
{
    local $_ = shift;
    s/&/&apos;/gso;
    s/</&lt;/gso;
    s/>/&gt;/gso;
    s/\"/&quot;/gso;
    s/\'/&apos;/gso;
    return $_;
}

# удаление тегов из строки, кроме заданных
# $str = strip_tags ($str)
sub strip_tags
{
    $_ = shift;
    my $ex = join '|', @{(shift)};
    s/<\/?(?!\/?($ex))([a-z0-9_\-]+)[^<>]*>//gis;
    return $_;
}

# удаление небезопасных HTML тегов (всех кроме our $allowed_html)
sub strip_unsafe_tags
{
    strip_tags($_[0], $allowed_html);
}

# аналог File::Slurp
# $contents = file_get_contents ($filename)
sub file_get_contents
{
    my ($tmp, $res);
    open ($tmp, '<'.$_[0]);
    if ($tmp)
    {
		local $/ = undef;
        $res = <$tmp>;
        close ($tmp);
    }
    return $res;
}

# изменённый вариант функции DBI::_::st::fetchall_hashref
# <ни фига не нужный велосипед>
# делает то же что и $dbh->selectall_arrayref(..., {Slice=>{}}, ...);
sub fetchall_hashref
{
    my ($sth, $key_field) = @_;
    my $hash_key_name = $sth->{FetchHashKeyName} || 'NAME';
    my $names_hash = $sth->FETCH("${hash_key_name}_hash");
    my @key_fields = (ref $key_field) ? @$key_field : $key_field ? ($key_field) : ();
    my @key_indexes;
    my $num_of_fields = $sth->FETCH('NUM_OF_FIELDS');
    foreach (@key_fields)
    {
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
    while ($sth->fetch)
    {
        my $ref;
        if (@key_indexes)
        {
			$ref = $rows;
            $ref = $ref->{$row[$_]} ||= {} for @key_indexes;
        }
        else
        {
            push @$rows, {};
            $ref = $rows->[@$rows-1];
        }
        @$ref{@$NAME} = @row;
    }
    return $rows;
}

# Обновить все строки, у которых значения полей с названиями ключей %$key
# равны значениям %$key, установив в них поля с названиями ключей %$row
# значениям %$row
sub updaterow_hashref
{
    my ($dbh, $table, $row, $key) = @_;
    return 0 unless
        $dbh && $table &&
        $row && ref($row) eq 'HASH' && %$row &&
        $key && ref($key) eq 'HASH' && %$key;
    my @f = keys %$row;
    my @k = keys %$key;
    my $sql =
        'UPDATE `'.$table.'` SET '.
        join(', ', map { "`$_`=?" } @f).
        ' WHERE '.join(' AND ', map { "`$_`=?" } @k);
    my @bind = (@$row{@f}, @$key{@k});
    return $dbh->do($sql, {}, @bind);
}

# Вставить набор записей $rows = [{},{},{},...] в таблицу $table
# Возможно после этого дополнить каждую запись $reselect полями (напр. '*'),
# сделав дополнительный запрос выборки. Для этого требуются ещё поля
# `ji` INT DEFAULT NULL и `jin` INT DEFAULT NULL, и индекс по ним.
sub insertall_hashref
{
    my ($dbh, $table, $rows, $reselect, $replace) = @_;
    return 0 unless
        $dbh && $table && 
        $rows && ref($rows) eq 'ARRAY' && @$rows;
    my $conn_id = undef;
    if ($reselect)
    {
        my $i = 0;
        $conn_id = $dbh->{mysql_connection_id};
        @$_{'ji','jin'} = ($conn_id, ++$i) foreach @$rows;
    }
    my @f = keys %{$rows->[0]};
    my $sql = ($replace ? 'INSERT' : 'REPLACE').
        ' INTO `'.$table.'` (`'.join('`,`',@f).'`) VALUES '.
        join(',',('('.(join(',', ('?') x scalar(@f))).')') x scalar(@$rows));
    my @bind = map { @$_{@f} } @$rows;
    my $st = $dbh->do($sql, {}, @bind);
    return $st if !$st || !$reselect;
    if (ref($reselect) eq 'ARRAY')
    {
        $reselect = '`'.join('`,`',@$reselect).'`';
    }
    elsif ($reselect ne '*')
    {
        $reselect = "`$reselect`";
    }
    # осуществляем reselect данных
    $sql = "SELECT $reselect FROM `$table` WHERE `ji`=? ORDER BY `jin` ASC";
    @bind = ($conn_id);
    my $resel = $dbh->selectall_hashref($sql, [], {}, @bind);
    for (my $i = 0; $i < @$resel; $i++)
    {
        $rows->[$i]->{$_} = $resel->[$i]->{$_} for keys %{$resel->[$i]};
    }
    $sql = "UPDATE `$table` SET `ji`=NULL, `jin`=NULL WHERE `ji`=?";
    $dbh->do($sql, {}, @bind);
    return $st;
}

# вещь, о которой все мы, пользователи MySQL, давно мечтали - возможность
# сделать SELECT t1.*, t2.*, t3.* и при этом успешно разделить поля таблиц,
# распределив их по хешам. Только надо делать SELECT t1.*, 0 AS '_', t2.* и т.п,
# т.е. поля разных таблиц разделять неким разделителем, и указывать его
# качестве $split. $names - имена отдельных хешей.
sub multiselectall_hashref
{
    my ($dbh, $query, $bind, $split, $names) = @_;
    return undef unless ref($dbh) && $query && $split && $names && @$names;
    $bind ||= [];
    unless (ref $query)
    {
        # запрос преображаем в stmt
        $query = $dbh->prepare_cached($query);
        return undef unless $query;
    }
    # делаем запрос к базе
    $query->execute(@$bind);
    my $rows = $query->fetchall_arrayref({});
    return [] unless $rows && @$rows;
    my $nh;
    # DIRTY HACK :-)
    unless ((tied %$query)->{__hack_split_multiselect})
    {
        # массив имён ещё не построен, построим
        $nh = [[]];
        my $n = [ @{$query->{$query->{FetchHashKeyName}}} ];
        my $i = 0;
        foreach (@{$query->{$query->{FetchHashKeyName}}})
        {
            if ($_ eq $split)
            {
                $i++;
                $nh->[$i] = [];
            }
            else
            {
                push @{$nh->[$i]}, $_;
            }
        }
        (tied %$query)->{__hack_split_multiselect} = $nh;
    }
    else
    {
        # или возьмём из объекта запроса
        $nh = (tied %$query)->{__hack_split_multiselect};
    }
    # преобразуем строки
    my ($row, $nr, $i);
    foreach $row (@$rows)
    {
        $nr = {};
        for $i (0..$#$names)
        {
            last unless $names->[$i] && $nh->[$i];
            $nr->{$names->[$i]} = {};
            @{$nr->{$names->[$i]}}{@{$nh->[$i]}} = @$row{@{$nh->[$i]}};
        }
        $row = $nr;
    }
    # возвращаем результат
    return $rows;
}

# вычисление MD5 хеша от файла
sub filemd5
{
    my ($file) = @_;
    my $f;
    my $r;
    if (open $f, "<$file")
    {
        my $ctx = Digest::MD5->new;
        $ctx->addfile($f);
        $r = $ctx->hexdigest;
        close $f;
    }
    return $r;
}

# тоже <ни фига не нужный велосипед>, экранирование символов для MySQL,
# да ещё и несколько кривое
sub mysql_quote
{
	my ($a) = @_;
	$a =~ s/\'/\'\'/gso;
    $a =~ s/\\/\\\\/gso;
	return "'$a'";
}

# экранирование кавычек
sub quotequote
{
    my ($a) = @_;
    $a =~ s/\'|\"/\\$&/gso;
    return $a;
}

# Dumper без переводов строки
sub dumper_no_lf
{
    my $r = Data::Dumper::Dumper (@_);
    $r =~ s/\s+/ /giso;
    return $r;
}

# str2time, принимающий формат даты вида DD.MM.YYYY
sub str2time
{
    my ($str) = @_;
    $str =~ s/(\d{2})\.(\d{2})\.(\d{4})/$2\/$1\/$3/gso;
    return Date::Parse::str2time($str);
}

1;
__END__
