#!/usr/bin/perl
# Новая версия шаблонного движка VMX::Template!

# Уйти от assign_vars(), assign_block_vars()
# Передавать, как и в обычных движках, просто
# $hash =
# {
#   key   => "value",
#   block =>
#   [
#     {
#       key => "value",
#     },
#     {
#       key => "value",
#     },
#   ],
# }

# Вне BEGIN - {block} будет иметь значение ARRAY(0x...) т.е. массив всех итераций
# А {block.0} будет иметь значение HASH(0x...) т.е. первую итерацию

# <!-- BEGIN block -->
# Внутри BEGIN - {block} будет иметь значение HASH(0x...) т.е. уже значение конкретной итерации
# А {block.#} будет иметь значение - номер текущей итерации
# {block.var}
# <!-- END block -->
# На <!-- END другоеимя --> ругнётся, ибо нефиг.
# Если block в хеше данных - не массив, а хешреф - значит, итерация только одна.

# Функции нескольких аргументов
# <!-- function(block.key, 0, "abc") -->

# Функции одного аргумента
# <!-- function(block.key) -->
# <!-- function block.key -->
# {block.key/L}
# {L block.key}

# IF -
# <!-- IF function(block.key) --><!-- ELSEIF ... --><!-- END -->
# <!-- IF NOT block.key -->...<!-- END -->

# Операторов НЕТ, только функции
# <!-- IF OR(function(block.key1),AND(block.key2,block.key3)) -->

# Есть SET
# <!-- SET block.key -->...<!-- END -->
# или
# <!-- SET block.key = ... -->

# Функции
# OR, AND, NOT
# EVEN, ODD
# INT, ADD, MUL, DIV, MOD
# EQ, SEQ, GT, LT, GE, LE, SGT, SLT, SGE, SLE (== eq > < >= <= gt lt ge le)
# CONCAT, JOIN, SPLIT, LC=LOWER=LOWERCASE, UC=UPPER=UPPERCASE
# L=TRANSLATE, LZ=TRANSLATE_NULL
# S=HTML, T=STRIP, H=STRIP_UNSAFE
# Q=QUOTE, REQUOTE=RE_QUOTE=PREG_QUOTE

package VMX::Template;

use strict;
use VMX::Common qw(:all);
use Digest::MD5 qw(md5_hex);
use Hash::Merge;

my $mtimes = {};            # время изменения файлов
my $uncompiled_code = {};   # нескомпилированный код
my $compiled_code = {};     # скомпилированный код (sub'ы)
my $langhashes = {};        # хеши ленгпаков
my $assigncache = {};       # кэш eval'ов присвоений

