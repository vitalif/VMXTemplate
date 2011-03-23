#!/usr/bin/perl

# "Ох уж эти перлисты... что ни пишут - всё Template Toolkit получается!"
# Компилятор переписан уже 2 раза - сначала на regexы, потом на index() :-)
# А обратная совместимость по синтаксису, как ни странно, до сих пор цела.

# Homepage: http://yourcmc.ru/wiki/VMX::Template
# Author: Vitaliy Filippov, 2006-2011
# $Id$

package VMX::Template;

use strict;
use VMX::Common qw(:all uri_escape_hacks);
use Digest::MD5 qw(md5_hex);
use Hash::Merge;
use POSIX;

my $mtimes = {};            # время изменения файлов
my $ltimes = {};            # время загрузки файлов
my $uncompiled_code = {};   # нескомпилированный код
my $compiled_code = {};     # скомпилированный код (sub'ы)

# Конструктор
# $obj = new VMX::Template, %params
sub new
{
    my $class = shift;
    $class = ref ($class) || $class;
    my $self =
    {
        root            => '.',      # каталог с шаблонами
        cache_dir       => undef,    # каталог файлового кэша, ускоряющий работу в случае частых инициализаций интерпретатора
        reload          => 2,        # если 0, шаблоны не будут перечитываться с диска, и вызовов stat() происходить не будет
                                     # если >0, то шаблоны будут перечитываться с диска не чаще чем раз в reload секунд
        wrapper         => undef,    # глобальный фильтр, вызываемый перед выдачей результата parse
        use_utf8        => undef,    # шаблоны в UTF-8 и с флагом UTF-8
        begin_code      => '<!--',   # начало кода
        end_code        => '-->',    # конец кода
        eat_code_line   => 1,        # съедать "лишний" перевод строки, если в строке только инструкция?
        begin_subst     => '{',      # начало подстановки (необязательно)
        end_subst       => '}',      # конец подстановки (необязательно)
        strict_end      => 0,        # жёстко требовать имя блока в его завершающей инструкции (<!-- end block -->)
        raise_error     => 0,        # умирать от фатальных ошибок
        print_error     => 1,        # включать ошибки в вывод шаблонов
        compiletime_functions => {}, # дополнительные компилируемые функции

        tpldata         => {},       # сюда будут сохранены данные
        errors          => [],       # сюда будут сохранены ошибки компиляции

        @_,
    };
    $self->{cache_dir} =~ s!/*$!/!so if $self->{cache_dir};
    $self->{root} =~ s!/*$!/!so;
    bless $self, $class;
}

# Сохранить и/или напечатать потом ошибку, сдохнуть в случае raise_error
sub error
{
    my $self = shift;
    my ($e) = @_;
    if ($self->{input_filename})
    {
        $e = $e." at ".$self->{input_filename}.":".$self->{input_line};
    }
    my $c = [caller 1];
    $e = $c->[3].": $e\n";
    push @{$self->{errors}}, $e;
    die $e if $self->{raise_error};
    return $self->{print_error} ? join('', @{$self->{errors}}) : undef;
}

# Текст ошибок, ещё не включённый в вывод
sub errors
{
    my $self = shift;
    return @{$self->{errors}} ? join('', @{$self->{errors}}) : undef;
}

# Сохранить и/или напечатать потом предупреждение
sub warning
{
    my $self = shift;
    my ($w) = @_;
    if ($self->{input_filename})
    {
        $w = $w." at ".$self->{input_filename}.":".$self->{input_line};
    }
    $w = __PACKAGE__ . "::warning: $w\n";
    push @{$self->{errors}}, $w;
    return undef;
}

# Функция уничтожает данные шаблона
# $obj->clear()
sub clear
{
    %{ shift->{tpldata} } = ();
    return 1;
}

# Функция очищает кэш в памяти
sub clear_memory_cache
{
    my $self = shift;
    %$compiled_code = ();
    %$uncompiled_code = ();
    %$mtimes = ();
    %$ltimes = ();
    return $self;
}

# Получить хеш для записи данных
sub vars
{
    my $self = shift;
    my ($vars) = @_;
    my $t = $self->{tpldata};
    $self->{tpldata} = $vars if $vars;
    return $t;
}

# Вызов функции из шаблона
sub exec_from
{
    my ($self, $filename, $function, $vars) = @_;
    return $self->parse_real($filename, undef, $function, $vars);
}

# Вызов функции из кода шаблона
# Совсем не рекомендовано, но возможно
sub exec_from_inline
{
    my ($self, $code, $function, $vars) = @_;
    return $self->parse_real(undef, $code, $function, $vars);
}

# Обработка главного блока шаблона
# $page = $obj->parse($filename);
# $page = $obj->parse($filename, $tpldata);
sub parse
{
    my ($self, $fn, $vars) = @_;
    return $self->parse_real($fn, undef, '_main', $vars);
}

# Обработка явно переданного кода шаблона
# Менее рекомендовано, но возможно
sub parse_inline
{
    my ($self, $code, $vars) = @_;
    return $self->parse_real(undef, $_[1], '_main', $vars);
}

# "Реальная" функция, обрабатывающая все вызовы типа parse
# $page = $obj->parse_real(filename, inline code, function, vars)
# inline code - передача не имени файла, а кода. Менее рекомендовано, но возможно.
sub parse_real
{
    my $self = shift;
    my ($fn, $textref, $function, $vars) = @_;
    # Загрузка кода
    if ($fn)
    {
        $fn = $self->{root}.$fn if $fn !~ m!^/!so;
        return $self->error("couldn't load template file '$fn'")
            unless $textref = $self->loadfile($fn);
    }
    else
    {
        $textref = \( $_[1] );
    }
    my $str = $self->compile($textref, $fn);
    $function ||= '_main';
    if (ref $str eq 'CODE')
    {
        # кэш от старой версии, которая кэширует coderef'ы, а не хеши
        $str = $self->compile($textref, $fn, 1);
    }
    $str = $str->{$function};
    # иначе (если не coderef), то шаблон - не шаблон, а тупо константа
    if (ref $str eq 'CODE')
    {
        local $self->{tpldata} = $vars if $vars;
        $str = eval { &$str($self) };
        return $self->error("error running '$fn".'::'."$function': $@") if $@;
    }
    # в Perl'е мы не можем просто выплюнуть ошибку на STDOUT
    # (возможно, ещё не отправлены HTTP-заголовки, и сами они не отправятся),
    # print_error все ошибки сливает в текст на выход.
    if (($self->{print_error} || $self->{raise_error}) && @{$self->{errors}})
    {
        substr($str, 0, 0, join("\n", @{$self->{errors}}) . "\n");
        $self->{errors} = [];
    }
    &{$self->{wrapper}}($str) if $self->{wrapper};
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
    if (!$uncompiled_code->{$fn} || $self->{reload} &&
        $ltimes->{$fn}+$self->{reload} > time)
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
        $ltimes->{$fn} = time;
    }
    return $uncompiled_code->{$fn};
}

# Функция компилирует код.
# $sub = $self->compile(\$code, $fn);
# print &$sub($self);
sub compile
{
    my $self = shift;
    my ($coderef, $fn, $force_reload) = @_;
    return $compiled_code->{$coderef} if $compiled_code->{$coderef} && !$force_reload;

    # код не из файла
    if (!$fn)
    {
        my (undef, $f, $l) = caller(1);
        $fn = "(inline template at $f:$l)";
    }

    # кэширование на диске
    my $code = $$coderef;
    Encode::_utf8_off($code);

    my $h;
    if ($self->{cache_dir})
    {
        $h = $self->{cache_dir}.md5_hex($code).'.pl';
        if (-e $h && !$force_reload)
        {
            $compiled_code->{$coderef} = do $h;
            if ($@)
            {
                $self->warning("error compiling '$fn': [$@] in FILE: $h");
                unlink $h;
            }
            else
            {
                return $compiled_code->{$coderef};
            }
        }
    }

    Encode::_utf8_on($code) if $self->{use_utf8};

    # начала/концы спецстрок
    my $bc = $self->{begin_code} || '<!--';
    my $ec = $self->{end_code} || '-->';
    # маркер начала, маркер конца, обработчик, съедать ли начало и конец строки
    my @blk = ([ $bc, $ec, 'compile_code_fragment', $self->{eat_code_line} ]);
    if ($self->{begin_subst} && $self->{end_subst})
    {
        push @blk, [ $self->{begin_subst}, $self->{end_subst}, 'compile_substitution' ];
    }
    for (@blk)
    {
        $_->[4] = length $_->[0];
        $_->[5] = length $_->[1];
    }

    # FIXME в PHP-версии используется отдельный объект $st
    # вероятно, это более корректно, однако конкретных претензий
    # к тому, чтобы хранить текущее состояние компиляции прямо
    # в полях объекта себя тоже не заметно.
    $self->{blocks} = [];
    $self->{in} = [];
    $self->{functions} = [];
    $self->{output_position} = 0;
    $self->{output_plus_len} = 0;
    $self->{input_line} = 0;
    $self->{input_filename} = $fn;

    # ищем фрагменты кода - на регэкспах-то было не очень правильно, да и медленно!
    my ($r, $pp, $b, $i, $e, $f, $frag, $x_pp, $l, $nl, @p) = ('', 0);
    while ($code && $pp < length $code)
    {
        @p = map { index $code, $_->[0], $pp } @blk;
        $b = undef;
        for $i (0..$#p)
        {
            # ближайшее найденное
            $b = $i if $p[$i] >= 0 && (!defined $b || $p[$i] < $p[$b]);
        }
        if (defined $b)
        {
            # это означает, что в случае отсутствия корректной инструкции
            # в найденной позиции надо пропустить ТОЛЬКО её начало и попробовать
            # найти что-нибудь снова!
            $pp = $p[$b]+$blk[$b][4];
            $e = index $code, $blk[$b][1], $pp;
            if ($e >= 0)
            {
                $frag = substr $code, $p[$b]+$blk[$b][4], $e-$p[$b]-$blk[$b][4];
                $f = $blk[$b][2];
                if ($frag =~ /\S/so)
                {
                    # Некоторые инструкции хотят видеть позицию в выходном потоке.
                    # Например, FUNCTION и END. Поэтому преобразуем текст
                    # до вызова обработчика.
                    $x_pp = $pp - $blk[$b][4];
                    $nl = $l = 0;
                    if ($x_pp > 0)
                    {
                        $x_pp = substr($code, 0, $x_pp);
                        $nl = $x_pp =~ tr/\n/\n/;
                        $x_pp =~ s/([\\\'])/\\$1/gso;
                        # съедаем перевод строки, если надо
                        $blk[$b][5] and $x_pp =~ s/\r?\n\r?[ \t]*$//so;
                        $l += 8 if $l = length $x_pp;
                    }
                    # записываем позицию
                    $self->{output_position} = $l + length $r;
                    # блин, они же ещё хотят знать и точку конца директивы!
                    # а в неё входит коммент "#line $self->{input_line} \"$fn\"\n"
                    $self->{output_plus_len} = 10 + length($fn) + length($self->{input_line}+$nl);
                    $frag = $self->$f($frag);
                }
                else
                {
                    $frag = undef;
                }
                if (defined $frag)
                {
                    # есть инструкция
                    $pp -= $blk[$b][4];
                    if ($pp > 0)
                    {
                        substr $code, 0, $pp, '';
                        $self->{input_line} += $nl;
                        $r .= "\$t.='$x_pp';\n" if length $x_pp;
                        $pp = 0;
                    }
                    $r .= "#line $self->{input_line} \"$fn\"\n";
                    $r .= $frag;
                    $self->{input_line} += substr($code, 0, $e+$blk[$b][5]-$p[$b], '') =~ tr/\n/\n/;
                }
            }
        }
        else
        {
            # финиш
            $code =~ s/([\\\'])/\\$1/gso;
            if (!$r)
            {
                # шаблон - тупо константа!
                $pp = -1;
                $r = "'$code'";
            }
            else
            {
                $r .= "\$t.='$code';\n";
            }
            undef $code;
        }
    }

    # перемещаем функции в конец кода
    $code = '';
    while ($f = pop @{$self->{functions}})
    {
        $f = substr($r, $f->[0], $f->[1]-$f->[0], '');
        # проверяем, а не константу ли она возвращает?
        $e = $f;
        $e =~ s/^.*?sub {\nmy \$self = shift;\n/my \$self = 0;\n/so;
        $e =~ s/},\n$//so;
        $e = eval $e;
        if (!$@)
        {
            # константа, от $self никак не зависит
            $e =~ s/([\\\'])/\\$1/gso;
            $f =~ s/^([^=]*=>).*$/$1 $e,/so;
        }
        $code .= $f;
    }

    # основной результат заворачиваем в функцию
    # (если $pp = 0, это просто текстовая константа)
    $r = ($pp < 0 ? $r : "sub {
my \$self = shift;
my \$t = '';
$r
return \$t;
}\n");
    # и заворачиваем всё это в хеш функций шаблона
    $code = ($self->{use_utf8} ? "use utf8;\n" : "") . "{ _main => $r, $code }\n";
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
            $self->warning("error caching '$fn': $! while opening $h");
        }
    }

    # компилируем код
    $compiled_code->{$coderef} = eval $code;
    return $self->error("error compiling '$fn': [$@] in CODE:\n$code") if $@;

    # возвращаем ссылку на процедуру
    return $compiled_code->{$coderef};
}

# ELSE
# ELSE IF expression
sub compile_code_fragment_else
{
    my ($self, $kw, $t) = @_;
    if ($t =~ /^IF\s+(.*)$/iso)
    {
        return compile_code_fragment_if($self, 'elsif', $1);
    }
    return $_[2] ? undef : "} else {";
}

# IF expression
# ELSIF expression
my %cf_if = ('elseif' => "} els", 'elsif' => "} els", 'if' => "");
sub compile_code_fragment_if
{
    my ($self, $kw, $e) = @_;
    my $t = $self->compile_expression($e);
    unless (defined $t)
    {
        $self->warning("Invalid expression in $kw: ($e)");
        return undef;
    }
    $kw = $cf_if{$kw};
    push @{$self->{in}}, [ 'if' ] unless $kw;
    return $kw . "if ($t) {\n";
}
*compile_code_fragment_elsif = *compile_code_fragment_if;
*compile_code_fragment_elseif = *compile_code_fragment_if;

# END [block]
sub compile_code_fragment_end
{
    my ($self, $kw, $t) = @_;
    unless (@{$self->{in}})
    {
        $self->warning("END $t without BEGIN, IF or SET");
        return undef;
    }
    my ($w, $id) = @{$self->{in}->[$#{$self->{in}}]};
    if ($self->{strict_end} &&
        ($t && ($w ne 'begin' || !$id || $id ne $t) ||
        !$t && $w eq 'begin' && $id))
    {
        $self->warning(uc($kw)." $t after ".uc($w)." $id");
        return undef;
    }
    my $in = pop @{$self->{in}};
    if ($w eq 'set')
    {
        return "return \$t;\n};\n";
    }
    elsif ($w eq 'begin' || $w eq 'for')
    {
        $w eq 'begin' && pop @{$self->{blocks}};
        return "}}\n";
    }
    elsif ($w eq 'function')
    {
        my $s = "return \$t;\n},\n";
        $self->{$_} = $in->[2]->{$_} for 'blocks', 'in';
        push @{$self->{functions}->[$#{$self->{functions}}]},
            $self->{output_position} + $self->{output_plus_len} + length $s;
        return $s;
    }
    return "}\n";
}

# SET varref ... END
# SET varref = expression
sub compile_code_fragment_set
{
    my ($self, $kw, $t) = @_;
    return undef if $t !~ /^((?:\w+\.)*\w+)(\s*=\s*(.*))?/iso;
    my $e;
    if ($3)
    {
        $e = $self->compile_expression($3);
        unless (defined $e)
        {
            $self->warning("Invalid expression in $kw: ($3)");
            return undef;
        }
    }
    else
    {
        push @{$self->{in}}, [ 'set', $1 ];
    }
    my $ekw = lc($kw) eq 'function' ? 'sub { my $self = shift; local $self->{tpldata}->{args} = [ @_ ];' : 'eval {';
    return $self->varref($1) . ' = ' . ($e || $ekw . ' my $t = ""') . ";\n";
}

# FUNCTION|BLOCK|MACRO name ... END
# FUNCTION|BLOCK|MACRO name = expression
sub compile_code_fragment_function
{
    my ($self, $kw, $t) = @_;
    return undef if $t !~ /^([^=]*)(=\s*(.*))?/is;
    my $n = $1;
    my $e = $3;
    if ($n !~ /^[^\W\d]\w*$/ || $n eq '_main')
    {
        $self->warning("Template function names:
* must start with a letter
* must consist of alphanumeric characters
* must not be equal to '_main'
I see 'FUNCTION $n' instead.");
        return undef;
    }
    if (@{$self->{functions}} && @{$self->{functions}->[$#{$self->{functions}}]} == 1)
    {
        $self->warning("Template functions cannot be nested");
        return undef;
    }
    my $s = "$n => sub {\nmy \$self = shift;\n";
    if (length $e)
    {
        my $r = $self->compile_expression($e);
        if (!defined $r)
        {
            $self->warning("Invalid expression in $kw: ($e)");
            return undef;
        }
        $s .= "return $r;\n},\n";
        push @{$self->{functions}}, [
            $self->{output_position},
            $self->{output_position} + length $s
        ];
        return $s;
    }
    # блоки сохраняются и сбрасываются
    $self->{in} = [ [
        'function', $n, { in => $self->{in}, blocks => $self->{blocks} }
    ] ];
    $self->{blocks} = [];
    # запоминаем положение в выходном потоке
    # для последующего разбиения его на функции
    push @{$self->{functions}}, [ $self->{output_position} ];
    return $s . "my \$t = '';\n";
}
*compile_code_fragment_block = *compile_code_fragment_function;
*compile_code_fragment_macro = *compile_code_fragment_function;

# INCLUDE template.tpl
# legacy, в новом варианте можно использовать с кавычками, и это уже идёт как функция
sub compile_code_fragment_include
{
    my ($self, $kw, $t) = @_;
    $t =~ s/^([a-z0-9_\.]+)$/\'$1\'/so;
    if (defined($t = $self->compile_expression("include $t")))
    {
        return "\$t.=$t;\n";
    }
    return undef;
}

# FOR[EACH] varref = array
# или
# FOR[EACH] varref (тогда записывается в себя)
sub compile_code_fragment_for
{
    my ($self, $kw, $t, $in) = @_;
    if ($t =~ /^((?:\w+\.)*\w+)(\s*=\s*(.*))?/so)
    {
        push @{$self->{in}}, [ 'for', $t ] unless $in;
        my $v = $self->varref($1);
        my $v_i = $self->varref($1.'#');
        if (substr($v_i,-1) eq substr($v,-1))
        {
            $v_i = "local $v_i = \$i++;\n"
        }
        else
        {
            # небольшой хак для $1 =~ \.\d+$
            $v_i = '';
        }
        $t = $3 ? $self->compile_expression($3) : $v;
        return "{
my \$i = 0;
for (array_items($t)) {
local $v = \$_;
$v_i";
    }
    return undef;
}
*compile_code_fragment_foreach = *compile_code_fragment_for;

# BEGIN block [AT e] [BY e] [TO e]
# тоже legacy, но пока оставлю...
sub compile_code_fragment_begin
{
    my ($self, $kw, $t) = @_;
    if ($t =~ /^([a-z_][a-z0-9_]*)(?:\s+AT\s+(.+))?(?:\s+BY\s+(.+))?(?:\s+TO\s+(.+))?/iso)
    {
        push @{$self->{blocks}}, $1;
        push @{$self->{in}}, [ 'begin', $1 ];
        $t = join '.', @{$self->{blocks}};
        my $e = $t;
        if ($2)
        {
            $e = "subarray($e, $2";
            $e .= ", $4" if $4;
            $e .= ")";
        }
        if ($3)
        {
            $e = "subarray_divmod($e, $3)";
        }
        if ($e ne $t)
        {
            $e = "$t = $e";
        }
        return compile_code_fragment_for($self, 'for', $e, 1);
    }
    return undef;
}

# компиляция фрагмента кода <!-- ... -->. это может быть:
# 1) [ELSE] IF выражение
# 2) BEGIN/FOR/FOREACH имя блока
# 3) END [имя блока]
# 4) SET переменная
# 5) SET переменная = выражение
# 6) INCLUDE имя_файла_шаблона
# 7) выражение
sub compile_code_fragment
{
    my $self = shift;
    my ($e) = @_;
    $e =~ s/^[ \t]+//so;
    $e =~ s/\s+$//so;
    if ($e =~ /^\#/so)
    {
        # комментарий!
        return '';
    }
    my ($sub, $r);
    if ($e =~ s/^(?:(ELS)(?:E\s*)?)?IF!\s+/$1IF NOT /so)
    {
        # обратная совместимость... нафига она нужна?...
        # но пока пусть останется...
        $self->warning("Legacy IF! used, consider changing it to IF NOT");
    }
    my ($kw, $t) = split /\s+/, $e, 2;
    $kw = lc $kw;
    if (($kw !~ /\W/so) &&
        ($sub = $self->can("compile_code_fragment_$kw")) &&
        defined($r = &$sub($self, $kw, $t)))
    {
        return $r;
    }
    else
    {
        $t = $self->compile_expression($e);
        if (defined $t)
        {
            # если заданы маркеры подстановок (по умолчанию { ... }),
            # то выражения, вычисляемые в директивах (по умолчанию <!-- ... -->),
            # не подставляются в результат
            return "$t;\n" if $self->{begin_subst} && $self->{end_subst} &&
                $e !~ /^(parse|process|include|exec)/iso;
            return "\$t.=$t;\n";
        }
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
    return "\$t.=$e;\n";
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
    $e =~ s/^[ \t]+//so;
    $e =~ s/\s+$//so unless $after;
    # строковой или числовой литерал
    if ($e =~ /^((\")(?:[^\"\\]+|\\.)*\"|\'(?:[^\'\\]+|\\.)*\'|-?[1-9]\d*(\.\d+)?|-?0\d*|-?0x\d+)\s*(.*)$/iso)
    {
        if ($4)
        {
            return undef unless $after;
            $$after = $4;
        }
        $e = $1;
        $e =~ s/[\$\@\%]/\\$&/gso if $2;
        return $e;
    }
    # функция нескольких аргументов или вызов метода объекта
    elsif ($e =~ /^([a-z_][a-z0-9_]*((?:\.[a-z0-9_]+)*))\s*\((.*)$/iso)
    {
        # вызов методов по цепочке типа obj.method().key.other_method() не поддерживаем
        # (в PHP-версии за просто так не сделаешь, а мы хотим быть совместимыми)
        my $f = $1;
        my $varref;
        my $a = $3;
        if ($2)
        {
            # вызов метода объекта obj.method()
            $varref = $f;
            $varref =~ s/^(.*)\.([^\.]*)$/$1/so;
            $f = $2;
            if ($f =~ /^[^a-z_]/is)
            {
                $self->warning("Object method name cannot start with a number: '$f' of '$varref'");
                return undef;
            }
            $varref = $self->varref($varref) . '->' . $f;
        }
        else
        {
            $f = lc $f;
            my $s;
            unless ($s = $self->{compiletime_functions}->{$f})
            {
                # встроенная функция
                unless ($s = $self->can("function_$f"))
                {
                    $self->warning("Unknown function: $f");
                    return undef;
                }
            }
            $f = $s;
        }
        # разбираем аргументы
        my @a;
        while (defined($e = $self->compile_expression($a, \$a)))
        {
            push @a, $e;
            if ($a =~ /^\s*((,|=>)\s*)?\)/so)
            {
                last;
            }
            elsif ($a !~ s/^\s*(,|=>)//so)
            {
                $self->warning("Unexpected token: '$a' in $f() parameter list");
                return undef;
            }
        }
        if ($a !~ s/^\s*((,|=>)\s*)?\)\s*//so)
        {
            $self->warning("Unexpected token: '$a' in the end of $f() parameter list");
            return undef;
        }
        if ($a)
        {
            return undef unless $after;
            $$after = $a;
        }
        if ($varref)
        {
            # вызов метода объекта
            return "$varref(".join(',', @a).")";
        }
        # встроенная функция
        return &$f($self, @a);
    }
    # функция одного аргумента
    elsif ($e =~ /^([a-z_][a-z0-9_]*)\s+(?=\S)(.*)$/iso)
    {
        my $f = lc $1;
        unless ($self->can("function_$f"))
        {
            $self->warning("Unknown function: '$f' in '$e'");
            return undef;
        }
        my $a = $2;
        my $arg = $self->compile_expression($a, \$a);
        unless (defined $arg)
        {
            $self->warning("Invalid expression: ($e)");
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
    elsif ($e =~ /^((?:[a-z0-9_]+\.)*(?:[a-z0-9_]+\#?))(?:\/([a-z]+))?\s*(.*)$/iso)
    {
        if ($3)
        {
            return undef unless $after;
            $$after = $3;
        }
        $e = $self->varref($1);
        if ($2)
        {
            my $f = lc $2;
            unless ($self->can("function_$f"))
            {
                $self->warning("Unknown function: '$f' called in legacy mode ($&)");
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
    my $t = '$self->{tpldata}';
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

# вспомогательная функция - возвращает элементы массива или скаляр,
# если он не ссылка на массив
sub array_items { ref($_[0]) && $_[0] =~ /ARRAY/ ? @{$_[0]} : (defined $_[0] ? ($_[0]) : ()) }

# вызов функции с аргументами и раскрытием массивов
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

#############
## ФУНКЦИИ ##
#############

## Числа / логические значения

# логические операции
sub function_or      { fmop('||', @_) }
sub function_and     { fmop('&&', @_) }
sub function_not     { "!($_[1])" }
# арифметические операции
sub function_add     { fmop('+', @_) }
sub function_sub     { fmop('-', @_) }
sub function_mul     { fmop('*', @_) }
sub function_div     { fmop('/', @_) }
sub function_mod     { fmop('%', @_) }
# логарифм
sub function_log     { "log($_[1])" }
# чётный, нечётный
sub function_even    { "!(($_[1]) & 1)" }
sub function_odd     { "(($_[1]) & 1)" }
# приведение к целому числу
sub function_int     { "int($_[1])" }                   *function_i = *function_int;    *function_intval = *function_int;
# сравнения: = != > < >= <= (аргументов как строк)
sub function_eq      { "(($_[1]) eq ($_[2]))" }         *function_seq = *function_eq;
sub function_ne      { "(($_[1]) ne ($_[2]))" }         *function_sne = *function_ne;
sub function_gt      { "(($_[1]) gt ($_[2]))" }         *function_sgt = *function_gt;
sub function_lt      { "(($_[1]) lt ($_[2]))" }         *function_slt = *function_lt;
sub function_ge      { "(($_[1]) ge ($_[2]))" }         *function_sge = *function_ge;
sub function_le      { "(($_[1]) le ($_[2]))" }         *function_sle = *function_le;
# сравнения: = != > < >= <= (аргументов как чисел)
sub function_neq     { "(($_[1]) == ($_[2]))" }
sub function_nne     { "(($_[1]) != ($_[2]))" }
sub function_ngt     { "(($_[1]) >  ($_[2]))" }
sub function_nlt     { "(($_[1]) <  ($_[2]))" }
sub function_nge     { "(($_[1]) >= ($_[2]))" }
sub function_nle     { "(($_[1]) <= ($_[2]))" }
# тернарный оператор $1 ? $2 : $3
sub function_yesno   { "(($_[1]) ? ($_[2]) : ($_[3]))" }

## Строки

# нижний и верхний регистр
sub function_lc      { "lc($_[1])" }                    *function_lower = *function_lowercase = *function_lc;
sub function_uc      { "uc($_[1])" }                    *function_upper = *function_uppercase = *function_uc;
# нижний и верхний регистр первого символа
sub function_lcfirst { "lcfirst($_[1])" }
sub function_ucfirst { "ucfirst($_[1])" }
# экранировать двойные и одинарные кавычки в стиле C (добавить \)
sub function_quote   { "quotequote($_[1])" }            *function_q = *function_quote; *function_addslashes = *function_q;
# экранировать двойные кавычки в стиле SQL/CSV (удвоением)
sub function_sq      { "sql_quote($_[1])" }             *function_sql_quote = *function_sq;
# экранирование символов, специальных для регулярного выражения
sub function_requote { "requote($_[1])" }               *function_re_quote = *function_preg_quote = *function_requote;
# кодировать символы в стиле URL
sub function_uriquote{ shift; "URI::Escape::uri_escape(".join(",",@_).")" }            *function_uri_escape = *function_urlencode = *function_uriquote;
# замена регэкспов
sub function_replace { "resub($_[1], $_[2], $_[3])" }
# замена подстрок (а не регэкспов)
sub function_str_replace { "exec_str_replace($_[1], $_[2], $_[3])" }
# длина строки в символах
sub function_strlen  { "strlen($_[1])" }
# подстрока
sub function_substr  { shift; "substr(".join(",", @_).")" }    *function_substring = *function_substr;
# обрезать пробелы из начала и конца строки
sub function_trim    { shift; "trim($_[0])" }
# разделить строку $2 по регулярному выражению $1 опционально с лимитом $3
sub function_split   { shift; "split(".join(",", @_).")" }
# заменить символы & < > " ' на HTML-сущности
sub function_html    { "htmlspecialchars($_[1])" }      *function_s = *function_html; *function_htmlspecialchars = *function_html;
# удалить все HTML-теги
sub function_strip   { "strip_tags($_[1])" }            *function_t = *function_strip; *function_strip_tags = *function_strip;
# оставить только "безопасные" HTML-теги
sub function_h       { "strip_unsafe_tags($_[1])" }     *function_strip_unsafe = *function_h;
# заменить \n на <br />
sub function_nl2br   { "resub(qr/\\n/so, '<br />', $_[1])" }
# конкатенация строк
sub function_concat  { fmop('.', @_) }
# объединяет не просто скаляры, а также все элементы массивов
sub function_join    { fearr('join', 1, @_) }           *function_implode = *function_join;
# подставляет на места $1, $2 и т.п. в строке аргументы
sub function_subst   { fearr('exec_subst', 1, @_) }
# sprintf
sub function_sprintf { fearr('sprintf', 1, @_) }
# strftime
sub function_strftime
{
    my $self = shift;
    my $e = $_[1];
    $e = "($e).' '.($_[2])" if $_[2];
    $e = "VMX::Common::estrftime($_[0], localtime(timestamp($e)))";
    $e = "utf8on($e)" if $self->{use_utf8};
    return $e;
}
# ограничение длины строки $maxlen символами на границе пробелов и добавление '...', если что.
sub function_strlimit{ shift; "strlimit(".join(",", @_).")" }   *function_truncate = *function_strlimit;

## Массивы и хеши

# создание хеша
sub function_hash    { shift; @_ == 1 ? "{ \@{ $_[0] } }" : "{" . join(",", @_) . "}"; }
# ключи хеша
sub function_keys    { '[ keys(%{'.$_[1].'}) ]'; }      *function_hash_keys = *function_keys; *function_array_keys = *function_keys;
# сортировка массива
sub function_sort    { '[ '.fearr('sort', 0, @_).' ]'; }
# пары { id => ключ, name => значение } для хеша
sub function_pairs   { "exec_pairs($_[1])" }            *function_each = *function_pairs;
# создание массива
sub function_array   { shift; "[" . join(",", @_) . "]"; }
# диапазон значений
sub function_range   { "($_[1] .. $_[2])" }
# проверка, аргумент - массив или не массив?
sub function_is_array{ "exec_is_array($_[1])" }
# количество элементов _массива_ (не хеша)
sub function_count   { "(ref($_[1]) && $_[1] =~ /ARRAY/so ? scalar(\@{ $_[1] }) : 0)" }
# подмассив по номерам элементов
sub function_subarray { shift; "exec_subarray(" . join(",", @_) . ")"; }    *function_array_slice = *function_subarray;
# подмассив по кратности номеров элементов
sub function_subarray_divmod { shift; "exec_subarray_divmod(" . join(",", @_) . ")"; }
# получить элемент хеша/массива по неконстантному ключу (например get(iteration.array, rand(5)))
# по-моему, это лучше, чем Template Toolkit'овский ад - hash.key.${another.hash.key}.зюка.хрюка и т.п.
sub function_get     { shift; "exec_get(" . join(",", @_) . ")"; }
# для хеша
sub function_hget    { "($_[1])->\{$_[2]}" }
# для массива
sub function_aget    { "($_[1])->\[$_[2]]" }
# присваивание (только lvalue)
sub function_set     { "($_[1] = $_[2])" }
# слияние массивов в один большой массив
sub function_array_merge { shift; '[@{'.join('},@{',@_).'}]' }
# вынуть первый элемент массива
sub function_shift   { "shift(\@{$_[1]})"; }
# вынуть последний элемент массива
sub function_pop     { "pop(\@{$_[1]})"; }
# вставить как первый элемент массива
sub function_unshift { shift; "unshift(\@{".shift(@_)."}, ".join(",", @_).")"; }
# вставить как последний элемент массива
sub function_push    { shift; "push(\@{".shift(@_)."}, ".join(",", @_).")"; }

## Прочее

# вычисление выражения и игнорирование результата, как в JS
sub function_void    { "scalar(($_[1]), '')" }
# дамп переменной
sub function_dump    { shift; "exec_dump(" . join(",", @_) . ")" }          *function_var_dump = *function_dump;
# JSON-кодирование
sub function_json    { "encode_json($_[1])" }

# включение другого файла: parse('файл'[, аргументы]) */
sub function_parse
{
    shift;
    my $fn = shift;
    return "\$self->parse_real($fn, undef, '_main'".auto_hash(@_).")";
}
*function_process = *function_parse;
*function_include = *function_parse;

# включение блока из текущего файла: exec('блок'[, аргументы])
sub function_exec
{
    my $self = shift;
    my $block = shift;
    my $fn = $self->{input_filename};
    $fn =~ s/([\'\\])/\\$1/gso;
    return "\$self->parse_real('$fn', undef, $block".auto_hash(@_).")";
}

# включение блока из другого файла: exec_from('файл', 'блок'[, аргументы])
sub function_exec_from
{
    shift;
    my $fn = shift;
    my $block = shift;
    return "\$self->parse_real($fn, undef, $block".auto_hash(@_).")";
}

# parse не из файла, хотя и не рекомендуется
sub function_parse_inline
{
    shift;
    my $code = shift;
    return "\$self->parse_real(undef, $code, '_main'".auto_hash(@_).")";
}
*function_process_inline = *function_parse_inline;
*function_include_inline = *function_parse_inline;

# сильно не рекомендуется, но возможно:
# включение блока не из файла:
# exec_from_inline('код', 'блок'[, аргументы])
sub function_exec_from_inline
{
    shift;
    my $code = shift;
    my $block = shift;
    return "\$self->parse_real(undef, $code, $block".auto_hash(@_).")";
}

# вызов функции объекта по вычисляемому имени:
# call(object, "method", arg1, arg2, ...) или
# call_array(object, "method", array(arg1, arg2, ...))
sub function_call       { shift; "exec_call(" . join(",", @_) . ")"; }
sub function_call_array { "exec_call($_[1], $_[2], @{ $_[3] })"; }

# map()
sub function_map
{
    my $self = shift;
    my $f = shift;
    my $def = $self->varref('_');
    $def = "\Q$def\E";
    $f =~ s/$def/\$_/giso;
    return '[ '.fearr('map { '.$f.' }', 0, $self, @_).' ]';
}

########################
## Реализации функций ##
########################

# подмассив
# exec_subarray([], 0, 10)
# exec_subarray([], 2)
# exec_subarray([], 0, -1)
sub exec_subarray
{
    my ($array, $from, $to) = @_;
    return $array unless $from;
    $to ||= 0;
    $from += @$array if $from < 0;
    $to += @$array if $to <= 0;
    return [ @$array[$from..$to] ];
}

# подмассив по кратности номеров элементов
# exec_subarray_divmod([], 2)
# exec_subarray_divmod([], 2, 1)
sub exec_subarray_divmod
{
    my ($array, $div, $mod) = @_;
    return $array unless $div;
    $mod ||= 0;
    return [ @$array[grep { $_ % $div == $mod } 0..$#$array] ];
}

# получение элемента хеша или массива
sub exec_get
{
    defined $_[1] && ref $_[0] || return $_[0];
    $_[0] =~ /ARRAY/ && return $_[0]->[$_[1]];
    return $_[0]->{$_[1]};
}

# выполняет подстановку function_subst
sub exec_subst
{
    my $str = shift;
    $str =~ s/(?<!\\)((?:\\\\)*)\$(?:([1-9]\d*)|\{([1-9]\d*)\})/$_[($2||$3)-1]/gisoe;
    return $str;
}

# пары { key => ключ, value => значение } для хеша
sub exec_pairs
{
    my $hash = shift;
    return [ map { { key => $_, value => $hash->{$_} } } sort keys %{ $hash || {} } ];
}

# проверка, массив или нет?
sub exec_is_array
{
    return ref $_[1] && $_[1] =~ /ARRAY/;
}

# замена _подстрок_ (а не регэкспов)
sub exec_str_replace
{
    my ($s, $sub, $v) = @_;
    $v =~ s/\Q$s\E/$sub/gso;
    return $v;
}

# вызов функции $2 объекта $1 с параметрами $3 и далее
sub exec_call
{
    my $o = shift;
    my $m = shift;
    return $o->$m(@_);
}

# Data::Dumper
sub exec_dump
{
    require Data::Dumper;
    local $Data::Dumper::Indent = 1;
    local $Data::Dumper::Varname = '';
    local $Data::Dumper::Sortkeys = 1;
    return scalar Data::Dumper::Dumper(@_);
}

# автоматическое создание хеша из хешрефа или списка
sub auto_hash
{
    if (!@_)
    {
        return "";
    }
    elsif (@_ == 1)
    {
        return ', ' . $_[0];
    }
    else
    {
        return ', {'.join(',', @_).'}';
    }
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

=head2 S=HTML, T=STRIP, H=STRIP_UNSAFE

Преобразование символов < > & " ' в HTML-сущности,

Удаление всех тегов,

Удаление запрещённых тегов.

=head2 Q=QUOTE, REQUOTE=RE_QUOTE=PREG_QUOTE

Экранирование символов " ' \

А также экранирование символов, являющихся специальными в регулярных выражениях (см. perldoc perlre).

=cut
