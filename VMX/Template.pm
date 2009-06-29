#!/usr/bin/perl
# Простой шаблонный движок.
# Когда-то inspired by phpBB templates, которые в свою очередь inspired by
# phplib templates. Однако уже далеко ушедши от них обоих.

package VMX::Template;

use strict;
use VMX::Common qw(:all);
use Digest::MD5 qw(md5_hex);
use Hash::Merge;

my $mtimes = {};            # время изменения файлов
my $uncompiled_code = {};   # нескомпилированный код
my $compiled_code = {};     # скомпилированный код (sub'ы)
my $langhashes = {};        # хеши ленгпаков
my %assigncache = {};       # кэш eval'ов присвоений

# Конструктор
# $obj = new VMX::Template, %params
sub new
{
    my $class = shift;
    $class = ref ($class) || $class;
    my $self =
    {
        conv =>
        {
            # char => func_name | \&sub_ref
            T => 'strip_tags',
            i => 'int',
            s => 'htmlspecialchars',
            l => 'lc',
            u => 'uc',
            q => 'quotequote',
            H => 'strip_unsafe_tags',
            L => \&language_ref,
            Lz => \&language_refnull,
        },
        tests =>
        {
            '!'  => [ '!', 0 ],
            odd  => [ 'test_odd', 0 ],
            even => [ 'test_even', 0 ],
            mod  => [ 'test_mod', 1 ],
            eq   => [ 'test_eq', 1 ],
        },
        root            => '.',   # каталог с шаблонами
        reload          => 1,     # если 0, шаблоны не будут перечитываться с диска, и вызовов stat() происходить не будет
        wrapper         => undef, # фильтр, вызываемый перед выдачей результата parse
        tpldata         => {},    # сюда будут сохранены: данные
        lang            => {},    # ~ : языковые данные
        tpldata_stack   => [],    # стек tpldata-ы для datapush и datapop
        cache_dir       => undef, # необязательный кэш, ускоряющий работу только в случае частых инициализаций интерпретатора
        use_utf8        => undef, # шаблоны в UTF-8 и с флагом UTF-8
        @_,
    };
    $self->{cache_dir} =~ s!/*$!/!so if $self->{cache_dir};
    $self->{root} =~ s!/*$!/!so;
    bless $self, $class;
}

# Функция задаёт имена файлов для хэндлов
# $obj->set_filenames (handle1 => 'template1.tpl', handle2 => \'{CODE} - Template code', ...)
sub set_filenames
{
    my $self = shift;
    my %fns = @_;
    while (my ($k, $v) = each %fns)
    {
        if (ref $v && ref $v ne 'SCALAR')
        {
            $v = "$v";
        }
        $self->{filenames}->{$k} = $v;
    }
    return 1;
}

# Функция загружает файлы переводов (внутри хеши)
# $obj->load_lang ($filename, $filename, ...);
sub load_lang
{
    my $self = shift;
    return $self->load_lang_hashes(map
    {
        my $load = 0;
        my $mtime;
        if (!defined($mtimes->{$_}) || $self->{reload})
        {
            $mtime = [ stat($_) ] -> [ 9 ];
            $load = 1 if !defined($mtimes->{$_}) || $mtime > $mtimes->{$_};
        }
        if ($load)
        {
            $mtimes->{$_} = $mtime;
            $langhashes->{$_} = do $_;
        }
        $langhashes->{$_};
    } @_);
}

# Функция загружает хеши переводов
# $obj->load_lang_hashes ($hash, $hash, ...);
sub load_lang_hashes
{
    my $self = shift;
    my $i = 0;
    Hash::Merge::set_behavior('RIGHT_PRECEDENT');
    $self->{lang} = Hash::Merge::merge ($self->{lang}, $_) foreach @_;
    return $i;
}

# Функция уничтожает данные шаблона
# $obj->clear()
sub clear
{
    shift->{tpldata} = {};
    return 1;
}

# Функция сохраняет текущие данные шаблона в стек и уничтожает их
# $obj->datapush ()
sub datapush
{
    my $self = shift;
    push (@{$self->{tpldata_stack}}, \$self->{tpldata});
    $self->clear;
    return 1;
}

# Функция восстанавливает данные шаблона из стека
# $obj->datapop()
sub datapop
{
    my $self = shift;
    return 0 if (@{$self->{tpldata_stack}} <= 0);
    $self->{tpldata} = pop @{$self->{tpldata_stack}};
    return 1;
}

# Функция загружает, компилирует и возвращает результат для хэндла
# $obj->parse('handle')
sub parse
{
    my $self = shift;
    my ($handle) = @_;
    my $fn = $self->{filenames}->{$handle};
    my $textref;
    unless (ref $fn)
    {
        die "[Template] unknown handle '$handle'"
            unless $fn;
        $fn = $self->{root}.$fn
            if $fn !~ m!^/!so;
        die "[Template] couldn't load template file '$fn' for handle '$handle'"
            unless $textref = $self->loadfile($fn);
    }
    else
    {
        $textref = $fn;
        $fn = undef;
    }
    my $sub = $self->compile($textref, $handle, $fn);
    my $str = eval { &$sub($self) };
    die "[Template] error running '$handle': $@" if $@;
    &{$self->{wrapper}} ($str) if $self->{wrapper};
    return $str;
}

# Функция загружает файл с кэшированием
# $textref = $obj->loadfile($file)
sub loadfile
{
    my $self = shift;
    my ($fn) = @_;
    my $load = 0;
    my $mtime;
    if (!$uncompiled_code->{$fn} || $self->{reload})
    {
        $mtime = [ stat($fn) ] -> [ 9 ];
        $load = 1 if !$uncompiled_code->{$fn} || $mtime > $mtimes->{$fn};
    }
    if ($load)
    {
        # если файл изменился - перезасасываем
        my ($fd, $text);
        if (open $fd, "<", $fn)
        {
            local $/ = undef;
            $text = <$fd>;
            close $fd;
        }
        else
        {
            return undef;
        }
        # удаляем старый скомпилированный код
        delete $compiled_code->{$uncompiled_code->{$fn}}
            if $uncompiled_code->{$fn};
        $uncompiled_code->{$fn} = \$text;
        $mtimes->{$fn} = $mtime;
    }
    return $uncompiled_code->{$fn};
}

# Функция присваивает переменные блока в новую итерацию
# $obj->assign_block_vars ($block, varname1 => value1, varname2 => value2, ...)
# Так тоже можно (при этом избежим лишнего копирования хеша!):
# $obj->assign_block_vars ($block, { varname1 => value1, varname2 => value2, ... })
sub assign_block_vars
{
    my $self = shift;
    my $block = shift;
    my $vararray;
    if (@_ > 1)
    {
        # копирование хеша, да...
        $vararray = { @_ };
    }
    else
    {
        # а так можно и не копировать
        ($vararray) = @_;
    }
    $block =~ s/^\.+//so;
    $block =~ s/\.+$//so;
    if (!$block)
    {
        # если не блок, а корневой уровень
        $self->assign_vars($vararray);
    }
    elsif ($block !~ /\.[^\.]/so)
    {
        # если блок, но не вложенный
        $block =~ s/\.*$/./so; # добавляем . в конец, если надо
        $self->{tpldata}->{$block} ||= [];
        push @{$self->{tpldata}->{$block}}, $vararray;
    }
    else
    {
        # если вложенный блок
        my $ev;
        $block =~ s/\.+$//so; # обрезаем точки в конце (хоть их 10 там)
        unless ($ev = $assigncache{"=$block"})
        {
            $ev = '$_[0]';
            my @blocks = split /\./, $block;
            my $lastblock = pop @blocks;
            foreach (@blocks)
            {
                $ev .= "{'$_.'}";
                $ev .= "[\$\#\{$ev\}]";
            }
            $ev .= "{'$lastblock.'}";
            $ev = "return sub { $ev ||= []; push \@\{$ev\}, \$_[1]; }";
            $ev = $assigncache{"=$block"} = eval $ev;
        }
        &$ev($self->{tpldata}, $vararray);
    }
    return 1;
}

# Функция добавляет переменные к текущей итерации блока
# $obj->append_block_vars ($block, varname1 => value1, varname2 => value2, ...)
sub append_block_vars
{
    my $self = shift;
    my $block = shift;
    my %vararray = @_;
    my $lastit;
    if (!$block || $block eq '.')
    {
        # если не блок, а корневой уровень
        $self->assign_vars(@_);
    }
    elsif ($block !~ /\../so)
    {
        # если блок, но не вложенный
        $block =~ s/\.*$/./so; # добавляем . в конец, если надо
        $self->{tpldata}{$block} ||= [];
        $lastit = $#{$self->{tpldata}{$block}};
        $lastit = 0 if $lastit < 0;
        $self->{tpldata}{$block}[$lastit]{$_} = $vararray{$_}
            for keys %vararray;
    }
    else
    {
        # если вложенный блок
        my $ev;
        $block =~ s/\.+$//so; # обрезаем точки в конце (хоть их 10 там)
        unless ($ev = $assigncache{"+$block"})
        {
            $ev = '$_[0]';
            my @blocks = split /\.+/, $block;
            foreach (@blocks)
            {
                $ev .= "{'$_.'}";
                $ev .= "[\$#\{$ev\}]";
            }
            $ev = 'return sub { for my $k (keys %{$_[1]}) { '.$ev.'{$k} = $_[1]->{$k}; } }';
            $ev = $assigncache{"+$block"} = eval $ev;
        }
        &$ev($self->{tpldata}, \%vararray);
    }
    return 1;
}

# Функция присваивает переменные корневого уровня
# $obj->assign_vars (varname1 => value1, varname2 => value2, ...)
sub assign_vars
{
    my $self = shift;
    my %h;
    if (@_ > 1 || !ref($_[0]))
    {
        %h = @_;
    }
    else
    {
        %h = %{$_[0]};
    }
    $self->{tpldata}{'.'}[0] ||= {};
    $self->{tpldata}{'.'}[0]{$_} = $h{$_} for keys %h;
    return 1;
}

# Аналог assign_vars, но преобразует имена переменных
sub tr_assign_vars
{
    my $self = shift;
    $self->assign_vars($self->tr_vars(@_));
}

# Аналог assign_block_vars, но преобразует имена переменных
sub tr_assign_block_vars
{
    my $self = shift;
    my $block = shift;
    $self->assign_block_vars($block, $self->tr_vars(@_));
}

# Аналог append_block_vars, но преобразует имена переменных
sub tr_append_block_vars
{
    my $self = shift;
    my $block = shift;
    $self->append_block_vars($block, $self->tr_vars(@_));
}

# Собственно функция, которая преобразует имена переменных
sub tr_vars
{
    my $self = shift;
    my $tr = shift;
    my $prefix = shift;
    my %h = ();
    my ($k, $v);
    if ($tr && !ref($tr))
    {
        unless ($self->{_tr_subroutine_cache}->{$tr})
        {
            # делаем так, чтобы всякие uc, lc и т.п работали
            $self->{_tr_subroutine_cache}->{$tr} = eval 'sub { '.$tr.'($_[0]) }';
        }
        $tr = $self->{_tr_subroutine_cache}->{$tr};
    }
    while(@_)
    {
        $k = shift;
        $v = shift;
        $k = &$tr($k) if $tr;
        $k = $prefix.$k if $prefix;
        $h{$k} = $v;
    }
    return %h;
}

# Функция компилирует код
# $sub = $self->compile(\$code, $handle, $fn);
# print &$sub($self);
sub compile
{
    my $self = shift;
    my ($coderef, $handle, $fn) = @_;
    return $compiled_code->{$coderef} if $compiled_code->{$coderef};
    my $h;
    if ($self->{cache_dir})
    {
        $h = $self->{cache_dir}.md5_hex($$coderef).'.pl';
        if (-e $h)
        {
            $compiled_code->{$coderef} = do $h;
            if ($@)
            {
                warn "[Template] error compiling '$handle': [$@] in FILE: $h";
                unlink $h;
            }
            else
            {
                return $compiled_code->{$coderef};
            }
        }
    }

    $self->{cur_template_path} = $self->{cur_template} = '';
    if ($fn)
    {
        $self->{cur_template} = $fn;
        $self->{cur_template} = substr($self->{cur_template}, length($self->{root}))
            if substr($self->{cur_template}, 0, length($self->{root})) eq $self->{root};
        $self->{cur_template} =~ s/\.[^\.]+$//iso;
        $self->{cur_template} =~ s/:+//gso;
        $self->{cur_template} =~ s!/+!:!gso;
        $self->{cur_template} =~ s/[^\w_:]+//gso;
        $self->{cur_template_path} = '->{"' . join('"}->{"',
            map { lc } split /:/, $self->{cur_template}) . '"}';
    }

    my $nesting = 0;
    my $included = {};
    my @code_lines = ();
    my @block_names = ('.');
    my ($cbstart, $cbcount, $cbplus, $mm);

    my $code = $$coderef;
    Encode::_utf8_on($code) if $self->{use_utf8};

    # комментарии <!--# ... #-->
    $code =~ s/\s*<!--#.*?#-->//gos;
    # форматирование кода для красоты
    $code =~ s/(?:^|\n)\s*(<!--\s*(?:BEGIN|END|IF\S*|ELSE\S*|INCLUDE|SET|ENDSET)\s+.*?-->)\s*(?:$|\n)/\x01$1\x01\n/gos;
    1 while $code =~ s/(?<!\x01)<!--\s*(?:BEGIN|END|IF\S*|ELSE\S*|INCLUDE|SET|ENDSET)\s+.*?-->/\x01$&/gom;
    1 while $code =~ s/<!--\s*(?:BEGIN|END|IF\S*|ELSE\S*|INCLUDE|SET|ENDSET)\s+.*?-->(?!\x01)/$&\x01/gom;

    # ' и \ -> \' и \\
    $code =~ s/\'|\\/\\$&/gos;

    # "первая замена"
    $code =~
        s%(?>\%+) *\w+[\w ]*?(?>\%+)|(?>\%+)|\{[a-z0-9\-_]+\.\#\}|\{((?:[a-z0-9\-_]+\.)*)([a-z0-9\-_]+)((?:->[a-z0-9\-_]+)*)(?:\/([a-z0-9\-_]+))?\}%
        $self->generate_xx_ref($&,$1,$2,$3,$4)
        %goise;

    # \n -> \n\x01
    $code =~ s/\n/\n\x01/gos;

    # разбиваем код на строки
    @code_lines = split /\x01/, $code;
    foreach (@code_lines)
    {
        next unless $_;
        if (/^\s*<!--\s*BEGIN\s+([a-z0-9\-_]+?)\s+([a-z \t\-_0-9]*)-->\s*$/iso)
        {
            # начало блока
            $nesting++;
            $block_names[$nesting] = $1;
            $self->{current_namespace} = join '.', @block_names;
            $cbstart = 0; $cbcount = ''; $cbplus = '++';

            {
                my $o2 = $2;
                if ($o2 =~ /^[ \t]*AT ([0-9]+)[ \t]*(?:([0-9]+)[ \t]*)?$/)
                {
                    $cbstart = $1;
                    $cbcount = $2 ? $1+$2 : 0;
                }
                elsif ($o2 =~ /^[ \t]*MOD ([1-9][0-9]*) ([0-9]+)[ \t]*$/)
                {
                    $cbstart = $2;
                    $cbplus = '+='.$1;
                }
            }

            # либо min (N, $cbcount) если $cbcount задано
            # либо просто N если нет
            if ($nesting < 2)
            {
                # блок не вложенный
                if ($cbcount) { $_ = "my \$_${1}_count = min (scalar(\@\{\$self->{tpldata}{'$1.'} || []\}), " . $cbcount . ');'; }
                else { $_ = "my \$_${1}_count = scalar(\@{\$self->{tpldata}{'$1.'} || []});"; }
                # начало цикла for
                $_ .= "\nfor (my \$_${1}_i = $cbstart; \$_${1}_i < \$_${1}_count; \$_${1}_i$cbplus)\n{";
            }
            else
            {
                # блок вложенный
                my $namespace = substr (join ('.', @block_names), 2);
                my $varref = $self->generate_block_data_ref ($namespace);
                if ($cbcount) { $_ = "my \$_${1}_count = min (scalar(\@\{$varref || []\}), $cbcount);"; }
                else { $_ = "my \$_${1}_count = ($varref && \@\{$varref\}) ? scalar(\@\{$varref || []\}) : 0;"; }
                $_ .= "\nfor (my \$_${1}_i = $cbstart; \$_${1}_i < \$_${1}_count; \$_${1}_i$cbplus)\n{";
            }
        }
        elsif (/^\s*<!--\s*END\s+(.*?)-->\s*$/so)
        {
            # чётко проверяем: блок нельзя завершать чем попало
            delete $block_names[$nesting--] if ($nesting > 0 && trim ($1) eq $block_names[$nesting]);
            $self->{current_namespace} = join '.', @block_names;
            $_ = "} # END $1";
        }
        elsif (/^\s*<!--\s*(ELS(?:E\s*)?)?IF(\S*)\s+((?:[a-z0-9\-_]+\.)*)([a-z0-9\-_]+|#)((?:->[a-z0-9\-_]+)*)(?:\/([a-z0-9\-_]+))?\s*-->\s*$/iso)
        {
            my ($elsif, $varref, $t, $ta) = (
                ($1 ? "} elsif" : "if"),
                $self->generate_block_varref($3, $4, $5, $6, 1),
                split /:/, $2, 2
            );
            if ($ta && $t && $self->{tests}->{lc $t}->[1])
            {
                $ta =~ s/\'|\\/\\$&/gso;
                $ta = ", '$ta'";
            }
            else
            {
                $ta = "";
            }
            $t = $self->{tests}->{lc $t}->[0] || '' if $t;
            $_ = "$elsif ($t($varref$ta)) {";
        }
        elsif (/^\s*<!--\s*ELSE\s*-->\s*$/so)
        {
            $_ = "} else {";
        }
        elsif (/^\s*<!--\s*INCLUDE\s*([^'\s]+)\s*-->\s*$/so)
        {
            my $n = $1;
            $_ = "\$t .= \$self->parse('_INCLUDE$n');";
            unless ($included->{$n})
            {
                $_ = "\$self->set_filenames('_INCLUDE$n' => '$n');\n    $_";
                $included->{$n} = 1;
            }
        }
        elsif (/^\s*<!--\s*SET\s+((?:[a-z0-9\-_]+\.)*)([a-z0-9\-_\/]+)\s*-->\s*$/iso)
        {
            my $varref = $self->generate_block_data_ref($1, 1)."{'$2'}";
            $_ = "$varref = eval {\nmy \$t = '';";
        }
        elsif (/^\s*<!--\s*ENDSET\s*-->\s*$/so)
        {
            $_ = "return \$t;\n};";
        }
        else
        {
            $_ = "\$t .= '$_';";
        }
    }

    # собираем код в строку
    $code = ($self->{use_utf8} ? "\nuse utf8;\n" : "").
'sub {
my $self = shift;
my $t = "";
my $_current_template = [ split /:/, \'' . $self->{cur_template} . '\' ];
' . join("\n", @code_lines) . '
return $t;
}';
    if ($h)
    {
        my $fd;
        if (open $fd, ">$h")
        {
            print $fd $code;
            close $fd;
        }
        else
        {
            warn "[Template] error caching '$handle': $! while opening $h";
        }
    }

    $compiled_code->{$coderef} = eval $code;
    die "[Template] error compiling '$handle': [$@] in CODE:\n$code" if $@;

    return $compiled_code->{$coderef};
}

# Функция для "первой замены"
sub generate_xx_ref
{
    my $self = shift;
    my @a = @_;
    my $a = shift @a;
    if ($a =~ /^\%\%|\%\%$/so)
    {
        my $r = $a;
        $r =~ s/^\%\%/\%/so;
        $r =~ s/\%\%$/\%/so;
        return $r;
    }
    elsif ($a =~ /^\%(.+)\%$/so)
    {
        return $self->language_xform($self->{current_namespace}, $1);
    }
    elsif ($a =~ /^\%\%+$/so)
    {
        return substr($a, 1);
    }
    elsif ($a =~ /^\{([a-z0-9\-_]+)\.\#\}$/iso)
    {
        return '\'.(1+$_'.$1.'_i).\'';
    }
    elsif ($a =~ /^\{.*\}$/so)
    {
        return "' . " . $self->generate_block_varref(@a) . " . '";
    }
    return $a;
}

# Функция генерирует подстановку переменной шаблона
# $varref = $obj->generate_block_varref ($namespace, $varname, $varhash)
sub generate_block_varref
{
    my $self = shift;
    my ($namespace, $varname, $varhash, $varconv) = @_;
    my $varref;

    $varconv = undef unless $self->{conv}->{$varconv};
    # обрезаем точки в конце
    $namespace =~ s/\.*$//o;

    $varref = $self->generate_block_data_ref ($namespace, 1);
    # добавляем имя переменной
    if ($varname ne '#')
    {
        $varref .= "{'$varname'}";
    }
    else
    {
        $varref = $namespace;
        $varref =~ s/^(?:.*\.)?([^\.]+)\.*$/$1/;
        $varref = '(1+$_'.$varref.'_i)';
    }

    # добавляем путь по вложенным хешам/массивам
    if ($varhash)
    {
        $varhash = [ split /->/, $varhash ];
        foreach (@$varhash)
        {
            if (/^\d+$/so)
            {
                $varref .= "[$_]";
            }
            elsif ($_)
            {
                $varref .= "{'$_'}";
            }
        }
    }

    # генерируем преобразование
    if ($varconv)
    {
        unless (ref $self->{conv}->{$varconv})
        {
            $varref = "(" . $self->{conv}->{$varconv} . "($varref))";
        }
        else
        {
            my $f = $self->{conv}->{$varconv};
            unless ($namespace)
            {
                $f = &$f($self, $varname, $varref);
            }
            else
            {
                $f = &$f($self, "$namespace.$varname", $varref);
            }
            $varref = "($f)";
        }
    }

    return $varref;
}

# Функция генерирует обращение к массиву переменных блока
# $blockref = $obj->generate_block_data_ref ($block, $include_last_iterator)
sub generate_block_data_ref
{
    my $self = shift;
    my $blockref = '$self->{tpldata}';
    my ($block, $withlastit) = @_;

    # для корневого блока
    return '$self->{tpldata}{\'.\'}' . ($withlastit ? '[0]' : '')
        if $block =~ /^\.*$/so;

    # строим цепочку блоков
    $block =~ s/\.+$//so;
    my @blocks = split (/\.+/, $block);
    my $lastblock = pop (@blocks);
    $blockref .= "{'$_.'}[\$_${_}_i]" foreach @blocks;
    $blockref .= "{'$lastblock.'}";

    # добавляем последний итератор, если надо
    $blockref .= "[\$_${lastblock}_i]" if ($withlastit);
    return $blockref;
}

# Функция компилирует ссылку на данные ленгпака
sub language_ref
{
    my $self = shift;
    my ($var, $varref, $value, $ifnull) = @_;
    my $code = '';
    $code .= '->{' . lc($_) . '}' foreach split /\.+/, $var;
    $code .= '->{' . $varref . '}';
    $code = ($self->{cur_template_path} ?
        '(($self->{lang}' . $self->{cur_template_path} . $code . ') || ' : '') .
        '($self->{lang}' . $code . ')';
    $code .= ' || (' . $varref . ')' unless $ifnull;
    $code .= ')';
    return $code;
}

# Функция компилирует ссылку на данные ленгпака
sub language_refnull { language_ref($_[0], $_[1], $_[2], $_[3], 1) }

# Compile-time вычисление language_ref
sub language_xform
{
    my $self = shift;
    my ($ns, $value) = @_;
    my ($ca, $cb) = ($self->{lang}, $self->{lang});
    foreach (split /:/, $self->{cur_template})
    {
        $cb = $cb->{lc $_} if $cb;
    }
    if ($ns)
    {
        foreach (split /\./, $ns)
        {
            $ca = $ca->{lc $_} if $ca;
            $cb = $cb->{lc $_} if $cb;
        }
    }
    $ca = $ca->{$value} if $ca;
    $cb = $cb->{$value} if $cb;
    return $ca || $cb;
}

# Тесты

sub test_even { !($_[0] & 1) }
sub test_odd  { ($_[0] & 1 ? 1 : 0) }
sub test_eq   { $_[0] eq $_[1] }

sub test_mod
{
    my ($div, $mod) = split /\s*,\s*/, $_[1], 2;
    $mod ||= 0;
    return ($_[0] % $div) == $mod;
}

