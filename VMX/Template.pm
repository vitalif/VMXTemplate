#!/usr/bin/perl

=head1 Простой шаблонный движок.
 Когда-то inspired by phpBB templates, которые в свою очередь inspired by
 phplib templates. Однако уже далеко ушедши от них обоих.
=cut

package VMX::Template;

use strict;
use VMX::Common qw(:all);
use Digest::MD5 qw(md5_hex);
use Hash::Merge;

# ускорение быстродействия постоянными stat-ами вместо вычисления md5
my $mtimes = {};
my $uncompiled_code = {};
my $langhashes = {};

##
 # Конструктор
 # $obj = new VMX::Template, %init
 ##
sub new
{
    my $class = shift;
    $class = ref ($class) || $class;
    my $self =
    {
        conv =>
        {
            # char => func_name | \&sub_ref
            'T' => 'strip_tags',
            'i' => 'int',
            's' => 'htmlspecialchars',
            'l' => 'lc',
            'u' => 'uc',
            'q' => 'quotequote',
            'H' => 'strip_unsafe_tags',
            'L' => \&language_ref,
        },
        root            => '.',   # каталог с шаблонами
        cachedir        => undef, # расположение кэша на диске
        wrapper         => undef, # фильтр, вызываемый перед выдачей результата parse
        _tpldata        => {},    # сюда будут сохранены: данные
		lang            => {},    # ~ : языковые данные
        files           => {},    # ~ : имена файлов
        package_names   => {},    # ~ : последние названия пакетов шаблонов
        _tpldata_stack  => [],    # стек tpldata-ы для datapush и datapop
        use_utf8        => undef, # шаблоны в UTF-8 и с флагом UTF-8
        @_
    };
    bless $self, $class;
}

##
 # Функция задаёт имена файлов для хэндлов
 # $obj->set_filenames (handle1 => 'template1.tpl', handle2 => 'template2.tpl', ...)
 ##
sub set_filenames
{
    my $self = shift;
    my %fns = @_;
    while (my ($k,$v) = each(%fns))
    {
        $self->{fnames}->{$k} = $v;
        $self->{files}->{$k} = $self->make_filename($v);
    }
    return 1;
}

##
 # Функция загружает файлы переводов (внутри хеши)
 # $obj->load_lang ($filename, $filename, ...);
 ##
sub load_lang
{
	my $self = shift;
	return $self->load_lang_hashes(map {
        my $mtime = [stat($_)]->[9];
        if (!defined($mtimes->{$_}) || $mtime > $mtimes->{$_})
        {
            $mtimes->{$_} = $mtime;
            $langhashes->{$_} = do($_);
        }
        $langhashes->{$_};
    } @_);
}

##
 # Функция загружает хеши переводов
 # $obj->load_lang_hashes ($hash, $hash, ...);
 ##
sub load_lang_hashes
{
	my $self = shift;
	my $i = 0;
    Hash::Merge::set_behavior('RIGHT_PRECEDENT');
    $self->{lang} = Hash::Merge::merge ($self->{lang}, $_) foreach @_;
	return $i;
}

##
 # Функция преобразовывает относительные имена файлов в абсолютные
 # $obj->make_filename ($filename)
 ##
sub make_filename
{
    my $self = shift;
    my ($fn) = @_;
    $fn = $self->{root}.'/'.$fn if $fn !~ /^\//iso;
    die("Template->make_filename(): file $fn does not exist") unless -f $fn;
    return $fn;
}

##
 # Функция уничтожает данные шаблона
 # $obj->clear ()
 ##
sub clear
{
    shift->{_tpldata} = {};
    return 1;
}

##
 # Функция сохраняет текущие данные шаблона в стек и уничтожает их
 # $obj->datapush ()
 ##
sub datapush
{
    my $self = shift;
    push (@{$self->{_tpldata_stack}}, \$self->{_tpldata});
    destroy $self;
    return 1;
}

##
 # Функция восстанавливает данные шаблона из стека
 # $obj->datapop ()
 ##
sub datapop
{
    my $self = shift;
    return 0 if (@{$self->{_tpldata_stack}} <= 0);
    $self->{_tpldata} = pop @{$self->{_tpldata_stack}};
    return 1;
}

##
 # Функция загружает, компилирует и возвращает результат для хэндла
 # $obj->parse ('handle')
 ##
