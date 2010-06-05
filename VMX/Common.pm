#!/usr/bin/perl
# Всякая полезная фигня с минимумом жёстких зависимостей

package VMX::Common;

use utf8;
use strict;
use Encode;

use constant {
    HASHARRAY   => {Slice=>{}},
    TS_UNIX     => 0,
    TS_DB       => 1,
    TS_DB_DATE  => 2,
    TS_MW       => 3,
    TS_EXIF     => 4,
    TS_ORACLE   => 5,
    TS_ISO_8601 => 6,
    TS_RFC822   => 7,
};

require Exporter;

our @EXPORT = qw(
    HASHARRAY
    TS_UNIX TS_MW TS_DB TS_DB_DATE TS_EXIF TS_ORACLE TS_ISO_8601 TS_RFC822
);
our @EXPORT_OK = qw(
    HASHARRAY quotequote min max trim htmlspecialchars strip_tags strip_unsafe_tags
    file_get_contents dbi_hacks ar1el filemd5 mysql_quote updaterow_hashref updateall_hashref
    insertall_arrayref insertall_hashref deleteall_hashref dumper_no_lf str2time callif urandom
    normalize_url utf8on utf8off rfrom_to mysql2time mysqllocaltime resub requote
    hashmrg litsplit strip_tagspace timestamp strlimit
), @EXPORT;
our %EXPORT_TAGS = (all => [ @EXPORT_OK ]);

# для strip_unsafe_tags()
our $allowed_html = [qw/
    div span a b i u p h\d+ strike strong small big blink center ol pre sub
    sup font br table tr td th tbody tfoot thead tt ul li em img marquee
/];

our @DATE_INIT = ("Language=Russian", "DateFormat=non-US");

my $uri_escape_original;