1;
__END__

=head1 Шаблонизатор VMX::Template, старая версия

Sway::Template - простой и быстрый шаблонизатор, выросший из шаблонизатора phpBB2.

Legacy-версия. Новая стабильная версия входит в Solstice Homepage System (см. ветку svn branches/solstice).

=head1 Программный интерфейс

 # Конструктор
 $template = VMX::Template->new(
     root            => '.',   # каталог с шаблонами
     reload          => 1,     # если 0, шаблоны не будут перечитываться с диска, и вызовов stat() происходить не будет
     wrapper         => undef, # фильтр, вызываемый перед выдачей результата parse
     cache_dir       => undef, # необязательный кэш, ускоряющий работу только в случае частых инициализаций интерпретатора
     use_utf8        => undef, # шаблоны в UTF-8 и с флагом UTF-8
 );

 # Выбор файла шаблона:
 $template->set_filenames('alias' => 'file-name.tpl');

 # Задание кода шаблона "на месте":
 $template->set_filenames('alias' => \ 'код шаблона');

 # Загрузка файлов автоматических переводов:
 # Каждый такой файл содержит код на языке Perl, возвращающий ссылку на хеш.
 # Загрузка происходит с автоматическим пересчитыванием с диска при изменениях.
 $template->load_lang("файл1.pl", "файл2.pl");

 # Загрузка хешей в качестве языковых данных:
 $template->load_lang_hashes({ block => { var => 'перевод' } });

 # Присвоение переменных корневого уровня:
 $template->assign_vars(KEY => "значение");

 # Присвоение переменных блока-цикла в новую итерацию блока:
 $template->assign_block_vars("block", KEY => "значение");
 # Или то же, но без копирования готового хешрефа:
 $template->assign_block_vars("block", { KEY => "значение" });
 # Или то же, но в последнюю заданную итерацию блока, а не в новую:
 $template->append_block_vars("block", KEY => "значение");

 # Выполнение шаблона и получение результатов (страницы):
 # Выбранные файлы автоматически перезачитываются с диска при изменениях.
 # Код кэшируется на 2-х уровнях: на диске в виде perl-кода и в памяти в скомпилированном виде.
 $page = $template->parse('alias');

 # Очистка сохранённых данных для генерации новой страницы:
 $template->clear;