sub parse
{
    my $self = shift;
    my ($handle) = @_;
    die("[Template] couldn't load template file for handle $handle")
        unless $self->loadfile($handle);
    $self->compile($handle);
    my $str = eval($self->{package_names}->{$handle} . '::parse($self)');
    die("[Template] error parsing $handle: $@") if $@;
    $str = &$self->{wrapper} ($str) if $self->{wrapper};
    return $str;
}

##
 # Функция присваивает переменные блока в новую итерацию
 # $obj->assign_block_vars ($block, varname1 => value1, varname2 => value2, ...)
 ##
sub assign_block_vars
{
    my $self = shift;
    my $block = shift;
    my $vararray = { @_ };
    
    $block =~ s/^\.+//so;
    $block =~ s/\.+$//so;

    if (!$block)
    {
        # если не блок, а корневой уровень
        $self->assign_vars (@_);
    }
    elsif ($block !~ /\.[^\.]/)
    {
        # если блок, но не вложенный
        $block =~ s/\.*$/./; # добавляем . в конец, если надо
		$self->{_tpldata}->{$block} ||= [];
        push @{$self->{_tpldata}->{$block}}, $vararray;
    }
    else
    {
        # если вложенный блок
        my $ev = '$self->{_tpldata}';
        $block =~ s/\.+$//; # обрезаем точки в конце (хоть их 10 там)
        my @blocks = split /\./, $block;
        my $lastblock = pop @blocks;
        foreach (@blocks)
        {
            $ev .= "{'$_.'}";
            $ev .= "[-1+\@\{$ev\}]";
        }
        $ev .= "{'$lastblock.'}";
        $ev = "$ev = [] unless $ev; push \@\{$ev\}, \$vararray;";
        eval ($ev);
    }

    return 1;
}

##
 # Функция добавляет переменные к текущей итерации блока
 # $obj->append_block_vars ($block, varname1 => value1, varname2 => value2, ...)
 ##
sub append_block_vars
{
    my $self = shift;
    my $block = shift;
    my %vararray = @_;
    my $lastit;
    if (!$block || $block eq '.')
    {
        # если не блок, а корневой уровень
        $self->assign_vars (@_);
    }
    elsif ($block !~ /\../)
    {
        # если блок, но не вложенный
        $block =~ s/\.*$/./; # добавляем . в конец, если надо
        $self->{_tpldata}{$block} ||= [];
        $lastit = @{$self->{_tpldata}{$block}} - 1;
        $lastit = 0 if $lastit < 0;
        $self->{_tpldata}{$block}[$lastit]{$_} = $vararray{$_}
            foreach keys %vararray;
    }
    else
    {
        # если вложенный блок
        my $ev = '$self->{_tpldata}';
        $block =~ s/\.+$//; # обрезаем точки в конце (хоть их 10 там)
        my @blocks = split /\.+/, $block;
        foreach (@blocks)
        {
            $ev .= "{'$_.'}";
            $ev .= "[-1+\@\{$ev\}]";
        }
        $ev = "\$ev{\$k} = \$vararray{\$k} foreach \$k (keys \%vararray);";
        eval ($ev);
    }

    return 1;
}

##
 # Функция присваивает переменные корневого уровня
 # $obj->assign_vars (varname1 => value1, varname2 => value2, ...)
 ##
sub assign_vars
{
    my $self = shift;
	$self->{_tpldata}{'.'}[0] = {} unless $self->{_tpldata}{'.'}[0];
    %{$self->{_tpldata}{'.'}[0]} = (%{$self->{_tpldata}{'.'}[0]}, @_);
    return 1;
}

##
 # Аналог assign_vars, но преобразует имена переменных
 ##
sub tr_assign_vars
{
    my $self = shift;
    $self->assign_vars($self->tr_vars(@_));
}

##
 # Аналог assign_block_vars, но преобазует имена переменных
 ##
sub tr_assign_block_vars
{
    my $self = shift;
    my $block = shift;
    $self->assign_block_vars($block, $self->tr_vars(@_));
}

##
 # Аналог append_block_vars, но преобазует имена переменных
 ##
sub tr_append_block_vars
{
    my $self = shift;
    my $block = shift;
    $self->append_block_vars($block, $self->tr_vars(@_));
}

##
 # Собственно функция, которая преобразует имена переменных
 ##
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

##
 # Функция загружает файл для хэндла HANDLE
 # $obj->loadfile ($handle)
 ##
