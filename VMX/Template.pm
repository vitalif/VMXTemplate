#!/usr/bin/perl

=head1 Простой шаблонный движок.
 Inspired by phpBB templates, которые в свою очередь inspired by
 phplib templates.
=cut

package VMX::Template;

use strict;
use VMX::Common qw(:all);
use Digest::MD5 qw(md5_hex);

# ускорение быстродействия постоянными stat-ами
my $mtimes = {};
my $uncompiled_code = {};
my $langhashes = {};

##
 # Конструктор
 # $obj = new VMX::Template, %init
 ##
sub new {
    my $class = shift;
    $class = ref ($class) || $class;
    my $self = {
        conv => [
                {
                    '<' => 'strip_tags',
                    'i' => 'int',
                    's' => 'htmlspecialchars',
                    'l' => 'lc',
                    'u' => 'uc',
                }, {
                    #'c' => 'strlimit'
                }
            ],
        root            => '.',   # каталог с шаблонами
        cachedir        => undef, # расположение кэша на диске
        wrapper         => undef, # фильтр, вызываемый перед выдачей результата parse
        _tpldata        => {},    # сюда будут сохранены: данные
        regions         => {},    # ~ : коды областей (<!-- REGION -->)
		lang            => {},    # ~ : языковые данные
        files           => {},    # ~ : имена файлов
        package_names   => {},    # ~ : последние названия пакетов шаблонов
        _tpldata_stack  => [],    # стек tpldata-ы для datapush и datapop
        @_
    };
    bless $self, $class;
}

##
 # Функция задаёт имена файлов для хэндлов
 # $obj->set_filenames (handle1 => 'template1.tpl', handle2 => 'template2.tpl', ...)
 ##
sub set_filenames {
    my $self = shift;
    my %fns = @_;
    while (my ($k,$v) = each(%fns)) {
        $self->{files}{$k} = $self->make_filename($v);
    }
    return 1;
}

##
 # Функция загружает файлы переводов (внутри хеши)
 # $obj->load_lang ($filename, $filename, ...);
 ##
sub load_lang {
	my $self = shift;
	return $self->load_lang_hashes(map {
        my $mtime = [stat($_)]->[9];
        if (!defined($mtimes->{$_}) || $mtime > $mtimes->{$_}) {
            $mtimes->{$_} = $mtime;
            return $langhashes->{$_} = do($_);
        } else {
            return $langhashes->{$_};
        }
    } @_);
}

##
 # Функция загружает хеши переводов
 # $obj->load_lang_hashes ($hash, $hash, ...);
 ##
sub load_lang_hashes {
	my $self = shift;
	my $i = 0;
	foreach my $new (@_) {
		unless ($@) {
			$self->{lang}->{$_} = $new->{$_}, $i++ foreach keys %$new;
		}
	}
	return $i;
}

##
 # Функция преобразовывает относительные имена файлов в абсолютные
 # $obj->make_filename ($filename)
 ##
sub make_filename {
    my $self = shift;
    my ($fn) = @_;
    $fn = $self->{root}.'/'.$fn if ($fn !~ m%^/%o);
    die("Template->make_filename(): file $fn does not exist") unless (-e $fn);
    return $fn;
}

##
 # Функция уничтожает данные шаблона
 # $obj->destroy ()
 ##
sub destroy {
    shift->{_tpldata} = {};
    return 1;
}

##
 # Функция сохраняет текущие данные шаблона в стек и уничтожает их
 # $obj->datapush ()
 ##
sub datapush {
    my $self = shift;
    push (@{$self->{_tpldata_stack}}, \$self->{_tpldata});
    destroy $self;
    return 1;
}

##
 # Функция восстанавливает данные шаблона из стека
 # $obj->datapop ()
 ##
sub datapop {
    my $self = shift;
    return 0 if (@{$self->{_tpldata_stack}} <= 0);
    $self->{_tpldata} = pop @{$self->{_tpldata_stack}};
    return 1;
}

##
 # Функция загружает, компилирует и возвращает результат для хэндла
 # $obj->parse ('handle')
 ##
