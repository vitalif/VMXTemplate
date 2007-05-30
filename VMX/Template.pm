#!/usr/bin/perl

=head1 Реализация пресловутого "template.php" на Перле
=cut

package VMX::Template;

use strict;
use VMX::Common qw(:all);
use Digest::MD5 qw(md5_hex);
use vars qw($cachedir $root $wrapper %_tpldata %files %compiled_code %uncompiled_code @_tpldata_stack @conv $self);

##
 # Конструктор
 # $obj = new VMX::Template, %init
 ##
sub new {
    my $class = shift;
    my %args = @_;
    $class = ref ($class) || $class;
    my %data = (
        'root' => '.',
        'conv' => [
                {
                    '<' => 'strip_tags',
                    'i' => 'int',
                    's' => 'htmlspecialchars',
                    'l' => 'lc',
                    'u' => 'uc'
                }, {
                    #'c' => 'strlimit'
                }
            ],
        %args
    );
    bless \%data, $class;
    return \%data;
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
 # Функция преобразовывает относительные имена файлов в абсолютные
 # $obj->make_filename ($filename)
 ##
sub make_filename {
    my $self = shift;
    my $fn = $_[0];
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
    our $self = shift;
    my $handle = shift;
    die("Template->parse(): couldn't load template file for handle $handle") unless $self->loadfile($handle);
    $self->{compiled_code}{$handle} = $self->compile ($self->{uncompiled_code}{$handle});
    my $_str = eval ($self->{compiled_code}{$handle});
    die("Template->parse(): $@") if $@;
    $_str = &$self->{wrapper} ($_str) if ($self->{wrapper});
    return $_str;
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
        $lastit = $self->{_tpldata}{$block} - 1;
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
    my ($self, $handle) = @_;
    return 1 if ($self->{uncompiled_code}{$handle});
    die("Template->loadfile(): no file specified for handle $handle") unless ($self->{files}{$handle});

    # если оно false, но задано, значит, код задан, минуя файлы
    if ($self->{files}{$handle})
    {
        my $filename = $self->{files}{$handle};
        my $filepath;

        $filepath = $` if $filename =~ m%(?<=/)[^/]*$%;
        $_ = file_get_contents ($filename);
        die("Template->loadfile(): file for handle $handle is empty") unless $_;

        s/\Q$&\E/file_get_contents($1)/eg while (m/<!-- INCLUDE\s+(.*?)\s+-->/go);
        $self->{uncompiled_code}{$handle} = $_;
    }

    return 1;
}

##
 # Функция компилирует код
 # $compiled_code = $obj->compile ($uncompiled_code)
 ##
sub compile {
    my ($self, $code) = @_;

    my ($sfile, $nesting) = ('', 0);
    my @code_lines = ();
    my @block_names = ('.');
    my ($cbstart, $cbcount, $cbplus, $mm);

    # а может быть, уже кэшировано?
    if ($self->{cachedir}) {
        $self->{cachedir} .= '/' if (substr($self->{cachedir},-1,1) ne '/');
        $sfile = $self->{cachedir} . md5_hex ($code) . '.pl';
        return file_get_contents($sfile) if -e $sfile;
    }

    # комментарии <!--# ... #-->
    $code =~ s/\s*<!--#.*?#-->//gos;

    # форматирование кода для красоты
    $code =~ s/^\s*(<!-- (?:BEGIN|END|IF!?) .*?-->)\s*$/\x01$1\x01\n/gom;
    1 while $code =~ s/(?<=[^\x01])<!-- (?:BEGIN|END|IF!?) .*?-->/\x01$&/gom;
    1 while $code =~ s/<!-- (?:BEGIN|END|IF!?) .*?-->(?=[^\x01])/$&\x01/gom;

    # ' и \ -> \' и \\
    $code =~ s/\'|\\/\\$&/gos;

    # номера итераций
    $code =~ s/\{([a-z0-9\-_]+)\.#\}/\'.(1+(\$_${1}_i)?\$_${1}_i:0)).\'/gois;

    # подстановки переменных
    $code =~ s%\{((?:[a-z0-9\-_]+\.)*)([a-z0-9\-_/]+)(?:\|([a-z0-9\-_/]+))?\}%$self->generate_block_varref($1,$2,$3)%goise;

    # \n -> \n\x01
    $code =~ s/\n/\n\x01/gos;

    # разбиваем код на строки
    @code_lines = split /\x01/, $code;
    foreach (@code_lines) {
        next unless $_;
        if (/^\s*<!-- BEGIN ([A-Za-z0-9\-_]+?) ([A-Za-z \t\-_0-9]*)-->\s*$/os) { # начало блока
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
                if ($cbcount) { $_ = "\$_${1}_count = min (0+(\$self->{_tpldata}{'$1.'}), " . $cbcount . ');'; }
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
        } elsif (/^\s*<!-- END (.*?)-->\s*$/) {
            # чётко проверяем: блок нельзя завершать чем попало
            delete $block_names[$nesting--] if ($nesting > 0 && trim ($1) eq $block_names[$nesting]);
            $_ = "} # END $1";
        } elsif (/^\s*<!-- IF(!?) ((?:[a-zA-Z0-9\-_]+\.)*)([a-zA-Z0-9\-_\/]+) -->\s*$/) {
            $_ = "if ($1(".$self->generate_block_data_ref(substr($2,0,-1),1)."{'$3'})) {";
        } else {
            $_ = "\$t .= '$_';";
        }
    }

    # собираем код в строку
    $code = "no strict;\nmy \$t='';\n" . join ("\n", @code_lines) . "\nreturn \$t;";

    # кэшируем код
    if ($self->{cachedir} && open (my $fd, '>'.$sfile)) {
        print $fd $code;
        close $fd;
    }

    return $code;
}

##
 # Функция генерирует подстановку переменной шаблона
 # $varref = $obj->generate_block_varref ($namespace, $varname, $varoption)
 ##
sub generate_block_varref {
    my $self = shift;
    my ($varconv, $varref);
    my ($namespace, $varname, $varoption) = @_;
    ($varname, $varconv) = split '/', $varname, 2;
    # обрезаем точки в конце
    $namespace =~ s/\.*^//o;

    $varref = $self->generate_block_data_ref ($namespace, 1);
    # готовим альтернативу
    unless ($varoption) { $varoption = "''"; }
    else { $varoption = "((${varref}{'$varoption'}) ? ${varref}{'$varoption'} : '')"; }

    # добавляем имя переменной
    $varref .= "{'$varname'}";
    $varref = "(($varref) ? $varref : $varoption)";

    # # генерируем преобразование [временно отключено]
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