sub loadfile
{
	my $self = shift;
    my ($handle) = @_;
    die("[Template] no file specified for handle $handle")
        unless defined $self->{files}->{$handle};

    # если оно false, но задано, значит, код задан, минуя файлы
    my $fn;
    if ($fn = $self->{files}{$handle})
    {
        my $mtime = [stat($fn)] -> [9];
        return 1 if
            $uncompiled_code->{$fn} &&
            $mtimes->{$fn} >= $mtime;
        my $filepath;

        $filepath = $` if $fn =~ m%(?<=/)[^/]*$%;
        my $cnt = file_get_contents ($fn);
        die("[Template] file for handle $handle is empty") unless $cnt;

        $uncompiled_code->{$fn} = $cnt;
        $mtimes->{$fn} = $mtime;
    }

    return 1;
}

##
 # Функция компилирует код
 # # ref($self) == 'VMX::Template'
 # $pkg_name = $self->compile ($handle)
 # print eval($pkg_name.'::parse($self)');
 ##
sub compile
{
    my $self = shift;
    my ($handle) = @_;
    my $code = $uncompiled_code->{$self->{files}->{$handle}};

    $self->{cur_template_path} = $self->{cur_template} = '';
    if ($self->{fnames}->{$handle})
    {
        $self->{cur_template} = $self->{fnames}->{$handle};
        $self->{cur_template} =~ s/\.[^\.]+$//iso;
        $self->{cur_template} =~ s/:+//gso;
        $self->{cur_template} =~ s!/+!:!gso;
        $self->{cur_template} =~ s/[^\w_:]+//gso;
        $self->{cur_template_path} = "->{\"" . join("\"}->{\"",
            map { lc } split /:/, $self->{cur_template}) . "\"}";
    }

    my $nesting = 0;
    my $included = {};
    my @code_lines = ();
    my @block_names = ('.');
    my ($cbstart, $cbcount, $cbplus, $mm);

    my ($PN, $sfile);
    $sfile = $PN = 'Tpl' . uc(md5_hex($code));
    $PN = __PACKAGE__.'::'.$PN;
    # а может быть, кэшировано в памяти? (т.е модуль уже загружен)
    if (eval('return $'.$PN.'::{parse}'))
    {
        goto _end;
    }

    # а может быть, кэшировано на диске?
    if ($self->{cachedir})
    {
        $self->{cachedir} .= '/' if (substr($self->{cachedir},-1,1) ne '/');
        $sfile = $self->{cachedir} . $sfile . '.pm';
        if (-e $sfile)
        {
            do $sfile;
            if ($@)
            {
                warn $@;
            }
            else
            {
                goto _end;
            }
        }
    }

    # комментарии <!--# ... #-->
    $code =~ s/\s*<!--#.*?#-->//gos;

    $code =~ s/(?:^|\n)\s*(<!--\s*(?:BEGIN|END|IF!?|ELSE|INCLUDE|SET|ENDSET)\s+.*?-->)\s*(?:$|\n)/\x01$1\x01\n/gos;
    # форматирование кода для красоты
    1 while $code =~ s/(?<!\x01)<!--\s*(?:BEGIN|END|IF!?|ELSE|INCLUDE|SET|ENDSET)\s+.*?-->/\x01$&/gom;
    1 while $code =~ s/<!--\s*(?:BEGIN|END|IF!?|ELSE|INCLUDE|SET|ENDSET)\s+.*?-->(?!\x01)/$&\x01/gom;

    # ' и \ -> \' и \\
    $code =~ s/\'|\\/\\$&/gos;

    # "первая замена"
    $code =~ 
        s%
            (?>\%+) |
            (?>\%+)\s*\S+.*?(?>\%+) |
            \{[a-z0-9\-_]+\.\#\} |
            \{((?:[a-z0-9\-_]+\.)*)([a-z0-9\-_]+)((?:->[a-z0-9\-_]+)*)(?:\/([a-z0-9\-_]+))?\}
        % $self->generate_xx_ref($&,$1,$2,$3,$4)
        %goisex;

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
                if ($cbcount) { $_ = "\$_${1}_count = min (scalar(\@\{\$self->{_tpldata}{'$1.'}\}), " . $cbcount . ');'; }
                else { $_ = "\$_${1}_count = scalar(\@{\$self->{_tpldata}{'$1.'}});"; }
                # начало цикла for
                $_ .= "\nfor (\$_${1}_i = $cbstart; \$_${1}_i < \$_${1}_count; \$_${1}_i$cbplus)\n{";
            }
            else
            {
                # блок вложенный
                my $namespace = substr (join ('.', @block_names), 2);
                my $varref = $self->generate_block_data_ref ($namespace);
                if ($cbcount) { $_ = "\$_${1}_count = min (scalar(\@\{$varref\}), $cbcount);"; }
                else { $_ = "\$_${1}_count = (\@\{$varref\}) ? scalar(\@\{$varref\}) : 0;"; }
                $_ .= "\nfor (\$_${1}_i = $cbstart; \$_${1}_i < \$_${1}_count; \$_${1}_i$cbplus)\n{";
            }
        }
        elsif (/^\s*<!--\s*END\s+(.*?)-->\s*$/so)
        {
            # чётко проверяем: блок нельзя завершать чем попало
            delete $block_names[$nesting--] if ($nesting > 0 && trim ($1) eq $block_names[$nesting]);
            $self->{current_namespace} = join '.', @block_names;
            $_ = "} # END $1";
        }
        elsif (/^\s*<!--\s*IF(!?)\s+((?:[a-z0-9\-_]+\.)*)([a-z0-9\-_]+)((?:->[a-z0-9\-_]+)*)\s*-->\s*$/iso)
        {
            $_ = "if ($1(".$self->generate_block_varref($2, $3, $4, undef, 1).")) {";
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
    $code = "package $PN;
use VMX::Common qw(:all);
no strict;
".($self->{use_utf8} ? "use utf8;" : "")."

sub parse {
    my \$self = shift;
    my \$t = '';
    my \$_current_template = [ split /:/, '$self->{cur_template}' ];
    " . join("\n    ", @code_lines) . "
    return \$t;
}

1;
";

    # кэшируем код
    if ($self->{cachedir} && open (my $fd, '>'.$sfile))
    {
        print $fd $code;
        close $fd;
    }
    
    eval $code;
    warn $@ if $@;

_end:
    return $self->{package_names}->{$handle} = $PN;
}

##
 # Функция для первой замены
 ##
sub generate_xx_ref
{
    my $self = shift;
    my @a = @_;
    my $a = shift @a;
    if ($a =~ /^%%|%%$/so)
    {
        my $r = $a;
        $r =~ s/^%%/%/so;
        $r =~ s/%%$/%/so;
        return $r;
    }
    elsif ($a =~ /^%(.+)%$/so)
    {
        return $self->language_xform($self->{current_namespace}, $1);
    }
    elsif ($a =~ /^%%+$/so)
    {
        return substr($a, 1);
    }
    elsif ($a =~ /^\{([a-z0-9\-_]+)\.\#\}$/iso)
    {
        return '\'.(1+($_'.$1.'_i)?$_'.$1.'_i:0)).\'';
    }
    elsif ($a =~ /^\{.*\}$/so)
    {
        return "' . " . $self->generate_block_varref(@a) . " . '";
    }
    return $a;
}

##
 # Функция генерирует подстановку переменной шаблона
 # $varref = $obj->generate_block_varref ($namespace, $varname, $varhash)
 ##
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
    $varref .= "{'$varname'}";
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

##
 # Функция генерирует обращение к массиву переменных блока
 # $blockref = $obj->generate_block_data_ref ($block, $include_last_iterator)
 ##
sub generate_block_data_ref
{
    my $self = shift;
    my $blockref = '$self->{_tpldata}';
    my ($block, $withlastit) = @_;

    # для корневого блока
    return '$self->{_tpldata}{\'.\'}' . ($withlastit ? '[0]' : '')
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

##
 # Функция компилирует ссылку на данные ленгпака
 ##
sub language_ref
{
    my $self = shift;
    my ($var, $varref, $value) = @_;
    my $code = '';
    $code .= '->{' . lc($_) . '}' foreach split /\.+/, $var;
    $code .= '->{' . $varref . '}';
    $code =
        ($self->{cur_template_path} ?
        '(($self->{lang}' . $self->{cur_template_path} . $code . ') || ' : '') .
        '($self->{lang}' . $code . ') || (' .
        $varref . '))';
    return $code;
}

##
 # Compile-time вычисление language_ref
 ##
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

1;
__END__
