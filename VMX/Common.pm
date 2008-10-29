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
    insertall_hashref deleteall_hashref dumper_no_lf str2time
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
    local $_ = $_[0];
    s/^\s+//so;
    s/\s+$//so;
    $_;
}

# аналог HTML::Entities::encode_entities
# $str = htmlspecialchars ($str)
sub htmlspecialchars
{
    local $_ = $_[0];
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
    local $_ = shift;
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
# первая вещь - аналог fetchall_arrayref({Slice=>{}}), т.е. просто возвращает
# массив хешей при передаче в качестве $key_field ссылки на пустой массив или undef.
# вторая вещь - о которой все мы, пользователи MySQL, давно мечтали - возможность
# сделать SELECT t1.*, t2.*, t3.* и при этом успешно разделить поля таблиц,
# распределив их по отдельным хешам.
# весь смысл в том, что при передаче в качестве $key_field хеша делает из каждой
# строчки вложенный hashref, а колонки из результата запроса разделяет по
# $key_field->{Separator} или '_' по умолчанию.
# то есть например $dbh->selectall_hashref(
#    "SELECT t1.*, 0 AS `_`, t2.* FROM t1 JOIN t2 USING (join_field)",
#    { Separator => '_', Names => [ 't1', 't2' ] }, {}
# ) вернёт ссылку на массив хешрефов вида { t1 => { ... }, t2 => { ... } },
# т.е. поля t1 и t2 будут разделены по подхешам даже в случае, если в t1 и t2
# существуют поля с одинаковыми именами
# кроме того, кэширует все свои вспомогательные массивы в объекте запроса
# для дополнительной оптимальности
sub fetchall_hashref
{
    my ($sth, $key_field) = @_;
    return multifetchall_hashref($sth, $key_field) if ref($key_field) eq 'HASH';
    my $hash_key_name = $sth->{FetchHashKeyName} || 'NAME';
    my $names_hash = $sth->FETCH("${hash_key_name}_hash");
    my @key_fields = (ref $key_field) ? @$key_field : $key_field ? ($key_field) : ();
    my $cachename = "__cache_key_fields_".join "_", @key_fields;
    my $key_indexes = $sth->{$cachename};
    my $num_of_fields = $sth->FETCH('NUM_OF_FIELDS');
    unless ($key_indexes)
    {
        $key_indexes = [];
        foreach (@key_fields)
        {
            my $index = $names_hash->{$_}; # perl index not column
            $index = $_ - 1 if !defined $index && DBI::looks_like_number($_) && $_ >= 1 && $_ <= $num_of_fields;
            return $sth->set_err(1, "Field '$_' does not exist (not one of @{[keys %$names_hash]})")
                unless defined $index;
            push @$key_indexes, $index;
        }
        $sth->{$cachename} = $key_indexes;
    }
    my $rows = {};
    $rows = [] unless scalar @key_fields;
    my $NAME = $sth->FETCH($hash_key_name);
    my @row = (undef) x $num_of_fields;
    $sth->bind_columns(\(@row)) if @row;
    my $ref;
    if (scalar @key_fields)
    {
        while ($sth->fetch)
        {
            $ref = $rows;
            $ref = $ref->{$row[$_]} ||= {} for @$key_indexes;
            @$ref{@$NAME} = @row;
        }
    }
    else
    {
        while ($sth->fetch)
        {
            push @$rows, $ref = {};
            @$ref{@$NAME} = @row;
        }
    }
    return $rows;
}

# вот здесь-то и реализовано вертикальное разбиение результата
sub multifetchall_hashref
{
    my ($sth, $key_field) = @_;
    $key_field = [] unless ref($key_field->{Multi}) eq 'ARRAY';
    return fetchall_hashref($sth, $key_field) if ref($key_field) ne 'HASH';
    my $NAME = $sth->FETCH($sth->{FetchHashKeyName} || 'NAME');
    my $num_of_fields = $sth->FETCH('NUM_OF_FIELDS');
    my $cachename = "__cache_multi_key_fields";
    my ($nh, $ni, $i, $hs);
    unless ($sth->{$cachename})
    {
        # массивы индексов и имён ещё не построены, построим
        my $split = $key_field->{Separator} || '_';
        $nh = [[]];
        $ni = [[]];
        $i = 0;
        for my $k (0..$#$NAME)
        {
            if ($NAME->[$k] eq $split)
            {
                $i++;
                $nh->[$i] = [];
                $ni->[$i] = [];
            }
            else
            {
                push @{$nh->[$i]}, $NAME->[$k];
                push @{$ni->[$i]}, $k;
            }
        }
        $sth->{$cachename} = [ $nh, $ni ];
    }
    else
    {
        ($nh, $ni) = @{$sth->{$cachename}};
    }
    my $rows = [];
    my @row = (undef) x $num_of_fields;
    $sth->bind_columns(\(@row)) if @row;
    $hs = $key_field->{Multi};
    my $ref;
    while ($sth->fetch)
    {
        push @$rows, $ref = {};
        for $i (0..$#$hs)
        {
            $ref->{$hs->[$i]} = {};
            @{$ref->{$hs->[$i]}}{@{$nh->[$i]}} = @row[@{$ni->[$i]}];
        }
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

# Удалить все строки, у которых значения полей с названиями ключей %$key
# равны значениям %$key
sub deleteall_hashref
{
    my ($dbh, $table, $key) = @_;
    return 0 unless $dbh && $table &&
        $key && ref($key) eq 'HASH' && %$key;
    my @k = keys %$key;
    my $sql = "DELETE FROM `$table` WHERE ".join(" AND ", map { "`$_`=?" } @k);
    my @bind = (@$key{@k});
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
    my $sql = ($replace ? 'REPLACE' : 'INSERT').
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