# Конструктор
# $obj = new VMX::Template, %params
sub new
{
    my $class = shift;
    $class = ref ($class) || $class;
    my $self =
    {
        root            => '.',   # каталог с шаблонами
        reload          => 1,     # если 0, шаблоны не будут перечитываться с диска, и вызовов stat() происходить не будет
        wrapper         => undef, # фильтр, вызываемый перед выдачей результата parse
        tpldata         => {},    # сюда будут сохранены: данные
        lang            => {},    # ~ : языковые данные
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

# Функция компилирует код
# $sub = $self->compile(\$code, $handle, $fn);
# print &$sub($self);
sub compile
{
    my $self = shift;
    my ($coderef, $handle, $fn) = @_;
    return $compiled_code->{$coderef} if $compiled_code->{$coderef};

    # кэширование на диске
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

    # удаляем комментарии <!--# ... #-->
    $code =~ s/\s*<!--#.*?#-->//gos;

    $self->{blocks} = [];
    $self->{in} = [];
    $self->{included} = {};

    my $r = '';
    my ($p, $c, $t);
    my $pp = 0;

    # ищем фрагменты кода
    $code =~ /^/gcso;
    while ($code =~ /<!--(.*?)-->|\{(.*?)\}/gcso)
    {
        $c = $1 ? $self->compile_code_fragment($1) : $self->compile_substitution($2);
        next unless $c;
        if (($t = pos($code) - $pp - length $&) > 0)
        {
            $p = substr $code, $pp, $t;
            $p =~ s/\\|\'/\\$&/gso;
            $r .= "\$t.='$p';\n";
        }
        $r .= $c if $c;
        $pp = pos $code;
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
            print $fd $code;
            close $fd;
        }
        else
        {
            warn "[Template] error caching '$handle': $! while opening $h";
        }
    }

    # компилируем код
    $compiled_code->{$coderef} = eval $code;
    die "[Template] error compiling '$handle': [$@] in CODE:\n$code" if $@;

    # возвращаем ссылку на процедуру
    return $compiled_code->{$coderef};
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
    if ($e =~ /^(ELS(?:E\s+)?)?IF\s+/iso)
    {
        $t = $self->compile_expression($');
        unless ($t)
        {
            warn "Invalid expression: ($')";
            return undef;
        }
        return $1 ? "} elsif ($t) {\n" : "if ($t) {\n";
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
my \$blk_${1}_vars = ref($ref) && $ref =~ /ARRAY/so ? $ref ->{\$blk_${1}_i} : $ref;
EOF
    }
    elsif ($e =~ /^END(?:\s+([a-z_][a-z0-9_]*))?$/iso)
    {
        unless (@{$self->{in}})
        {
            warn "$& without BEGIN, IF or SET";
            return undef;
        }
        my $l = $self->{in}->{$#{$self->{in}}};
        if ($1 && ($l->[0] ne 'begin' || !$l->[1] || $l->[1] ne $1) ||
            !$1 && $l->[1])
        {
            warn "$& after ".uc($l->[0])." $l->[1]";
            return undef;
        }
        pop @{$self->{in}};
        pop @{$self->{blocks}} if $1;
        return $l->[0] eq 'set' ? "return \$t;\n};\n" : "} # $&\n";
    }
    elsif ($e =~ /^SET\s+((?:[a-z0-9_]+\.)*[a-z0-9_]+)(\s*=\s*)?$/iso)
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
        return $self->varref($1) . ' = ' . ($t || 'eval { my $t = ""') . ";\n";
    }
    elsif ($e =~ /^INCLUDE\s+(\S+)$/iso)
    {
        my $n = $1;
        $n =~ s/\'|\\/\\$&/gso;
        $t = "\$t .= \$self->parse('_INCLUDE$n');\n";
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
        return "\$t .= $t;\n" if $t;
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
    return "\$t .= $e;\n";
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
    $e =~ s/^\s+//so;
    $e =~ s/\s+$//so unless $after;
    # переменная плюс legacy-mode переменная/функция
    if ($e =~ /^((?:[a-z0-9_]+\.)*(?:[a-z0-9_]+|\#))(?:\/([a-z]+))?\s*/iso)
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
    elsif ($e =~ /^([a-z_][a-z0-9_]*)\s+/iso)
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
    # строковой или числовой литерал
    elsif ($e =~ /^((\")(?:[^\"\\]+|\\.)+\"|\'(?:[^\'\\]+|\\.)+\'|[1-9]\d*(\.\d+)?|0\d*|0x\d+)\s*/iso)
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
    EQBLOCK: if (@{$self->{blocks}})
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

# функции
sub function_or      { fmop('||', @_) }
sub function_and     { fmop('&&', @_) }
sub function_add     { fmop('+', @_) }
sub function_sub     { fmop('-', @_) }
sub function_mul     { fmop('*', @_) }
sub function_div     { fmop('/', @_) }
sub function_concat  { fmop('.', @_) }
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
sub function_l       { f_translate(undef, @_) }         *function_translate = \&function_l;
sub function_lz      { f_translate(1, @_) }             *function_translate_null = \&function_lz;

# объединяет не просто скаляры, а также все элементы массивов
sub function_join
{
    my $self = shift;
    my $e = shift;
    $e = "join($e";
    $e .= ", ref($_) eq 'ARRAY' ? \@{$_} : ($_)" for @_;
    $e .= ")";
    return $e;
}

# автоматически выбирает, в compile-time или в run-time делать перевод
sub f_translate
{
    my $ifnull = shift;
    my $e = eval $_[1];
    if ($@)
    {
        # выражение - не константа, т.к. не вычисляется без $self
        return $_[0]->language_ref($_[0]->{last_varref_path}, $_[1], $ifnull);
    }
    # выражение - константа
    return $_[0]->language_xform($e);
}

# Функция компилирует ссылку на данные ленгпака
sub language_ref
{
    my $self = shift;
    my ($var, $varref, $emptyifnull) = @_;
    my $code = '';
    $code .= '->{' . lc($_) . '}' foreach split /\.+/, $var;
    $code .= '->{' . $varref . '}';
    $code = ($self->{cur_template_path} ?
        '(($self->{lang}' . $self->{cur_template_path} . $code . ') || ' : '') .
        '($self->{lang}' . $code . ')';
    $code .= ' || (' . $varref . ')' unless $emptyifnull;
    $code .= ')';
    return $code;
}

# Compile-time вычисление language_ref
sub language_xform
{
    my $self = shift;
    my ($value) = @_;
    my ($ca, $cb) = ($self->{lang}, $self->{lang});
    foreach (split /:/, $self->{cur_template})
    {
        $cb = $cb->{lc $_} if $cb;
    }
    if (@{$self->{blocks}})
    {
        foreach (@{$self->{blocks}})
        {
            $ca = $ca->{lc $_} if $ca;
            $cb = $cb->{lc $_} if $cb;
        }
    }
    $ca = $ca->{$value} if $ca;
    $cb = $cb->{$value} if $cb;
    return $ca || $cb;
}

1;
__END__