=head1 Синтаксис

Идея синтаксиса шаблонов - быть максимально простым и не поганить HTML-код.

=head2 Комментарии

<!--# Комментарий, не попадающий в результат исполнения #-->

=head2 Включение (INCLUDE)

 Включение шаблона с именем filename.tpl:
 <!-- INCLUDE filename.tpl -->

=head2 Подстановки переменных

{переменная} или {переменная->путь} или {переменная/преобразование}

Где переменная - цепочка идентификаторов, разделённая точками.
Все, кроме последнего - имена блоков, последний - имя переменной.
После имени переменной может идти путь по ней, если она представляет собой хеш или массив.
Путь - цепочка идентификаторов или чисел, разделённая стрелками ->
Например, {DOMAIN} - подстановка корневой переменной DOMAIN.
А {site.url.DOMAIN} - подстановка переменной DOMAIN блока url, вложенного в блок site.
А {site.url.CONFIG->rules->0/s} - подстановка первого элемента массива, вложенного
в переменную CONFIG блока url, вложенного в блок site, по ключу rules, в
HTML-безопасном виде (т.е. с преобразованием s, см.ниже).

А преобразование - одно из:

 T - удаление всех HTML тегов из значения
 H - удаление всех HTML тегов из значения, кроме разрешённых в VMX::Common
 i - преобразование значения к целому числу
 s - замена всех символов < > & " ' на HTML сущности &lt; &gt; &amp; &quot; &apos;
 l - перевод значения в нижний регистр
 u - перевод значения в верхний регистр
 q - замена всех символов " ' \ на \" \' \\
 L - замена значения на его контекстный перевод, если таковой имеется
 Lz - замена значения на его контекстный перевод, если таковой имеется, и на пустое значение, если нет