sub parse {
    my $self = shift;
    my $handle = shift;
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
sub assign_block_vars {
    my $self = shift;
    my $block = shift;
    my $vararray = { @_ };

    if (!$block || $block =~ /^\.+$/so) { # если не блок, а корневой уровень
        $self->assign_vars (@_);
    } elsif ($block !~ /\.[^\.]/) { # если блок, но не вложенный
        $block =~ s/\.*$/./; # добавляем . в конец, если надо
		$self->{_tpldata}{$block} = [] unless $self->{_tpldata}{$block};
        push @{$self->{_tpldata}{$block}}, $vararray;
    } else { # если вложенный блок
        my $ev = '$self->{_tpldata}';
        $block =~ s/\.+$//; # обрезаем точки в конце (хоть их 10 там)
        my @blocks = split /\./, $block;
        my $lastblock = pop @blocks;
        foreach (@blocks) {
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
sub append_block_vars {
    my $self = shift;
    my $block = shift;
    my %vararray = @_;
    my $lastit;

    if (!$block || $block eq '.') { # если не блок, а корневой уровень
        $self->assign_vars (@_);
    } elsif ($block !~ /\../) { # если блок, но не вложенный
        $block =~ s/\.*$/./; # добавляем . в конец, если надо
        $lastit = @{$self->{_tpldata}{$block}} - 1;
        $self->{_tpldata}{$block}[$lastit]{$_} = $vararray{$_} foreach (keys %vararray);
    } else { # если вложенный блок
        my $ev = '$self->{_tpldata}';
        $block =~ s/\.+$//; # обрезаем точки в конце (хоть их 10 там)
        my @blocks = split /\.+/, $block;
        foreach (@blocks) {
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
sub assign_vars {
    my $self = shift;
	$self->{_tpldata}{'.'}[0] = {} unless $self->{_tpldata}{'.'}[0];
    %{$self->{_tpldata}{'.'}[0]} = (%{$self->{_tpldata}{'.'}[0]}, @_);
    return 1;
}

##
 # Функция загружает файл для хэндла HANDLE
 # $obj->loadfile ($handle)
 ##
sub loadfile {
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
sub compile {
    my $self = shift;
    my ($handle) = @_;
    my $code = $uncompiled_code->{$self->{files}->{$handle}};

    my $nesting = 0;
    my $included = {};
    my @code_lines = ();
    my @block_names = ('.');
    my ($cbstart, $cbcount, $cbplus, $mm);

    my ($PN, $sfile);
    $sfile = $PN = 'Tpl' . uc(md5_hex($code));
    $PN = __PACKAGE__.'::'.$PN;
    # а может быть, кэшировано в памяти? (т.е модуль уже загружен)
    if (eval('return $'.$PN.'::{parse}')) {
        goto _end;
    }
    
    # а может быть, кэшировано на диске?
    if ($self->{cachedir}) {
        $self->{cachedir} .= '/' if (substr($self->{cachedir},-1,1) ne '/');
        $sfile = $self->{cachedir} . $sfile . '.pm';
        if (-e $sfile) {
            do $sfile;
            if ($@) {
                warn $@;
            } else {
                goto _end;
            }
        }
    }

    # комментарии <!--# ... #-->
    $code =~ s/\s*<!--#.*?#-->//gos;

    # форматирование кода для красоты
    $code =~ s/(?:^|\n)\s*(<!--\s*(?:BEGIN|END|IF!?|INCLUDE|REGION|ENDREGION|INCREGION)\s+.*?-->)\s*(?:$|\n)/\x01$1\x01\n/gos;
    1 while $code =~ s/(?<!\x01)<!--\s*(?:BEGIN|END|IF!?|INCLUDE|REGION|ENDREGION|INCREGION)\s+.*?-->/\x01$&/gom;
    1 while $code =~ s/<!--\s*(?:BEGIN|END|IF!?|INCLUDE|REGION|ENDREGION|INCREGION)\s+.*?-->(?!\x01)/$&\x01/gom;
	
    # ' и \ -> \' и \\
    $code =~ s/\'|\\/\\$&/gos;

    # номера итераций
    $code =~ s/\{([a-z0-9\-_]+)\.#\}/\'.(1+(\$_${1}_i)?\$_${1}_i:0)).\'/gois;

    # подстановки переменных {block.block.[...].variable[|alternative]}
    $code =~ s%\{((?:[a-z0-9\-_]+\.)*)([a-z0-9\-_/]+)(?:\|([a-z0-9\-_/]+))?\}%$self->generate_block_varref($1,$2,$3)%goise;

	# переводы <!-- L section.section.section VARIABLE|"string" -->
	$code =~ s%<!--\s+L\s+((?:\w+\.)*\w+)\s+(\"(?:[^\\\"]+|\\\"|\\\\)*\"|(?:[a-z0-9\-_]+\.)*(?:[a-z0-9\-_/]+))\s+-->%$self->generate_l_ref($1,$2)%goise;

    # \n -> \n\x01
    $code =~ s/\n/\n\x01/gos;

    # разбиваем код на строки
    @code_lines = split /\x01/, $code;
    foreach (@code_lines) {
        next unless $_;
        if (/^\s*<!--\s*BEGIN\s+([A-Za-z0-9\-_]+?)\s+([A-Za-z \t\-_0-9]*)-->\s*$/so) { # начало блока
            $nesting++;
            $block_names[$nesting] = $1;
            $cbstart = 0; $cbcount = ''; $cbplus = '++';

            {
                my $o2 = $2;
                if ($o2 =~ /^[ \t]*AT ([0-9]+)[ \t]*(?:([0-9]+)[ \t]*)?$/) {
                    $cbstart = $1;
                    $cbcount = $2 ? $1+$2 : 0;
                } elsif ($o2 =~ /^[ \t]*MOD ([1-9][0-9]*) ([0-9]+)[ \t]*$/) {
                    $cbstart = $2;
                    $cbplus = '+='.$1;
                }
            }

            # либо min (N, $cbcount) если $cbcount задано
            # либо просто N если нет
            if ($nesting < 2) { # блок не вложенный
                if ($cbcount) { $_ = "\$_${1}_count = min (scalar(\@\{\$self->{_tpldata}{'$1.'}\}), " . $cbcount . ');'; }
                else { $_ = "\$_${1}_count = scalar(\@{\$self->{_tpldata}{'$1.'}});"; }
                # начало цикла for
                $_ .= "\nfor (\$_${1}_i = $cbstart; \$_${1}_i < \$_${1}_count; \$_${1}_i$cbplus)\n{";
            }
            else { # блок вложенный
                my $namespace = substr (join ('.', @block_names), 2);
                my $varref = $self->generate_block_data_ref ($namespace);
                if ($cbcount) { $_ = "\$_${1}_count = min (scalar(\@\{$varref\}), $cbcount);"; }
                else { $_ = "\$_${1}_count = (\@\{$varref\}) ? scalar(\@\{$varref\}) : 0;"; }
                $_ .= "\nfor (\$_${1}_i = $cbstart; \$_${1}_i < \$_${1}_count; \$_${1}_i$cbplus)\n{";
            }
        } elsif (/^\s*<!--\s*END\s+(.*?)-->\s*$/so) {
            # чётко проверяем: блок нельзя завершать чем попало
            delete $block_names[$nesting--] if ($nesting > 0 && trim ($1) eq $block_names[$nesting]);
            $_ = "} # END $1";
        } elsif (/^\s*<!--\s*IF(!?)\s+((?:[a-zA-Z0-9\-_]+\.)*)([a-zA-Z0-9\-_\/]+)\s*-->\s*$/so) {
            $_ = "if ($1(".$self->generate_block_data_ref(substr($2,0,-1),1)."{'$3'})) {";
        } elsif (/^\s*<!--\s*INCLUDE\s*([^'\s]+)\s*-->\s*$/so) {
            $_ = ($included->{$1} ? "\$self->set_filenames('_INCLUDE$1' => $1);\n    " : '')."\$t .= \$self->parse('_INCLUDE$1');";
            $included->{$1} = 1;
        } elsif (/^\s*<!--\s*REGION\s+([a-zA-Z0-9\-_]+)\s*-->\s*$/so) {
			$_ = "\$self->{regions}->{'$1'} = sub {\n    my \$self = shift;\n    my \$t='';\n    my \$tmp='';";
		} elsif (/^\s*<!--\s*ENDREGION\s*-->\s*$/so) {
			$_ = "return \$t;\n};";
		} elsif (/^\s*<!--\s*INCREGION\s+([a-zA-Z0-9\-_]+)\s*-->\s*$/so) {
			$_ = "\$tmp = \$self->{regions}->{'$1'};\n    \$t .= &\$tmp(\$self) if ref(\$tmp) eq 'CODE';";
		} else {
            $_ = "\$t .= '$_';";
        }
    }

    # собираем код в строку
    $code = "package $PN;
use VMX::Common qw(:all);
no strict;

sub parse {
    my \$self = shift;
    my \$t = '';
    my \$tmp = '';
    " . join("\n    ", @code_lines) . "
    return \$t;
}

1;
";

    # кэшируем код
    if ($self->{cachedir} && open (my $fd, '>'.$sfile)) {
        print $fd $code;
        close $fd;
    }
    
    eval $code;
    warn $@ if $@;

_end:
    return $self->{package_names}->{$handle} = $PN;
}

##
 # Функция выдаёт код, переводящий строку в кавычках или переменную шаблона
 # $translation = $obj->generate_l_ref ($section, $what);
 ##
sub generate_l_ref {
	my $self = shift;
	my ($section, $what) = @_;
	$section =~ s/\\/\\\\/gso;
	$section =~ s/\'/\\\'/gso;
	$section =~ s/\./\'}->{\'/gso;
	if ($what !~ /^\"/so || $what !~ /\"$/so) {
		my $block = '';
		$block = $1 if $what =~ s/^([^\.]+)\.//iso;
		$what = $self->generate_block_varref ($block, $what);
		$what =~ s/^\' \. //iso;
		$what =~ s/ \. \'$//iso;
	} else {
		$what =~ s/^\"//so;
		$what =~ s/\"$//so;
		$what =~ s/\'/\\\'/gso;
		$what = "'$what'";
	}
	return '\' . ($self->{lang}->{\''.$section.'\'}->{'.$what.'} || \'\') . \'';
}

##
 # Функция генерирует подстановку переменной шаблона
 # $varref = $obj->generate_block_varref ($namespace, $varname, $varoption)
 ##
sub generate_block_varref {
    my $self = shift;
    my ($namespace, $varname, $varoption) = @_;
    my ($varconv, $varref);
    ($varname, $varconv) = split '/', $varname, 2;
    # обрезаем точки в конце
    $namespace =~ s/\.*$//o;

    $varref = $self->generate_block_data_ref ($namespace, 1);
    # готовим альтернативу
    unless ($varoption) { $varoption = "''"; }
    else { $varoption = "((${varref}{'$varoption'}) ? ${varref}{'$varoption'} : '')"; }

    # добавляем имя переменной
    $varref .= "{'$varname'}";
    $varref = "(defined $varref ? $varref : $varoption)";

    # # генерируем преобразование [not implemented]
    # $varref = $self->generate_conversion_ref ($varref, $varconv) if ($varconv);
    $varref = "' . $varref . '";
    return $varref;
}

##
 # Функция генерирует обращение к массиву переменных блока
 # $blockref = $obj->generate_block_data_ref ($block, $include_last_iterator)
 ##
sub generate_block_data_ref {
    my $self = shift;
    my $blockref = '$self->{_tpldata}';
    my ($block, $withlastit) = @_;

    # для корневого блока
    return '$self->{_tpldata}{\'.\'}' . ($withlastit ? '[0]' : '') if ($block =~ /^\.*$/o);

    # строим цепочку блоков
    $block =~ s/\.+$//o;
    my @blocks = split (/\.+/, $block);
    my $lastblock = pop (@blocks);
    $blockref .= "{'$_.'}[\$_${_}_i]" foreach @blocks;
    $blockref .= "{'$lastblock.'}";

    # добавляем последний итератор, если надо
    $blockref .= "[\$_${lastblock}_i]" if ($withlastit);
    return $blockref;
}

1;