# Exporter-ский импорт + подмена функций в DBI и URI::Escape
sub import
{
    my @args = @_;
    my $dbi_hacks = 0;
    my $uri_escape_hacks = 0;
    my $export = { map { $_ => 1 } @EXPORT };
    foreach (@args)
    {
        if ($_ eq 'dbi_hacks')
        {
            $_ = '!dbi_hacks';
            $dbi_hacks = 1;
        }
        elsif ($_ eq 'uri_escape_hacks')
        {
            $_ = '!uri_escape_hacks';
            $uri_escape_hacks = 1;
        }
        elsif (substr($_,0,1) eq '!' && $export->{substr($_,1)})
        {
            delete $export->{substr($_,1)};
        }
    }
    push @args, keys %$export;
    if ($dbi_hacks)
    {
        require DBI;
        *DBI::_::st::fetchall_hashref = *VMX::Common::fetchall_hashref;
        *DBI::st::fetchall_hashref = *VMX::Common::fetchall_hashref;
        $DBI::DBI_methods{st}{fetchall_hashref} = { U =>[1,2,'[ $key_field ]'] };
        $DBI::DBI_methods{db}{selectall_hashref} = { U =>[2,0,'$statement [, $keyfield [, \%attr [, @bind_params ] ] ]'], O=>0x2000 };
    }
    if ($uri_escape_hacks)
    {
        require URI::Escape;
        $uri_escape_original = \&URI::Escape::uri_escape;
        *URI::Escape::uri_escape = *VMX::Common::uri_escape;
    }
    $Exporter::ExportLevel = 1;
    my $r = Exporter::import(@args);
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
# trim ($r)
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

# аналог HTML::Entities::encode_entities
# $str = htmlspecialchars ($str)
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

# удаление тегов из строки, кроме заданных
# $str = strip_tags ($str)
sub strip_tags
{
    local $_ = shift;
    my $ex = join '|', @{(shift || [])};
    $ex = "(?!/?($ex))" if $ex;
    s/<\/?$ex(!?[a-z0-9_\-]+)[^<>]*>//gis;
    return $_;
}

# преобразование \s+ и тегов в 1 пробел
sub strip_tagspace
{
    local $_ = shift;
    my $ex = join '|', @{(shift || [])};
    $ex = "(?!/?($ex))" if $ex;
    s/\s*(<\/?$ex(!?[a-z0-9_\-]+)[^<>]*>\s*)+/ /gis;
    s/\s+/ /gis;
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
# первая вещь - аналог fetchall_arrayref(HASHARRAY), т.е. просто возвращает
# массив хешей при передаче в качестве $key_field ссылки на пустой массив или undef.
# вторая вещь - о которой все мы, пользователи MySQL, давно мечтали - возможность
# сделать SELECT t1.*, t2.*, t3.* и при этом успешно разделить поля таблиц,
# распределив их по отдельным хешам.
# весь смысл в том, что при передаче в качестве $key_field хеша делает из каждой
# строчки вложенный hashref или arrayref, а колонки из результата запроса разделяет
# по $key_field->{Separator} или '_' по умолчанию.
# то есть например $dbh->selectall_hashref(
#    "SELECT t1.*, 0 AS `_`, t2.* FROM t1 JOIN t2 USING (join_field)",
#    { Separator => '_', Multi => [ 't1', 't2' ] }, {}
# ) вернёт ссылку на массив хешрефов вида { t1 => { ... }, t2 => { ... } },
# а если в качестве Multi передать просто скаляр, являющийся истиной (напр. 1),
# то вернёт ссылку на массив массивов вида [ { ... }, { ... } ].
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
    $key_field = [] unless
        ref($key_field->{Multi}) eq 'ARRAY' ||
        $key_field->{Multi} && !ref $key_field->{Multi};
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
    if (ref $hs) # если передана ссылка на массив - это имена в хеше
    {
        while ($sth->fetch)
        {
            push @$rows, $ref = {};
            for $i (0..$#$hs)
            {
                $ref->{$hs->[$i]} = {};
                @{$ref->{$hs->[$i]}}{@{$nh->[$i]}} = @row[@{$ni->[$i]}];
            }
        }
    }
    else # иначе это будут вложенные массивы
    {
        while ($sth->fetch)
        {
            push @$rows, $ref = [];
            for $i (0..$#$ni)
            {
                $ref->[$i] = {};
                @{$ref->[$i]}{@{$nh->[$i]}} = @row[@{$ni->[$i]}];
            }
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
        $key && (ref($key) eq 'HASH' && %$key || $key eq '1');
    my @f = keys %$row;
    my @bind = @$row{@f};
    my $sql = 'UPDATE `'.$table.'` SET '.join(', ', map { "`$_`=?" } @f);
    if ($key ne 1)
    {
        my @k = keys %$key;
        $sql .= ' WHERE '.join(' AND ', map { "`$_`=?" } @k);
        push @bind, @$key{@k};
    }
    return $dbh->do($sql, undef, @bind);
}

# Множественный UPDATE - обновить много строк @%$rows,
# но только по первичному ключу (каждая строка должна содержать его значение!)
sub updateall_hashref
{
    my ($dbh, $table, $rows) = @_;
    my @f = keys %{$rows->[0]};
    my $sql = "INSERT INTO `$table` (`".join("`,`",@f)."`) VALUES ".
        join(",",("(".(join(",", ("?") x scalar(@f))).")") x scalar(@$rows)).
        " ON DUPLICATE KEY UPDATE ".join(',', map { "`$_`=VALUES(`$_`)" } @f);
    my @bind = map { @$_{@f} } @$rows;
    return $dbh->do($sql, undef, @bind);
}

# Удалить все строки, у которых значения полей с названиями ключей %$key
# равны значениям %$key
sub deleteall_hashref
{
    my ($dbh, $table, $key) = @_;
    return 0 unless $dbh && $table &&
        $key && ref($key) eq 'HASH' && %$key;
    my $sql = [];
    my @bind;
    foreach (keys %$key)
    {
        if (!defined $key->{$_})
        {
            push @$sql, "`$_` IS NULL";
        }
        elsif (!ref $key->{$_})
        {
            push @$sql, "`$_`=?";
            push @bind, $key->{$_};
        }
        else
        {
            return unless @{$key->{$_}};
            # IN (?, ?, ?, ..., ?)
            push @$sql, "`$_` IN (" . join(",", ("?") x @{$key->{$_}}) . ")";
            push @bind, @{$key->{$_}};
        }
    }
    $sql = "DELETE FROM `$table` WHERE " . join " AND ", @$sql;
    return $dbh->do($sql, undef, @bind);
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
        $conn_id = $dbh->{mysql_thread_id};
        @$_{'ji','jin'} = ($conn_id, ++$i) foreach @$rows;
    }
    my @f = keys %{$rows->[0]};
    my $sql = ($replace ? 'REPLACE' : 'INSERT').
        ' INTO `'.$table.'` (`'.join('`,`',@f).'`) VALUES '.
        join(',',('('.(join(',', ('?') x scalar(@f))).')') x scalar(@$rows));
    my @bind = map { @$_{@f} } @$rows;
    my $st = $dbh->do($sql, undef, @bind);
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
    my $resel = $dbh->selectall_arrayref($sql, HASHARRAY, @bind) || [];
    for (my $i = 0; $i < @$resel; $i++)
    {
        $rows->[$i]->{$_} = $resel->[$i]->{$_} for keys %{$resel->[$i]};
    }
    $sql = "UPDATE `$table` SET `ji`=NULL, `jin`=NULL WHERE `ji`=?";
    $dbh->do($sql, undef, @bind);
    return $st;
}

# то же, но массив и без reselectов
sub insertall_arrayref
{
    my ($dbh, $table, $key, $rows, $replace) = @_;
    return 0 unless
        $dbh && $table &&
        $rows && ref($rows) eq 'ARRAY' && @$rows &&
        $key && ref($key) eq 'ARRAY' && @$key;
    my $sql = ($replace ? 'REPLACE' : 'INSERT').
        ' INTO `'.$table.'` (`'.join('`,`', @$key).'`) VALUES ';
    my $bind;
    if (ref $rows->[0])
    {
        $bind = [ map { @$_ } @$rows ];
        $sql .= join(',', ('('.(join(',', ('?') x scalar(@$key))).')') x scalar(@$rows));
    }
    else
    {
        $bind = $rows;
        $sql .= join(',', ('('.(join(',', ('?') x scalar(@$key))).')') x int(@$rows/@$key));
    }
    return $dbh->do($sql, undef, @$bind);
}

# вычисление MD5 хеша от файла
sub filemd5
{
    my ($file) = @_;
    my $f;
    my $r;
    if (open $f, "<$file")
    {
        require Digest::MD5;
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
my $init;
my $orig_DIRussian;
sub str2time
{
    my ($str) = @_;
    my $time;
    unless ($init)
    {
        require Date::Manip;
        $orig_DIRussian = \&Date::Manip::_Date_Init_Russian;
        *Date::Manip::_Date_Init_Russian = \&date_init_russian;
        Date::Manip::Date_Init(@DATE_INIT);
        $init = 1;
    }
    $str = lc $str;
    $time = Date::Manip::UnixDate(Date::Manip::ParseDate($str),"%s");
    return $time if defined $time;
    $time = $str;
    $time =~ s/(\d{2})\.(\d{2})\.(\d{4})/$2\/$1\/$3/gso;
    require Date::Parse;
    $time = Date::Parse::str2time($time);
    return $time;
}

my @Mon = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
my %mon = qw(jan 0 feb 1 mar 2 apr 3 may 4 jun 5 jul 6 aug 7 sep 8 oct 9 nov 10 dec 11);
my @Wday = qw(Sun Mon Tue Wed Thu Fri Sat);

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
    elsif ($ts =~ /^\D*(\d{4,})\D*(\d{2})\D*(\d{2})\D*(?:(\d{2})\D*(\d{2})\D*(\d{2})\D*([\+\- ]\d{2}\D*)?)?$/so)
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

sub date_init_russian
{
    my $r = &$orig_DIRussian(@_);
    rfrom_to($_[0], 'koi8-r', 'utf-8');
    utf8on($_[0]);
    $_[0]->{month_abb}->[1]->[2] = 'мар';
    return $r;
}

# если значение - вернуть значение, если coderef - вызвать и вернуть значение
sub callif
{
    my $sub = shift;
    if (ref($sub) eq 'CODE')
    {
        return &$sub(@_);
    }
    elsif ($sub)
    {
        return $sub;
    }
    return wantarray ? () : undef;
}

# чтение N байт из Crypt::Random, urandom или rand() в случае его отсутствия
my $no_crypt_random;
sub urandom
{
    my ($bs) = @_;
    return undef unless $bs && $bs > 0;
    if (!$no_crypt_random && !$INC{'Crypt/Random.pm'})
    {
        eval { require Crypt::Random; };
        $no_crypt_random = 1 if $@;
    }
    if (!$no_crypt_random)
    {
        return Crypt::Random::makerandom_octet(Length => $bs, Strength => 1);
    }
    my ($fd, $data);
    if (open $fd, "</dev/urandom")
    {
        read $fd, $data, $bs;
        close $fd;
    }
    else
    {
        $data .= pack("C",int(rand(256))) for 1..$bs;
    }
    return $data;
}

# Нормализация одной url относительно другой
sub normalize_url ($$)
{
    my ($base, $url) = @_;
    return $url if $url =~ m%^[a-z]+://%iso;
    if ($url =~ m%^/%so)
    {
        $base = $1 if $base =~ m%^([a-z]+://[^/]*)%iso;
    }
    elsif ($url =~ /^\?/so)
    {
        $base = $& if $base =~ m/^[^\?]*/so;
    }
    elsif ($url =~ s/^((\.\.\/)+)\/*//so)
    {
        my $n = length($1)/3;
        my $d;
        $base =~ m%^([a-z]+://[^/]*)/*(.*)$%iso;
        ($base, $d) = ($1, $2);
        $d =~ s!(/+[^/]*){0,$n}$!!s;
        $base .= '/';
        $base .= "$d/" if $d;
    }
    else
    {
        $base = $` if $base =~ m%[^\/]*$%so;
    }
    return $base.$url;
}

# uri_escape, автоматически дёргающий uri_escape_utf8 если текст is_utf8
# не вызывайте это напрямую! только при use VMX::Common qw(uri_escape_hacks);
sub uri_escape
{
    if (Encode::is_utf8($_[0]))
    {
        my $text = shift;
        Encode::_utf8_off($text);
        return &$uri_escape_original($text, @_);
    }
    return &$uri_escape_original(@_);
}

# utf8_on для скаляра или рекурсивный для хешей/массивов
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

# utf8_off для скаляра или рекурсивный для хешей/массивов
sub utf8off
{
    if (ref($_[0]) && $_[0] =~ /HASH/so)
    {
        utf8off($_[0]->{$_}) for keys %{$_[0]};
    }
    elsif (ref($_[0]) && $_[0] =~ /ARRAY/so)
    {
        utf8off($_) for @{$_[0]};
    }
    else
    {
        Encode::_utf8_off($_[0]);
    }
    return $_[0];
}

# преобразование mysql даты/времени в UNIX время
sub mysql2time
{
    require POSIX;
    $_[0] ? POSIX::mktime(mysqllocaltime(@_)) : 0
}

# и в struct tm
sub mysqllocaltime
{
    my ($date, $time) = @_;
    $time ||= '';
    if ("$date $time" =~ /^(\d+)-(\d+)-(\d+)(?:\s+(\d+):(\d+):(\d+))?/so)
    {
        return (int($6), int($5), int($4), int($3), int($2)-1, int($1)-1900);
    }
    return ();
}

# рекурсивная версия from_to
sub rfrom_to
{
    if (ref($_[0]) && $_[0] =~ /HASH/so)
    {
        rfrom_to($_[0]->{$_}, $_[1], $_[2]) for keys %{$_[0]};
    }
    elsif (ref($_[0]) && $_[0] =~ /ARRAY/so)
    {
        rfrom_to($_, $_[1], $_[2]) for @{$_[0]};
    }
    else
    {
        Encode::from_to($_[0], $_[1], $_[2]);
    }
    return $_[0];
}

# s///, возвращающий значение...
# $1 $2 и т.п. в $replacement не работают
# resub($re, $replacement, $value)
sub resub
{
    my ($re, $replacement, $value) = @_;
    $re = qr/$re/s unless ref $re eq 'REGEXP';
    $value =~ s/$re/$replacement/g;
    return $value;
}

# \Q\E от $_[0]
sub requote
{
    "\Q$_[0]\E";
}

# недеструктивное объединение хешрефов
sub hashmrg
{
    return undef unless @_;
    my $h;
    for (@_)
    {
        if ($_ && %$_)
        {
            if ($h)
            {
                $h = { %$h, %$_ };
            }
            else
            {
                $h = $_;
            }
        }
    }
    return $h;
}

# AQG = 'Apostrophe', "Quote", `Grave Accent`
our $litsplit_AQG = qr/\'(?:[^\'\\]+|\\.)+\'|\"(?:[^\"\\]+|\\.)+\"|\`(?:[^\`\\]+|\\.)+\`/;
our $litsplit_AQ = qr/\'(?:[^\'\\]+|\\.)+\'|\"(?:[^\"\\]+|\\.)+\"/;
our $litsplit_QG = qr/\"(?:[^\"\\]+|\\.)+\"|\`(?:[^\`\\]+|\\.)+\`/;
our $litsplit_AG = qr/\'(?:[^\'\\]+|\\.)+\'|\`(?:[^\`\\]+|\\.)+\`/;
our $litsplit_A = qr/\'(?:[^\'\\]+|\\.)+\'/;
our $litsplit_Q = qr/\"(?:[^\"\\]+|\\.)+\"/;
our $litsplit_G = qr/\`(?:[^\`\\]+|\\.)+\`/;

my $litsplit_types = {
    aqg => $litsplit_AQG,
    agq => $litsplit_AQG,
    qag => $litsplit_AQG,
    qga => $litsplit_AQG,
    gaq => $litsplit_AQG,
    gqa => $litsplit_AQG,
    aq  => $litsplit_AQ,
    qa  => $litsplit_AQ,
    gq  => $litsplit_QG,
    qg  => $litsplit_QG,
    ag  => $litsplit_AG,
    ga  => $litsplit_AG,
    a   => $litsplit_A,
    q   => $litsplit_Q,
    g   => $litsplit_G,
};

# разбиение строки по регэкспу, однако не как split(//), а с учётом литералов,
# входящих в строку. границы литералов можно задавать доп.аргументом
# по умолчанию заключённые в 'одинарные', "двойные", или `обратные` кавычки строки.
# @a = litsplit /PATTERN/, EXPR[, LIMIT[, /LITERAL_PATTERN/]]
# LITERAL_PATTERN может быть равно сочетаниям букв "aqg"
sub litsplit
{
    my ($re, $s, $lim, $lit) = @_;
    $lit = $litsplit_types->{lc $$lit} if ref($lit) eq 'SCALAR';
    $lit ||= $litsplit_AQG;
    my @r;
    my $l = 0;
    my $ml;
    $s =~ /^/g;
    while ($s =~ /\G((?:$lit|.+?)*?)$re/gc && (!$lim || $lim <= 0 || @r+1 < $lim))
    {
        push @r, $1;
    }
    push @r, substr($s, pos($s));
    return @r;
}

# ограничение длины строки $maxlen символами на границе пробелов и добавление '...', если что.
sub strlimit
{
    my ($str, $maxlen) = @_;
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
        # обрезаем
        $str = substr($str, 0, $p);
    }
    return $str . '...';
}

1;
__END__