=head2 Условный вывод (IF)

 <!-- IF[тест] подстановка -->
 <!-- END -->

Где подстановка - любая допустимая в {фигурных.скобках} подстановка.

Тесты:

 !    - логическое отрицание
 EVEN - истина в случае, если значение - чётное число
 ODD  - истина в случае, если значение - нечётное число
 EQ:строка            - истина в случае, если значение переменной совпадает с "строка"
 MOD:делитель,остаток - истина в случае, если остаток от деления значения переменной на "делитель" равен "остатку"

Например:

 <!-- IF! site.url.CONFIG->rules->0/Lz -->
 <!-- END -->

=head2 Циклический вывод (BEGIN block)

Циклический вывод, начать с итерации start (считаются с нуля), и вывести максимум по итерацию count.
Либо обработать все итерации с номерами, дающими остаток от деления на "div" равный "mod".
Имя блока состоит из латинских символов, цифр и символа '_' (подчёркивания).

Итак, варианты начала:

 <!-- BEGIN block -->
 <!-- BEGIN block AT start -->
 <!-- BEGIN block AT start count -->
 <!-- BEGIN block MOD div mod -->

Конец блока - всегда <!-- END block -->.

Пример:

 <!-- BEGIN block -->
 <!-- BEGIN inner_block -->
 {block.inner_block.VARIABLE}
 {inner_block.#}
 <!-- END inner_block -->
 <!-- END block -->

И специальный случай: внутри внутреннего блока {inner_block.#} имеет значением
номер текущей итерации внутреннего блока, считающийся с 1. Именно {inner_block.#},
а не {block.inner_block.#}.

=head2 Автоматические контекстные переводы

Они доступны в двух вариантах: %Переводимая строка% и {переменная/L}.

Идея в том, чтобы автоматически заменять строки на другие строки в зависимости
от их расположения в файле шаблона (контекста).

Контекст включает в себя:

  - путь к файлу шаблона.
  - путь к текущему блоку-циклу.
  - в случае перевода переменной - имя переменной.

Данные перевода представляют собой вложенный хеш. Подставляемые строки
берутся по наиболее детализированному доступному пути в нём. Т.е. если есть
->1->2->3, берётся ->1->2->3, если нет ->1->2->3, но есть ->2->3, берётся ->2->3,
иначе берётся просто ->3.

Соответственно и загружаемые файлы переводов должны содержать просто код,
возвращающий хешреф. Т.е. в простейшем случае - просто хешреф.

=cut
