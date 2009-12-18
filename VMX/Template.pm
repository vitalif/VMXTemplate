#!/usr/bin/perl
# Новая версия шаблонного движка VMX::Template!
# "Ох уж эти перлисты... что ни пишут - всё Template Toolkit получается!"

package VMX::Template;

use strict;
use VMX::Common qw(:all);
use Digest::MD5 qw(md5_hex);
use Hash::Merge;
use POSIX;

my $mtimes = {};            # время изменения файлов
my $uncompiled_code = {};   # нескомпилированный код
my $compiled_code = {};     # скомпилированный код (sub'ы)
my $assigncache = {};       # кэш eval'ов присвоений

# Конструктор
# $obj = new VMX::Template, %params
sub new
{
    my $class = shift;
    $class = ref ($class) || $class;
    my $self =
    {
        root            => '.',    # каталог с шаблонами
        reload          => 1,      # если 0, шаблоны не будут перечитываться с диска, и вызовов stat() происходить не будет
        wrapper         => undef,  # фильтр, вызываемый перед выдачей результата parse
        tpldata         => {},     # сюда будут сохранены: данные
        cache_dir       => undef,  # необязательный кэш, ускоряющий работу только в случае частых инициализаций интерпретатора
        use_utf8        => undef,  # шаблоны в UTF-8 и с флагом UTF-8
        begin_code      => '<!--', # начало кода
        end_code        => '-->',  # конец кода
        begin_subst     => '{',    # начало подстановки (необязательно)
        end_subst       => '}',    # конец подстановки (необязательно)
        @_,
    };
    $self->{cache_dir} =~ s!/*$!/!so if $self->{cache_dir};
    $self->{root} =~ s!/*$!/!so;
    bless $self, $class;
}

# Функция задаёт имена файлов для хэндлов
# $obj->set_filenames (handle1 => 'template1.tpl', ...)
sub set_filenames
{
    my $self = shift;
    my %fns = @_;
    while (my ($k, $v) = each %fns)
    {
        $self->{filenames}->{$k} = "$v";
    }
    return 1;
}

# Задать код для хэндлов
# $obj->set_code (handle1 => "{CODE} - Template code", ...);
sub set_code
{
    my $self = shift;
    my %codes = @_;
    while (my ($k, $v) = each %codes)
    {
        $self->{filenames}->{$k} = \ $v;
    }
    return 1;
}

# Функция уничтожает данные шаблона
# $obj->clear()
sub clear
{
    %{ shift->{tpldata} } = ();
    return 1;
}

# Получить хеш для записи данных
sub vars
{
    my $self = shift;
    my ($vars) = @_;
    $self->{tpldata} = $vars if $vars;
    return $self->{tpldata};
}

# Функция выполняет код шаблона, не выводя страницу
# Нужно, чтобы выполнить все присваивания переменных.
# $obj->preparse('handle')
sub preparse
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
    # FIXME возможно, не стоит на это заморачиваться, а просто запускать шаблон дважды
    my $sub = $self->compile($textref, $handle, $fn, 1);
    eval { &$sub($self) };
    die "[Template] error pre-running '$handle': $@" if $@;
    return $self;
}

# Функция загружает, компилирует и возвращает результат для хэндла
# $page = $obj->parse('handle')
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
        unless ($ev = $assigncache->{"=$block"})
        {
            $ev = '$_[0]';
            my @blocks = split /\./, $block;
            my $lastblock = pop @blocks;
            foreach (@blocks)
            {
                $ev .= "{'$_'}";
                $ev .= "[\$\#\{$ev\}]";
            }
            $ev .= "{'$lastblock'}";
            $ev = "return sub { $ev ||= []; push \@\{$ev\}, \$_[1]; }";
            $ev = $assigncache->{"=$block"} = eval $ev;
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
        unless ($ev = $assigncache->{"+$block"})
        {
            $ev = '$_[0]';
            my @blocks = split /\.+/, $block;
            foreach (@blocks)
            {
                $ev .= "{'$_'}";
                $ev .= "[\$#\{$ev\}]";
            }
            $ev = 'return sub { for my $k (keys %{$_[1]}) { '.$ev.'{$k} = $_[1]->{$k}; } }';
            $ev = $assigncache->{"+$block"} = eval $ev;
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
    my $h;
    if (@_ > 1 || !ref $_[0])
    {
        $h = { @_ };
    }
    else
    {
        $h = $_[0];
    }
    $self->{tpldata} ||= {};
    $self->{tpldata}->{$_} = $h->{$_} for keys %$h;
    return 1;
}

# Функция компилирует код.
# Если $nout - истина, то не выводить страницу, а обрабатывать только <!-- SET --> и т.п.
# FIXME Если бы ещё убрать необходимость двойной компиляции для $nout=0 и $nout=1.
# $sub = $self->compile(\$code, $handle, $fn, $nout);
# print &$sub($self);
sub compile
{
    my $self = shift;
    my ($coderef, $handle, $fn, $nout) = @_;
    $nout = $nout ? 1 : 0;
    return $compiled_code->{$nout.$coderef} if $compiled_code->{$nout.$coderef};

    # кэширование на диске
    my $h;
    if ($self->{cache_dir})
    {
        $h = $self->{cache_dir}.$nout.md5_hex($$coderef).'.pl';
        if (-e $h)
        {
            $compiled_code->{$nout.$coderef} = do $h;
            if ($@)
            {
                warn "[Template] error compiling '$handle': [$@] in FILE: $h";
                unlink $h;
            }
            else
            {
                return $compiled_code->{$nout.$coderef};
            }
        }
    }

    # прописываем путь к текущему шаблону в переменную
    $self->{cur_template_path} = $self->{cur_template} = '';
    if ($fn)
    {
        $self->{cur_template} = $fn;
        $self->{cur_template} = substr $self->{cur_template}, length $self->{root}
            if substr($self->{cur_template}, 0, length $self->{root}) eq $self->{root};
        $self->{cur_template} =~ s/\.[^\.]+$//iso;
        $self->{cur_template} =~ s/:+//gso;
        $self->{cur_template} =~ s!/+!:!gso;
        $self->{cur_template} =~ s/[^\w_:]+//gso;
        $self->{cur_template_path} = '->{"' . join('"}->{"',
            map { lc } split /:/, $self->{cur_template}) . '"}';
    }

    my $code = $$coderef;
    Encode::_utf8_on($code) if $self->{use_utf8};

    # начала/концы спецстрок
    my $bc = $self->{begin_code} || '<!--';
    my $ec = $self->{end_code} || '-->';
    my $bs = $self->{end_subst} && $self->{begin_subst} || undef;
    my $es = $self->{begin_subst} && $self->{end_subst} || undef;

    # удаляем комментарии <!--# ... -->
    $code =~ s/\s*\Q$bc\E#.*?\Q$ec\E//gos;
    $code =~ s/(?:^|\n)[ \t\r]*(\Q$bc\E\s*[a-z]+(\s+.*)?\Q$ec\E)/$1/giso;

    $self->{blocks} = [];
    $self->{in} = [];
    $self->{included} = {};
    # вне <!-- SET --> при $nout=1 $t.= не делается
    # за это отвечают также соотв. if'ы в compile_code_fragment
    $self->{nout} = $nout;
    $self->{in_set} = 0;

    my $r = '';
    my ($p, $c, $t);
    my $pp = 0;
    my $in;

    # регулярное выражения для поиска фрагментов кода
    my $re = '\Q' . $bc . '\E(.*?)\Q' . $ec . '\E';
    $re .= '|\Q' . $bs . '\E(.*?)\Q' . $es . '\E' if $bs;
    $re = qr/$re/s;

    # ищем фрагменты кода
    $code =~ /^/gcso;
    while ($code =~ /$re/gcso)
    {
        $in = $self->{in_set};
        $c = $2 ? $self->compile_substitution($2) : $self->compile_code_fragment($1);
        next unless $c;
        if (($t = pos($code) - $pp - length $&) > 0)
        {
            $p = substr $code, $pp, $t;
            $p =~ s/\\|\'/\\$&/gso;
            $r .= "\$t.='$p';\n" if !$nout || $in;
        }
        $r .= $c if $c;
        $pp = pos $code;
    }
    if ($pp < length($code))
    {
        $p = substr $code, $pp;
        $p =~ s/\\|\'/\\$&/gso;
        $r .= "\$t.='$p';\n" if !$nout || $self->{in_set};
    }

    # дописываем начало и конец кода
    $code = ($self->{use_utf8} ? "\nuse utf8;\n" : "").
'sub {
my $self = shift;
my $t = "";
my $_current_template = [ split /:/, \'' . $self->{cur_template} . '\' ];
' . $r . '
return $t;
}';
    undef $r;

    # кэшируем код на диск
    if ($h)
    {
        my $fd;
        if (open $fd, ">$h")
        {
            no warnings 'utf8';
            print $fd $code;
            close $fd;
        }
        else
        {
            warn "[Template] error caching '$handle': $! while opening $h";
        }
    }

    # компилируем код
    $compiled_code->{$nout.$coderef} = eval $code;
    die "[Template] error compiling '$handle': [$@] in CODE:\n$code" if $@;

    # возвращаем ссылку на процедуру
    return $compiled_code->{$nout.$coderef};
}

# компиляция фрагмента кода <!-- ... -->. это может быть:
# 1) [ELSE] IF выражение
# 2) BEGIN имя блока
# 3) END [имя блока]
# 4) SET переменная
# 5) SET переменная = выражение
# 6) INCLUDE имя_файла_шаблона
# 7) выражение
sub compile_code_fragment
{
    my $self = shift;
    my ($e) = @_;
    my $t;
    $e =~ s/^\s+//so;
    $e =~ s/\s+$//so;
    if ($e =~ /^(ELS(?:E\s*)?)?IF(!?)\s*/iso)
    {
        $t = $';
        if ($2)
        {
            warn "Legacy IF! used, consider changing it to IF NOT";
            $t = "NOT $t";
        }
        $t = $self->compile_expression($t);
        unless ($t)
        {
            warn "Invalid expression: ($t)";
            return undef;
        }
        push @{$self->{in}}, [ 'if' ] unless $1;
        return $1 ? "} elsif ($t) {\n" : "if ($t) {\n";
    }
    elsif ($e =~ /^ELSE\s*$/iso)
    {
        return "} else {";
    }
    elsif ($e =~ /^BEGIN\s+([a-z_][a-z0-9_]*)(?:\s+AT\s+(.+))?(?:\s+BY\s+(.+))?(?:\s+TO\s+(.+))?$/iso)
    {
        my $ref = $self->varref([@{$self->{blocks}}, $1]);
        my $at = 0;
        if ($2)
        {
            $at = $self->compile_expression($2);
            unless ($at)
            {
                warn "Invalid expression: ($2) in AT";
                return undef;
            }
        }
        my $by = '++';
        if ($3)
        {
            $by = $self->compile_expression($3);
            unless ($by)
            {
                warn "Invalid expression: ($3) in BY";
                return undef;
            }
            $by = '+=' . $by;
        }
        my $to = '';
        if ($4)
        {
            $to = $self->compile_expression($4);
            unless ($to)
            {
                warn "Invalid expression: ($4) in TO";
                return undef;
            }
            $to = "\$blk_${1}_count = $to if $to < \$blk_${1}_count;";
        }
        push @{$self->{blocks}}, $1;
        push @{$self->{in}}, [ 'begin', $1 ];
        return <<EOF;
my \$blk_${1}_count = ref($ref) && $ref =~ /ARRAY/so ? scalar \@{$ref} : $ref ? 1 : 0;
${to}
for (my \$blk_${1}_i = $at; \$blk_${1}_i < \$blk_${1}_count; \$blk_${1}_i $by) {
my \$blk_${1}_vars = ref($ref) && $ref =~ /ARRAY/so ? $ref ->[\$blk_${1}_i] : $ref;
EOF
    }
    elsif ($e =~ /^END(?:\s+([a-z_][a-z0-9_]*))?$/iso)
    {
        unless (@{$self->{in}})
        {
            warn "$& without BEGIN, IF or SET";
            return undef;
        }
        my $l = $self->{in}->[$#{$self->{in}}];
        if ($1 && ($l->[0] ne 'begin' || !$l->[1] || $l->[1] ne $1) ||
            !$1 && $l->[0] eq 'begin' && $l->[1])
        {
            warn "$& after ".uc($l->[0])." $l->[1]";
            return undef;
        }
        $self->{in_set}-- if $l->[0] eq 'set';
        pop @{$self->{in}};
        pop @{$self->{blocks}} if $1;
        return $l->[0] eq 'set' ? "return \$t;\n};\n" : "} # $&\n";
    }
    elsif ($e =~ /^SET\s+((?:[a-z0-9_]+\.)*[a-z0-9_]+)(\s*=\s*)?/iso)
    {
        if ($2)
        {
            $t = $self->compile_expression($');
            unless ($t)
            {
                warn "Invalid expression: ($')";
                return undef;
            }
        }
        push @{$self->{in}}, [ 'set', $1 ];
        $self->{in_set}++;
        return $self->varref($1) . ' = ' . ($t || 'eval { my $t = ""') . ";\n";
    }
    elsif ($e =~ /^INCLUDE\s+(\S+)$/iso)
    {
        my $n = $1;
        my $p = $self->{nout} && !$self->{in_set} ? "preparse" : "parse";
        $n =~ s/\'|\\/\\$&/gso;
        $t = "\$t .= \$self->$p('_INCLUDE$n');\n";
        unless ($self->{included}->{$n})
        {
            $t = "\$self->set_filenames('_INCLUDE$n' => '$n');\n$t";
            $self->{included}->{$n} = 1;
        }
        return $t;
    }
    else
    {
        $t = $self->compile_expression($e);
        return "\$t .= $t;\n" if $t && (!$self->{nout} || $self->{in_set});
    }
    return undef;
}

# компиляция подстановки переменной {...} это просто выражение
sub compile_substitution
{
    my $self = shift;
    my ($e) = @_;
    $e = $self->compile_expression($e);
    return undef unless $e;
    return "\$t .= $e;\n" if !$self->{nout} || $self->{in_set};
}

# компиляция выражения. это может быть:
# 1) "строковой литерал"
# 2) 123.123 или 0123 или 0x123
# 3) переменная
# 4) функция(выражение,выражение,...,выражение)
# 5) функция выражение
# 6) для legacy mode: переменная/имя_функции
sub compile_expression
{
    my $self = shift;
    my ($e, $after) = @_;
    $after = undef if $after && ref $after ne 'SCALAR';
    $$after = '' if $after;
    $e =~ s/^\s+//so;
    $e =~ s/\s+$//so unless $after;
    # строковой или числовой литерал
    if ($e =~ /^((\")(?:[^\"\\]+|\\.)*\"|\'(?:[^\'\\]+|\\.)*\'|-?[1-9]\d*(\.\d+)?|-?0\d*|-?0x\d+)\s*/iso)
    {
        if ($')
        {
            return undef unless $after;
            $$after = $';
        }
        $e = $1;
        $e =~ s/[\$\@\%]/\\$&/gso if $2;
        return $e;
    }
    # функция нескольких аргументов
    elsif ($e =~ /^([a-z_][a-z0-9_]*)\s*\(/iso)
    {
        my $f = lc $1;
        unless ($self->can("function_$f"))
        {
            warn "Unknown function: '$f'";
            return undef;
        }
        my $a = $';
        my @a;
        while ($e = $self->compile_expression($a, \$a))
        {
            push @a, $e;
            if ($a =~ /^\s*\)/so)
            {
                last;
            }
            elsif ($a !~ s/^\s*,//so)
            {
                warn "Unexpected token: '$a' in $f() parameter list";
                return undef;
            }
        }
        if ($a !~ s/^\s*\)\s*//so)
        {
            warn "Unexpected token: '$a' in the end of $f() parameter list";
            return undef;
        }
        if ($a)
        {
            return undef unless $after;
            $$after = $a;
        }
        $f = "function_$f";
        return $self->$f(@a);
    }
    # функция одного аргумента
    elsif ($e =~ /^([a-z_][a-z0-9_]*)\s+(?=\S)/iso)
    {
        my $f = lc $1;
        unless ($self->can("function_$f"))
        {
            warn "Unknown function: '$f'";
            return undef;
        }
        my $a = $';
        my $arg = $self->compile_expression($a, \$a);
        unless ($arg)
        {
            warn "Invalid expression: ($e)";
            return undef;
        }
        $a =~ s/^\s*//so;
        if ($a)
        {
            return undef unless $after;
            $$after = $a;
        }
        $f = "function_$f";
        return $self->$f($arg);
    }
    # переменная плюс legacy-mode переменная/функция
    elsif ($e =~ /^((?:[a-z0-9_]+\.)*(?:[a-z0-9_]+|\#))(?:\/([a-z]+))?\s*/iso)
    {
        if ($')
        {
            return undef unless $after;
            $$after = $';
        }
        $e = $self->varref($1);
        if ($2)
        {
            my $f = lc $2;
            unless ($self->can("function_$f"))
            {
                warn "Unknown function: '$f' called in legacy mode ($&)";
                return undef;
            }
            $f = "function_$f";
            $e = $self->$f($e);
        }
        return $e;
    }
    return undef;
}

# генерация ссылки на переменную
sub varref
{
    my $self = shift;
    return "" unless $_[0];
    my @e = ref $_[0] ? @{$_[0]} : split /\.+/, $_[0];
    $self->{last_varref_path} = join '.', @e;
    my $t = '$self->{tpldata}';
    EQBLOCK: {
    if (@{$self->{blocks}})
    {
        for (0..$#{$self->{blocks}})
        {
            last EQBLOCK unless $self->{blocks}->[$_] eq $e[$_];
        }
        splice @e, 0, @{$self->{blocks}};
        if (@e == 1 && $e[0] eq '#')
        {
            # номер итерации блока
            @e = ();
            $t = '$blk_'.$self->{blocks}->[$#{$self->{blocks}}].'_i';
        }
        else
        {
            # локальная переменная
            $t = '$blk_'.$self->{blocks}->[$#{$self->{blocks}}].'_vars';
        }
    }
    }
    for (@e)
    {
        if (/^\d+$/so)
        {
            $t .= "->[$_]";
        }
        else
        {
            s/\'|\\/\\$&/gso;
            $t .= "->{'$_'}";
        }
    }
    return $t;
}

# операция над аргументами
sub fmop
{
    my $op = shift;
    shift; # my $self = shift;
    return "((" . join(") $op (", @_) . "))";
}

# вызов функции с аргументами и раскрытием массивов
sub fearr
{
    my $f = shift;
    my $self = shift;
    my $e = shift;
    $e = "$f($e";
    $e .= ", ref($_) eq 'ARRAY' ? \@{$_} : ($_)" for @_;
    $e .= ")";
    return $e;
}

# функции
sub function_or      { fmop('||', @_) }
sub function_and     { fmop('&&', @_) }
sub function_add     { fmop('+', @_) }
sub function_sub     { fmop('-', @_) }
sub function_mul     { fmop('*', @_) }
sub function_div     { fmop('/', @_) }
sub function_concat  { fmop('.', @_) }
sub function_count   { "ref($_[1]) && $_[1] =~ /ARRAY/so ? scalar(\@{ $_[1] }) : 0" }
sub function_not     { "!($_[1])" }
sub function_even    { "!(($_[1]) & 1)" }
sub function_odd     { "(($_[1]) & 1)" }
sub function_int     { "int($_[1])" }
sub function_eq      { "(($_[1]) == ($_[2]))" }
sub function_gt      { "(($_[1]) > ($_[2]))" }
sub function_lt      { "(($_[1]) < ($_[2]))" }
sub function_ge      { "(($_[1]) >= ($_[2]))" }
sub function_le      { "(($_[1]) <= ($_[2]))" }
sub function_seq     { "(($_[1]) eq ($_[2]))" }
sub function_sgt     { "(($_[1]) gt ($_[2]))" }
sub function_slt     { "(($_[1]) lt ($_[2]))" }
sub function_sge     { "(($_[1]) ge ($_[2]))" }
sub function_sle     { "(($_[1]) le ($_[2]))" }
sub function_lc      { "lc($_[1])" }                    *function_lower = *function_lowercase = \&function_lc;
sub function_uc      { "uc($_[1])" }                    *function_upper = *function_uppercase = \&function_uc;
sub function_requote { "requote($_[1])" }               *function_re_quote = *function_preg_quote = \&function_requote;
sub function_split   { "split($_[1], $_[2], $_[3])" }
sub function_quote   { "quotequote($_[1])" }            *function_q = \&function_quote;
sub function_html    { "htmlspecialchars($_[1])" }      *function_s = \&function_html;
sub function_strip   { "strip_tags($_[1])" }            *function_t = \&function_strip;
sub function_h       { "strip_unsafe_tags($_[1])" }     *function_strip_unsafe = \&function_h;
# объединяет не просто скаляры, а также все элементы массивов
sub function_join    { fearr('join', @_) }              *function_implode = \&function_join;
# подставляет на места $1, $2 и т.п. в строке аргументы
sub function_subst   { fearr('exec_subst', @_) }
# sprintf
sub function_sprintf { fearr('sprintf', @_) }
# strftime
sub function_strftime { "POSIX::strftime($_[1], localtime(($_[2]) || undef))" }

# выполняет подстановку function_subst
sub exec_subst
{
    my $str = shift;
    $str =~ s/(?<!\\)((?:\\\\)*)\$(?:([1-9]\d*)|\{([1-9\d*)\})/$_[($2||$3)-1]/gisoe;
    return $str;
}

1;
__END__

=head1 Шаблонизатор VMX::Template

Данный модуль представляет собой новую версию VMX::Template, построенную на
некоторых новых идеях, ликвидировавшую безобразие и legacy-код, накопленный
в старой версии, однако сохранившую высокую производительность и простоту.

=head1 Идеи

Уйти от assign_vars(), assign_block_vars(). Передавать, как и в обычных движках,
просто хеш с данными $vars. Как, например, в Template::Toolkit. При этом
сохранить данные методы для совместимости.

Почистить синтаксис: ликвидировать "преобразования", "вложенный путь по
переменной" (->key->index->key->и т.п.), специальный синтаксис для окончания SET,
неочевидное обращение к счётчику block.#, tr_assign_* и т.п.

Переписать с нуля компилятор.

Добавить в употребление функции, но только самые необходимые.

Добавить обработку ошибок и диагностические сообщения.

=head1 Реализация

Путь к переменной теперь может включать в себя числа.

Вне BEGIN - {block} будет иметь значение ARRAY(0x...) т.е. массив всех
итераций блока block, а {block.0} будет иметь значение HASH(0x...), т.е.
первую итерацию блока block.

 <!-- BEGIN block -->

Внутри BEGIN - {block} будет иметь значение HASH(0x...), т.е. уже значение
текущей итерации блока block, а {block.#} будет иметь значением номер текущей
итерации {block.var}, считаемый с 0, а не с 1, как в старой версии.

 <!-- END block -->

На <!-- END другоеимя --> после <!-- BEGIN block --> ругнётся, ибо нефиг.
Если block в хеше данных - не массив, а хеш - значит, итерация у блока только
одна, и <!-- BEGIN block --> работает как for($long_expression) {} в Perl.

Операторов НЕТ, но есть функции.
Пример:

 <!-- IF OR(function(block.key1),AND(block.key2,block.key3)) -->

Синтаксис вызова функции нескольких аргументов:

 <!-- function(block.key, 0, "abc") -->

Подстановка:

 {function(block.key, 0, "abc")}

Синтаксис вызова функции одного аргумента:

 <!-- function(block.key) -->
 <!-- function block.key -->
 {block.key/L}
 {L block.key}

Условный вывод:

 <!-- IF function(block.key) --><!-- ELSEIF ... --><!-- END -->
 <!-- IF NOT block.key -->...<!-- END -->

Запись значения переменной:

 <!-- SET block.key -->...<!-- END -->

или

 <!-- SET block.key = выражение -->

=head1 Функции

=head2 OR, AND, NOT

Логические ИЛИ, И, НЕ, действующие аналогично Perl операторам || && !.

=head2 EVEN, ODD

Истина в случае, если аргумент чётный или нечётный соответственно.

=head2 INT, ADD, MUL, DIV, MOD

Преобразование к целому числу и арифметические операции.

=head2 EQ, SEQ, GT, LT, GE, LE, SGT, SLT, SGE, SLE

Действуют аналогично Perl операторам == eq > < >= <= gt lt ge le.

=head2 CONCAT, JOIN, SPLIT, COUNT

Конкатенация всех своих аргументов - concat(аргументы).

Конкатенация элементов массива через разделитель - join(строка,аргументы).
Причём если какие-то аргументы - массивы, конкатенирует все их элементы,
а не их самих.

Разделение строки по регулярному выражению и лимиту - split(РЭ,аргумент,лимит).
Лимит необязателен. (см. perldoc -f split)

Количество элементов в массиве или 0 если не массив - count(аргумент).

=head2 LC=LOWER=LOWERCASE, UC=UPPER=UPPERCASE

Нижний и верхний регистр.

=head2 L=TRANSLATE, LZ=TRANSLATE_NULL

Контекстный перевод и он же либо пустое значение.

=head2 S=HTML, T=STRIP, H=STRIP_UNSAFE

Преобразование символов < > & " ' в HTML-сущности,

Удаление всех тегов,

Удаление запрещённых тегов.

=head2 Q=QUOTE, REQUOTE=RE_QUOTE=PREG_QUOTE

Экранирование символов " ' \

А также экранирование символов, являющихся специальными в регулярных выражениях (см. perldoc perlre).

=cut
