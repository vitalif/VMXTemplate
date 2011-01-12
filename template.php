<?php

# "Ох уж эти перлисты... что ни пишут - всё Template Toolkit получается!"
# Компилятор переписан уже 2 раза - сначала на regexы, потом на index() :-)
# А обратная совместимость по синтаксису, как ни странно, до сих пор цела.

# Homepage: http://yourcmc.ru/wiki/VMX::Template
# Author: Vitaliy Filippov, 2006-2011

class TemplateState
{
    var $blocks = array();
    var $in = array();
    var $functions = array();
    var $output_position = 0;
    var $input_filename = '';
}

define('TS_UNIX',     0);
define('TS_DB',       1);
define('TS_DB_DATE',  2);
define('TS_MW',       3);
define('TS_EXIF',     4);
define('TS_ORACLE',   5);
define('TS_ISO_8601', 6);
define('TS_RFC822',   7);

class Template
{
    static $Mon, $mon, $Wday;
    static $cache_type = NULL;
    static $cache      = array();
    static $safe_tags  = '<div> <span> <a> <b> <i> <u> <p> <h1> <h2> <h3> <h4> <h5> <h6> <strike> <strong> <small> <big> <blink> <center> <ol> <pre> <sub> <sup> <font> <br> <table> <tr> <td> <th> <tbody> <tfoot> <thead> <tt> <ul> <li> <em> <img> <marquee>';

    var $errors        = array(); // содержит последние ошибки
    var $root          = '.';     // каталог с шаблонами
    var $reload        = 1;       // если 0, шаблоны не будут перечитываться с диска, и вызовов stat() происходить не будет
    var $wrapper       = false;   // фильтр, вызываемый перед выдачей результата parse
    var $tpldata       = array(); // сюда будут сохранены: данные
    var $cache_dir     = false;   // необязательный кэш, ускоряющий работу только в случае частых инициализаций интерпретатора
    var $use_utf8      = true;    // использовать кодировку UTF-8 для операций со строками
    var $begin_code    = '<!--';  // начало кода
    var $end_code      = '-->';   // конец кода
    var $eat_code_line = true;    // съедать "лишний" перевод строки, если в строке только инструкция?
    var $begin_subst   = '{';     // начало подстановки (необязательно)
    var $end_subst     = '}';     // конец подстановки (необязательно)
    var $strict_end    = false;   // жёстко требовать имя блока в его завершающей инструкции (<!-- end block -->)
    var $raise_error   = false;   // говорить die() при ошибках в шаблонах
    var $print_error   = false;   // печатать фатальные ошибки
    var $compiletime_functions = array();   // дополнительные функции времени компиляции
    var $parent        = NULL;    // сюда сохраняется объект, от которого отпочкован объект класса конкретного шаблона
                                  // компилятор всегда дёргается в рамках объекта Template, а не объекта конкретного шаблона

    var $failed        = array(); // сюда сохраняются имена файлов, загрузка которых не удалась,
                                  // чтобы не долбиться в один и тот же кривой шаблон много раз за запрос

    function __construct($args)
    {
        foreach ($args as $k => $v)
            $this->$k = $v;
        $this->cache_dir = preg_replace('!/*$!s', '/', $this->cache_dir);
        if (!is_writable($this->cache_dir))
            $this->error('Template: cache_dir='.$this->cache_dir.' is not writable', true);
        $this->root = preg_replace('!/*$!s', '/', $this->root);
    }

    // Сохранить ошибку
    function error($e, $fatal = false)
    {
        $this->errors[] = $e;
        if ($this->raise_error && $fatal)
            die(__CLASS__."::error: $e");
        elseif ($this->print_error)
            print __CLASS__."::error: $e<br />";
    }

    // Функция уничтожает данные шаблона
    function clear()
    {
        $this->tpldata = array();
        return true;
    }

    // Подлить в огонь переменных. Возвращает новый массив.
    function assign_vars($new = NULL, $value = NULL) { return $this->vars($new, $value); }
    function vars($new = NULL, $value = NULL)
    {
        if (is_array($new))
            $this->tpldata = array_merge($this->tpldata, $new);
        else if ($new && $value !== NULL)
            $this->tpldata[$new] = $value;
        return $this->tpldata;
    }

    // Кэш (xcache, eaccelerator)
    static function cache_check_type()
    {
        if (is_null(self::$cache_type))
        {
            if (function_exists('xcache_get'))
                self::$cache_type = 'x';
            else if (function_exists('eaccelerator_get'))
                self::$cache_type = 'e';
            else
                self::$cache_type = '';
        }
    }
    static function cache_get($key)
    {
        self::cache_check_type();
        if (!array_key_exists($key, self::$cache))
        {
            if (self::$cache_type == 'x')
                self::$cache[$key] = xcache_get($key);
            else if (self::$cache_type == 'e')
                self::$cache[$key] = eaccelerator_get($key);
        }
        return self::$cache[$key];
    }
    static function cache_del($key)
    {
        self::cache_check_type();
        unset(self::$cache[$key]);
        if (self::$cache_type == 'x')
            xcache_unset($key);
        else if (self::$cache_type == 'e')
            eaccelerator_rm($key);
    }
    static function cache_set($key, $value)
    {
        self::cache_check_type();
        self::$cache[$key] = $value;
        if (self::$cache_type == 'x')
            xcache_set($key, $value);
        else if (self::$cache_type == 'e')
            eaccelerator_put($key, $value);
    }

    // Функция загружает, компилирует и возвращает результат
    // обработки шаблона или функции шаблона.
    // $page = $obj->parse(
    //     'file/name.tpl' или NULL, 'template {CODE}'
    //     [, 'function']
    //     [, array(vars => $values) ]
    // );
    // NULL, 'код' - передача не имени файла, а кода.
    // Менее рекомендовано, но возможно.
    function parse($fn, $inline = NULL, $func = NULL, $vars = NULL)
    {
        if ($this->parent)
        {
            // вызван из шаблона
            // разрешаем синтаксис <!-- process '::function' -->
            if (substr($fn, 0, 2) == '::')
            {
                $vars = $inline;
                $inline = substr($fn, 2);
                $fn = self::$template_filename;
            }
            return $this->parent->parse($fn, $inline, $func, $vars);
        }
        $this->errors = array();
        if (!strlen($fn))
        {
            $text = $inline;
            $fn = '';
            if (!$text)
                return '';
            $class = 'Template_X'.md5($text);
            if (!($file = $this->compile($text, $fn)))
                return NULL;
            include $file;
        }
        else
        {
            $vars = $func;
            $func = $inline;
            if (!strlen($fn))
            {
                $this->error("empty filename '$fn'", true);
                return NULL;
            }
            if (substr($fn, 0, 1) != '/')
                $fn = $this->root.$fn;
            /* Пока что, если класс существует - просто используем его.
               Однако если внезапно потребуется перезагружать шаблоны
               в рамках ОДНОГО запроса - надо будет добавить stat()... FIXME?
               Зато можно не бояться многократно вызывать какой-нибудь блок. */
            $class = 'Template_'.md5($fn);
            if (!class_exists($class))
            {
                if ($this->failed[$fn])
                {
                    /* Если один раз за запрос загрузить не смогли,
                       то больше не пытаемся */
                    return NULL;
                }
                if (!($text = $this->loadfile($fn)))
                {
                    $this->error("couldn't load template file '$fn'", true);
                    $this->failed[$fn] = true;
                    return NULL;
                }
                if (!($file = $this->compile($text, $fn)))
                {
                    $this->failed[$fn] = true;
                    return NULL;
                }
                $r = include($file);
                if ($r !== 1)
                {
                    $this->error("error including compiled template for '$fn'", true);
                    $this->failed[$fn] = true;
                    return NULL;
                }
                if (!class_exists($class))
                {
                    /* кэш от старой версии, нужно сбросить
                       FIXME в будущем совместимость со старым кэшем будет убрана */
                    $this->error("Please, clear template cache path after upgrading VMX::Template", true);
                    $this->failed[$fn] = true;
                    return NULL;
                }
            }
        }
        if (!$func)
            $func = '_main';
        elseif (is_array($func))
            $vars = $func;
        $func = "__$func";
        $tpl = new $class($this);
        if ($vars)
            $tpl->tpldata = &$vars;
        $t = $tpl->$func();
        /* FIXME Кусочек legacy, но тоже пока оставлен */
        if ($this->wrapper)
        {
            $w = $this->wrapper;
            if (is_callable($w))
                $w(&$t);
        }
        return $t;
    }

    // Функция загружает файл с кэшированием
    // $textref = $obj->loadfile($file)
    function loadfile($fn)
    {
        $load = false;
        if (!($text = self::cache_get("U$fn")) || $this->reload)
        {
            $mtime = stat($fn);
            $mtime = $mtime[9];
            if (!$text)
                $load = true;
            else
            {
                $ctime = self::cache_get("T$fn");
                if ($ctime < $mtime)
                    $load = true;
            }
        }
        // если файл изменился - перезасасываем
        if ($load)
        {
            if ($fp = fopen($fn, "rb"))
            {
                fseek($fp, 0, SEEK_END);
                $t = ftell($fp);
                fseek($fp, 0, SEEK_SET);
                $text = fread($fp, $t);
                fclose($fp);
            }
            else
                return NULL;
            self::cache_set("T$fn", $mtime);
            self::cache_set("U$fn", $text);
        }
        return $text;
    }

    // Функция компилирует код.
    // $file = $this->compile($code, $fn);
    // require $file;
    // --> class Template_...
    function compile($code, $fn, $reload = false)
    {
        $md5 = md5($code);
        $file = $this->cache_dir . 'tpl' . $md5 . '.php';
        if (file_exists($file) && !$reload)
            return $file;

        // "имя" файла для кода не из файла
        if (!$fn)
        {
            $func_ns = 'X' . $md5;
            $c = debug_backtrace();
            $c = $c[2];
            $fn = '(inline template at '.$c['file'].':'.$c['line'].')';
        }
        else
            $func_ns = md5($fn);

        // начала/концы спецстрок
        $bc = $this->begin_code;
        if (!$bc)
            $bc = '<!--';
        $ec = $this->end_code;
        if (!$ec)
            $ec = '-->';

        // маркер начала, маркер конца, обработчик, съедать ли начало и конец строки
        $blk = array(array($bc, $ec, 'compile_code_fragment', $this->eat_code_line));
        if ($this->begin_subst && $this->end_subst)
            $blk[] = array($this->begin_subst, $this->end_subst, 'compile_substitution');
        foreach ($blk as &$v)
        {
            $v[4] = strlen($v[0]);
            $v[5] = strlen($v[1]);
        }

        $st = new TemplateState();
        $st->input_filename = $fn;

        // ищем фрагменты кода - на регэкспах-то было не очень правильно, да и медленно!
        $r = '';
        $pp = 0;
        while ($code)
        {
            $p = array();
            $b = NULL;
            // ищем ближайшее
            foreach ($blk as $i => $bi)
                if (($p[$i] = strpos($code, $bi[0], $pp)) !== false &&
                    (is_null($b) || $p[$i] < $p[$b]))
                    $b = $i;
            if (!is_null($b))
            {
                /* это означает, что в случае отсутствия корректной инструкции
                   в найденной позиции надо пропустить ТОЛЬКО её начало и попробовать
                   найти что-нибудь снова! */
                $pp = $p[$b]+$blk[$b][4];
                $e = strpos($code, $blk[$b][1], $pp);
                if ($e >= 0)
                {
                    $frag = substr($code, $p[$b]+$blk[$b][4], $e-$p[$b]-$blk[$b][4]);
                    $f = $blk[$b][2];
                    if (!preg_match('/^\s*\n/s', $frag))
                    {
                        /* Некоторые инструкции хотят видеть позицию в выходном потоке.
                           Например, FUNCTION и END. Поэтому преобразуем текст
                           до вызова обработчика. */
                        $x_pp = $pp - $blk[$b][4];
                        $l = 0;
                        if ($x_pp > 0)
                        {
                            $text = substr($code, 0, $x_pp);
                            $text = addcslashes($text, '\\\'');
                            // съедаем перевод строки, если надо
                            if ($blk[$b][5])
                                $text = preg_replace('/\r?\n\r?[ \t]*$/s', '', $text);
                            if ($l = strlen($text))
                                $l += 8;
                        }
                        // записываем позицию
                        $st->output_position = $l + strlen($r);
                        // вызываем обработчик
                        $frag = $this->$f($st, $frag);
                    }
                    else
                        $frag = NULL;
                    if (!is_null($frag))
                    {
                        // есть инструкция
                        $pp = $x_pp;
                        if ($pp > 0)
                        {
                            if (strlen($text))
                                $r .= "\$t.='$text';\n"; // длина как раз этого = $l+8
                            $code = substr($code, $pp);
                            $pp = 0;
                        }
                        $r .= $frag;
                        $code = substr($code, $e+$blk[$b][5]-$p[$b]);
                    }
                }
            }
            else
            {
                // финиш
                $code = addcslashes($code, '\\\'');
                $r .= "\$t.='$code';\n";
                $code = '';
            }
        }

        // перемещаем функции в конец кода
        $code = '';
        for ($i = count($st->functions)-1; $i >= 0; $i--)
        {
            $f = $st->functions[$i];
            $f = substr_replace($r, '', $f[0], $f[1]-$f[0]);
            $code .= $f;
        }

        // заворачиваем основной код в _main()
        $rfn = addcslashes($fn, '\\\'');
        $code = "<?php // $fn
class Template_$func_ns extends ".__CLASS__." {
static \$template_filename = '$rfn';
function __construct(\$t) {
\$this->tpldata = &\$t->tpldata;
\$this->parent = &\$t;
}
function ___main() {
\$stack = array();
\$t = '';
$r
return \$t;
}
$code
}
";
        $r = '';

        // записываем в файл
        $fp = fopen($file, 'wb');
        fwrite($fp, $code);
        fclose($fp);

        // возвращаем имя файла
        return $file;
    }

    // ELSE
    // ELSE IF expression
    function compile_code_fragment_else($st, $kw, $t)
    {
        if (preg_match('/^IF\s+(.*)$/is', $t, $m))
            return $this->compile_code_fragment_if($st, 'elsif', $m[1]);
        return $t ? NULL : "} else {";
    }

    // IF expression
    // ELSIF expression
    function compile_code_fragment_if($st, $kw, $t)
    {
        $e = $this->compile_expression($t);
        if ($e === NULL)
        {
            $this->error("Invalid expression in $kw: '$t'");
            return NULL;
        }
        $cf_if = array('elseif' => "} else", 'elsif' => "} else", 'if' => "");
        $kw = $cf_if[$kw];
        if (!$kw)
            $st->in[] = array('if');
        return $kw . "if ($e) {\n";
    }
    function compile_code_fragment_elsif($st, $kw, $t)
    {
        return $this->compile_code_fragment_if($st, $kw, $t);
    }
    function compile_code_fragment_elseif($st, $kw, $t)
    {
        return $this->compile_code_fragment_if($st, $kw, $t);
    }

    // END [block]
    function compile_code_fragment_end($st, $kw, $t)
    {
        if (!count($st->in))
        {
            $this->error("END $t without begin directive");
            return NULL;
        }
        $in = array_pop($st->in);
        $w = $in[0];
        if ($this->strict_end &&
            ($t && ($w != 'begin' || !$in[1] || $in[1] != $t) ||
            !$t && $w == 'begin' && $in[1]))
        {
            $st->in[] = $in;
            $this->error(strtoupper($kw)." $t after ".strtoupper($w)." ".$in[1]);
            return NULL;
        }
        if ($w == 'set')
        {
            return $this->varref($in[1]) . " = \$t;\n\$t = array_pop(\$stack);\n";
        }
        elseif ($w == 'function')
        {
            $s = "return \$t;\n}\n";
            foreach (array('blocks', 'in') as $k)
                $st->$k = $in[2][$k];
            $st->functions[count($st->functions)-1][] = $st->output_position+strlen($s);
            return $s;
        }
        elseif ($w == 'begin' || $w == 'for')
        {
            if ($w == 'begin')
                array_pop($st->blocks);
            $v = $this->varref($in[2]);
            $v_i = $this->varref($in[2].'#');
            return "}
array_pop(\$stack);
$v_i = array_pop(\$stack);
$v = array_pop(\$stack);
";
        }
        return "}\n";
    }

    // SET varref ... END
    // SET varref = expression
    function compile_code_fragment_set($st, $kw, $t)
    {
        if (!preg_match('/^((?:\w+\.)*\w+)(\s*=\s*(.*))?/is', $t, $m))
            return NULL;
        if (strlen($m[3]))
        {
            $e = $this->compile_expression($m[3]);
            if ($e === NULL)
            {
                $this->error("Invalid expression in $kw: ($m[3])");
                return NULL;
            }
            return $this->varref($m[1]) . ' = ' . $e . ";\n";
        }
        $st->in[] = array($kw, $m[1]);
        return "\$stack[] = \$t;\n\$t = '';\n";
    }

    // FUNCTION|BLOCK|MACRO name ... END
    // FUNCTION|BLOCK|MACRO name = expression
    function compile_code_fragment_function($st, $kw, $t)
    {
        if (!preg_match('/^([^=]*)(=\s*(.*))?/is', $t, $m))
            return NULL;
        if (!preg_match('/^[^\W\d]\w*$/', $m[1]) || $m[1] == '_main')
        {
            $this->error("Template function names:
* must start with a letter
* must consist of alphanumeric characters
* must not be equal to '_main'
I see 'FUNCTION $m[1]' instead.");
            return NULL;
        }
        if ($st->functions && count($st->functions[count($st->functions)-1]) == 1)
        {
            $this->error("Template functions cannot be nested");
            return NULL;
        }
        /* при первом обращении к шаблону все его функции,
           включая "основную" _main, становятся членами класса шаблона.
           при последующих они просто вызываются без дополнительных затрат.
           слишком много функций в классе не появится, т.к. PHP всё равно
           сбрасывается при каждом запросе. */
        $s = "function __$m[1] () {\n";
        if (strlen($m[3]))
        {
            $e = $this->compile_expression($m[3]);
            if ($e === NULL)
            {
                $this->error("Invalid expression in $kw: ($m[3])");
                return NULL;
            }
            $s .= "return $e;\n}\n";
            $st->functions[] = array(
                $st->output_position,
                $st->output_position+strlen($s)
            );
            return $s;
        }
        /* блоки сохраняются и сбрасываются */
        $st->in = array(array('function', $m[1], array('in' => $st->in, 'blocks' => $st->blocks)));
        $st->blocks = array();
        /* запоминаем положение в выходном потоке
           для последующего разбиения его на функции */
        $st->functions[] = array($st->output_position);
        return $s . "\$stack = array();\n\$t = '';\n";
    }
    function compile_code_fragment_block($st, $kw, $t)
    {
        return $this->compile_code_fragment_function($st, $kw, $t);
    }
    function compile_code_fragment_macro($st, $kw, $t)
    {
        return $this->compile_code_fragment_function($st, $kw, $t);
    }

    // INCLUDE template.tpl
    // legacy, в новом варианте можно использовать с кавычками, и это уже идёт как функция
    function compile_code_fragment_include($st, $kw, $t)
    {
        $t = preg_replace('/^[a-z0-9_\.]+$/', '\'\0\'', $t);
        if (!is_null($t = $this->compile_expression("include $t")))
            return "\$t.=$t;\n";
        return NULL;
    }

    static function array1($a)
    {
        if (is_null($a))
            return array();
        if (is_array($a) && !self::is_assoc($a))
            return $a;
        return array($a);
    }

    // FOR[EACH] varref = array
    // или
    // FOR[EACH] varref (тогда записывается в себя)
    function compile_code_fragment_for($st, $kw, $t, $in = false)
    {
        if (preg_match('/^((?:\w+\.)*\w+)(\s*=\s*(.*))?/s', $t, $m))
        {
            if (!$in)
                $st->in[] = array('for', $t, $m[1]);
            $v = $this->varref($m[1]);
            $v_i = $this->varref($m[1].'#');
            if (substr($v_i,-1) == substr($v,-1))
            {
                $iset = "$v_i = \$stack[count(\$stack)-1]++;\n";
            }
            else
            {
                // небольшой хак для $1 =~ \.\d+$
                $iset = '';
            }
            $t = $m[3] ? $this->compile_expression($m[3]) : $v;
            return
"\$stack[] = $v;
\$stack[] = $v_i;
\$stack[] = 0;
foreach (self::array1($t) as \$item) {
$v = \$item;
$iset";
        }
        return NULL;
    }

    function compile_code_fragment_foreach($st, $kw, $t)
    {
        return $this->compile_code_fragment_for($st, $kw, $t);
    }

    // BEGIN block [AT e] [BY e] [TO e]
    // тоже legacy, но пока оставлю...
    function compile_code_fragment_begin($st, $kw, $t)
    {
        if (preg_match('/^([a-z_][a-z0-9_]*)(?:\s+AT\s+(.+))?(?:\s+BY\s+(.+))?(?:\s+TO\s+(.+))?\s*$/is', $t, $m))
        {
            $st->blocks[] = $m[1];
            $t = implode('.', $st->blocks);
            $st->in[] = array('begin', $m[1], $t);
            $e = $t;
            if ($m[2])
            {
                $e = "array_slice($e, $m[2]";
                if ($m[4])
                    $e .= ", $m[4]";
                $e .= ")";
            }
            if ($m[3])
            {
                $e = "self::exec_subarray_divmod($e, $m[3])";
            }
            if ($e != $t)
            {
                $e = "$t = $e";
            }
            return $this->compile_code_fragment_for($st, 'for', $e, 1);
        }
        return NULL;
    }

    // компиляция фрагмента кода <!-- ... -->. это может быть:
    // 1) [ELSE] IF выражение
    // 2) BEGIN/FOR/FOREACH имя блока
    // 3) END [имя блока]
    // 4) SET переменная
    // 5) SET переменная = выражение
    // 6) INCLUDE имя_файла_шаблона
    // 7) выражение
    function compile_code_fragment($st, $e)
    {
        $e = ltrim($e, " \t\r");
        $e = rtrim($e);
        if (substr($e, 0, 1) == '#')
        {
            // комментарий!
            return '';
        }
        if (preg_match('/^(?:(ELS)(?:E\s*)?)?IF!\s+(.*)$/s', $e, $m))
        {
            $e = $m[1].'IF NOT '.$m[2];
            // обратная совместимость... нафига она нужна?...
            // но пока пусть останется...
            $this->error("Legacy IF! used, consider changing it to IF NOT");
        }
        list($kw, $t) = preg_split('/\s+/', $e, 2);
        $kw = strtolower($kw);
        if (!preg_match('/\W/s', $kw) &&
            method_exists($this, $sub = "compile_code_fragment_$kw") &&
            !is_null($r = $this->$sub($st, $kw, $t)))
            return $r;
        elseif (!is_null($t = $this->compile_expression($e)))
        {
            // если заданы маркеры подстановок (по умолчанию { ... }),
            // то выражения, вычисляемые в директивах (по умолчанию <!-- ... -->),
            // не подставляются в результат
            if ($this->begin_subst && $this->end_subst &&
                !preg_match('/^(include|process|parse)/is', $e))
                return "$t;\n";
            return "\$t.=$t;\n";
        }
        return NULL;
    }

    // компиляция подстановки переменной {...} это просто выражение
    function compile_substitution($st, $e)
    {
        $e = $this->compile_expression($e);
        if ($e !== NULL)
            return "\$t.=$e;\n";
        return NULL;
    }

    // компиляция выражения. это может быть:
    // 1) "строковой литерал"
    // 2) 123.123 или 0123 или 0x123
    // 3) переменная
    // 4) функция(выражение,выражение,...,выражение)
    // 5) функция выражение
    // 6) для legacy mode: переменная/имя_функции
    function compile_expression($e, $after = NULL)
    {
        if ($after && (!is_array($after) || !count($after)))
            $after = NULL;
        $e = ltrim($e, " \t\r");
        if ($after)
            $after[0] = '';
        else
            $e = rtrim($e);
        // строковой или числовой литерал
        if (preg_match('/^((\")(?:[^\"\\\\]+|\\\\.)*\"|\'(?:[^\'\\\\]+|\\\\.)*\'|-?0\d+|-?[0-9]\d*(\.\d+)?|-?0x\d+)\s*(.*)$/is', $e, $m))
        {
            if ($m[4])
            {
                if (!$after)
                    return NULL;
                $after[0] = $m[4];
            }
            $e = $m[1];
            if ($m[2])
                $e = str_replace('$', '\\$', $e);
            return $e;
        }
        // функция нескольких аргументов или вызов метода объекта
        elseif (preg_match('/^([a-z_][a-z0-9_]*((?:\.[a-z0-9_]+)*))\s*\((.*)$/is', $e, $m))
        {
            /* вызов методов по цепочке типа obj.method().other_method()
               не поддерживаем, потому что к таким цепочкам без сохранения звеньев
               нервно относится сам PHP */
            $f = strtolower($m[1]);
            $ct_callable = array($this, "function_$f");
            if ($m[2])
            {
                /* вызов метода объекта obj.method() */
                $p = strrpos($m[1], '.');
                $method = substr(substr_replace($m[1], '', $p+1), 1);
                if (preg_match('/^[^a-z_]/is', $method))
                {
                    $this->error("Object method name cannot start with a number: '$method' of '$m[1]'");
                    return NULL;
                }
                $varref = $this->varref($m[1]).'->'.$method;
            }
            elseif ($this->compiletime_functions[$f])
                $ct_callable = $this->compiletime_functions[$f];
            /* разбираем аргументы */
            $a = $m[3];
            $args = array();
            while (!is_null($e = $this->compile_expression($a, array(&$a))))
            {
                $args[] = $e;
                if (preg_match('/^\s*\)/s', $a))
                    break;
                else if ($a == ($b = preg_replace('/^\s*,/s', '', $a)))
                {
                    $this->error("Unexpected token: '$a' in $f($m[2] parameter list");
                    return NULL;
                }
                $a = $b;
            }
            if ($a == ($b = preg_replace('/^\s*\)\s*/', '', $a)))
            {
                $this->error("Unexpected token: '$a' in the end of $f($m[2] parameter list");
                return NULL;
            }
            $a = $b;
            /* записываем остатки в $after */
            if ($a)
            {
                if (!$after)
                    return NULL;
                $after[0] = $a;
            }
            /* вызов метода объекта или компиляция вызова функции */
            if ($varref)
                return "$varref(".implode(",", $args).")";
            return call_user_func_array($ct_callable, $args);
        }
        // функция одного аргумента
        elseif (preg_match('/^([a-z_][a-z0-9_]*)\s+(?=\S)(.*)$/is', $e, $m))
        {
            $f = strtolower($m[1]);
            if (!method_exists($this, "function_$f"))
            {
                $this->error("Unknown function: '$f' in '$e'");
                return NULL;
            }
            $a = $m[2];
            $arg = $this->compile_expression($a, array(&$a));
            if ($arg === NULL)
            {
                $this->error("Invalid expression: ($e)");
                return NULL;
            }
            $a = ltrim($a);
            if ($a)
            {
                if (!$after)
                    return NULL;
                $after[0] = $a;
            }
            $f = "function_$f";
            return $this->$f($arg);
        }
        // переменная плюс legacy-mode переменная/функция
        elseif (preg_match('/^((?:[a-z0-9_]+\.)*(?:[a-z0-9_]+\#?))(?:\/([a-z]+))?\s*(.*)$/is', $e, $m))
        {
            if ($m[3])
            {
                if (!$after)
                    return NULL;
                $after[0] = $m[3];
            }
            $e = $this->varref($m[1]);
            if ($m[2])
            {
                $f = strtolower($m[2]);
                if (!method_exists($this, "function_$f"))
                {
                    $this->error("Unknown function: '$f' called in legacy mode ($m[0])");
                    return NULL;
                }
                $f = "function_$f";
                $e = $this->$f($e);
            }
            return $e;
        }
        return NULL;
    }

    // генерация ссылки на переменную
    function varref($e)
    {
        if (!$e)
            return "";
        $e = explode('.', $e);
        $t = '$this->tpldata';
        foreach ($e as $el)
        {
            if (preg_match('/^\d+$/', $el))
            {
                $t .= "[$el]";
            }
            else
            {
                $el = addcslashes($el, '\\\'');
                $t .= "['$el']";
            }
        }
        return $t;
    }

    // операция над аргументами
    static function fmop($op, $args)
    {
        return "((" . join(") $op (", $args) . "))";
    }

    static function is_assoc($a)
    {
        foreach (array_keys($a) as $k)
            if (!is_int($k))
                return true;
        return false;
    }

    // вспомогательная функция - вызов функции с раскрытием аргументов
    static function call_array_func()
    {
        $args = func_get_args();
        $cb = array_shift($args);
        $aa = array();
        foreach ($args as $a)
        {
            if (is_array($a) && !self::is_assoc($a))
                foreach ($a as $v)
                    $aa[] = $v;
            else
                $aa[] = $a;
        }
        return call_user_func_array($cb, $args);
    }

    static function array_count($a)
    {
        if (is_array($a))
            return count($a);
        return 0;
    }

    // вызов функции с аргументами и раскрытием массивов
    static function fearr($f, $args)
    {
        $e = "self::call_array_func($f";
        foreach ($args as $a)
            $e .= ", $a";
        $e .= ")";
        return $e;
    }

    // перлоподобный OR-оператор, который возвращает первое истинное значение
    static function perlish_or()
    {
        $a = func_get_args();
        foreach ($a as $v)
            if ($v)
                return $v;
        return false;
    }

    // вызов своей функции
    function exec_call($f, $sub, $args)
    {
        if (is_callable($sub))
            return call_user_func_array($sub, $args);
        $this->error("Unknown function: '$f'");
        return NULL;
    }

    /*** Функции ***/

    /** Числа, логические операции **/

    /* логические операции */
    function function_or()       { $a = func_get_args(); return "self::perlish_or(".join(",", $a).")"; }
    function function_and()      { $a = func_get_args(); return $this->fmop('&&', $a); }
    function function_not($e)    { return "!($e)"; }

    /* арифметические операции */
    function function_add()      { $a = func_get_args(); return $this->fmop('+', $a); }
    function function_sub()      { $a = func_get_args(); return $this->fmop('-', $a); }
    function function_mul()      { $a = func_get_args(); return $this->fmop('*', $a); }
    function function_div()      { $a = func_get_args(); return $this->fmop('/', $a); }
    function function_mod($a,$b) { return "(($a) % ($b))"; }

    /* логарифм */
    function function_log($e)    { return "log($e)"; }

    /* чётный, нечётный */
    function function_even($e)   { return "!(($e) & 1)"; }
    function function_odd($e)    { return "(($e) & 1)"; }

    /* приведение к целому числу */
    function function_int($e)    { return "intval($e)"; }
    function function_i($e)      { return "intval($e)"; }
    function function_intval($e) { return "intval($e)"; }

    /* сравнения: == != > < >= <= (аргументов как строк если оба строки, иначе как чисел) */
    function function_eq($a,$b) { return "(($a) == ($b))"; }
    function function_ne($a,$b) { return "(($a) != ($b))"; }
    function function_gt($a,$b) { return "(($a) > ($b))"; }
    function function_lt($a,$b) { return "(($a) < ($b))"; }
    function function_ge($a,$b) { return "(($a) >= ($b))"; }
    function function_le($a,$b) { return "(($a) <= ($b))"; }

    /* сравнения: == != > < >= <= (аргументов как строк) */
    function function_seq($a,$b) { return "((\"$a\") == (\"$b\"))"; }
    function function_sne($a,$b) { return "((\"$a\") != (\"$b\"))"; }
    function function_sgt($a,$b) { return "((\"$a\") >  (\"$b\"))"; }
    function function_slt($a,$b) { return "((\"$a\") <  (\"$b\"))"; }
    function function_sge($a,$b) { return "((\"$a\") >= (\"$b\"))"; }
    function function_sle($a,$b) { return "((\"$a\") <= (\"$b\"))"; }

    /* сравнения: == != > < >= <= (аргументов как чисел) */
    function function_neq($a,$b) { return "((0+$a) == ($b))"; }
    function function_nne($a,$b) { return "((0+$a) != ($b))"; }
    function function_ngt($a,$b) { return "((0+$a) > ($b))"; }
    function function_nlt($a,$b) { return "((0+$a) < ($b))"; }
    function function_nge($a,$b) { return "((0+$a) >= ($b))"; }
    function function_nle($a,$b) { return "((0+$a) <= ($b))"; }

    /* тернарный оператор $1 ? $2 : $3 */
    function function_yesno($a,$b,$c) { return "(($a) ? ($b) : ($c))"; }

    /** Строки **/

    /* нижний регистр */
    function function_lc($e)         { return ($this->use_utf8 ? "mb_" : "") . "strtolower($e)"; }
    function function_lower($e)      { return ($this->use_utf8 ? "mb_" : "") . "strtolower($e)"; }
    function function_lowercase($e)  { return ($this->use_utf8 ? "mb_" : "") . "strtolower($e)"; }

    /* верхний регистр */
    function function_uc($e)         { return ($this->use_utf8 ? "mb_" : "") . "strtoupper($e)"; }
    function function_upper($e)      { return ($this->use_utf8 ? "mb_" : "") . "strtoupper($e)"; }
    function function_uppercase($e)  { return ($this->use_utf8 ? "mb_" : "") . "strtoupper($e)"; }

    /* нижний регистр первого символа */
    function function_lcfirst($e)    { return ($this->use_utf8 ? "self::mb_" : "") . "lcfirst($e)"; }

    /* верхний регистр первого символа */
    function function_ucfirst($e)    { return ($this->use_utf8 ? "self::mb_" : "") . "ucfirst($e)"; }

    /* экранирование кавычек */
    function function_quote($e)      { return "str_replace(array(\"\\n\",\"\\r\"),array(\"\\\\n\",\"\\\\r\"),addslashes($e))"; }
    function function_addslashes($e) { return "str_replace(array(\"\\n\",\"\\r\"),array(\"\\\\n\",\"\\\\r\"),addslashes($e))"; }
    function function_q($e)          { return "str_replace(array(\"\\n\",\"\\r\"),array(\"\\\\n\",\"\\\\r\"),addslashes($e))"; }

    /* экранирование кавычек в SQL- или CSV- стиле (кавычка " превращается в двойную кавычку "") */
    function function_sq($e)         { return "str_replace('\"','\"\"',$e)"; }
    function function_sql_quote($e)  { return "str_replace('\"','\"\"',$e)"; }

    /* экранирование символов, специальных для регулярного выражения */
    function function_requote($e)    { return "preg_quote($e)"; }
    function function_re_quote($e)   { return "preg_quote($e)"; }
    function function_preg_quote($e) { return "preg_quote($e)"; }

    /* экранирование в стиле URL */
    function function_uriquote($e)   { return "urlencode($e)"; }
    function function_uri_escape($e) { return "urlencode($e)"; }
    function function_urlencode($e)  { return "urlencode($e)"; }

    /* замены - по регулярке и по подстроке */
    function function_replace($re, $sub, $v)
    {
        return "preg_replace('#'.str_replace('#','\\\\#',$re).'#s', $sub, $v)";
    }
    function function_str_replace($s, $sub, $v)
    {
        return "str_replace($s, $sub, $v)";
    }

    /* длина строки */
    function function_strlen($s) { return ($this->use_utf8 ? "mb_" : "") . "strlen($s)"; }

    /* подстрока */
    function function_substr($s, $start, $length = NULL)
    {
        return ($this->use_utf8 ? "mb_" : "") . "substr($s, $start" . ($length !== NULL ? ", $length" : "") . ")";
    }
    function function_substring($s, $start, $length = NULL)
    {
        return ($this->use_utf8 ? "mb_" : "") . "substr($s, $start" . ($length !== NULL ? ", $length" : "") . ")";
    }

    /* убиение пробелов в начале и конце */
    function function_trim($s) { return "trim($s)"; }

    /* разбиение строки по регулярному выражению */
    function function_split($re, $v, $limit = -1)
    {
        return "preg_split('#'.str_replace('#','\\\\#',$re).'#s', $v, $limit)";
    }

    /* преобразование символов <>&'" в HTML-сущности &lt; &gt; &amp; &apos; &quot; */
    function function_htmlspecialchars($e)      { return "htmlspecialchars($e,ENT_QUOTES)"; }
    function function_html($e)                  { return "htmlspecialchars($e,ENT_QUOTES)"; }
    function function_s($e)                     { return "htmlspecialchars($e,ENT_QUOTES)"; }

    /* удаление всех или заданных тегов */
    function function_strip($e, $t='')          { return "strip_tags($e".($t?",$t":"").")"; }
    function function_strip_tags($e, $t='')     { return "strip_tags($e".($t?",$t":"").")"; }
    function function_t($e, $t='')              { return "strip_tags($e".($t?",$t":"").")"; }

    /* удаление "небезопасных" HTML-тегов */
    function function_strip_unsafe($e)          { return "strip_tags($e, self::\$safe_tags)"; }
    function function_h($e)                     { return "strip_tags($e, self::\$safe_tags)"; }

    /* заменить \n на <br /> */
    function function_nl2br($s)                 { return "nl2br($s)"; }

    /* конкатенация строк */
    function function_concat()   { $a = func_get_args(); return $this->fmop('.', $a); }

    /* объединение всех скаляров и всех элементов аргументов-массивов */
    function function_join()    { $a = func_get_args(); return self::fearr("'join'", $a); }
    function function_implode() { $a = func_get_args(); return self::fearr("'join'", $a); }

    /* подставляет на места $1, $2 и т.п. в строке аргументы */
    function function_subst()   { $a = func_get_args(); return self::fearr("'VMX_Template::exec_subst'", $a); }

    /* sprintf */
    function function_sprintf() { $a = func_get_args(); return self::fearr("'sprintf'", $a); }

    /* strftime */
    function function_strftime($fmt, $date, $time = '')
    {
        $e = $time ? "($date).' '.($time)" : $date;
        return "strftime($fmt, self::timestamp($e))";
    }

    /* ограничение длины строки $maxlen символами на границе пробелов и добавление '...', если что. */
    /* strlimit(string, length, dots = '...') */
    function function_strlimit($a)
    {
        $a = func_get_args();
        return "self::" . ($this->use_utf8 ? "mb_" : "") . "strlimit(".join(",", $a).")";
    }
    function function_truncate($a)
    {
        $a = func_get_args();
        return "self::" . ($this->use_utf8 ? "mb_" : "") . "strlimit(".join(",", $a).")";
    }

    /** Массивы и хеши **/

    /* создание хеша */
    function function_hash()
    {
        $s = "array(";
        $i = 0;
        $d = '';
        foreach (func_get_args() as $v)
        {
            $s .= $d;
            $s .= $v;
            $i++;
            if ($i & 1)
                $d = '=>';
            else
                $d = ',';
        }
        $s .= ")";
        return $s;
    }

    /* ключи хеша или массива */
    function function_keys($a) { return "array_keys(is_array($a) ? $a : array())"; }
    function function_hash_keys($a) { return "array_keys(is_array($a) ? $a : array())"; }
    function function_array_keys($a) { return "array_keys(is_array($a) ? $a : array())"; }

    /* сортировка массива */
    function function_sort()    { $a = func_get_args(); return self::fearr("'VMX_Template::exec_sort'", $a); }

    /* пары id => ключ, name => значение для ассоциативного массива */
    function function_each($a) { return "array_id_name(is_array($a) ? $a : array())"; }

    /* создание массива */
    function function_array()
    {
        $a = func_get_args();
        return "array(" . join(",", $a) . ")";
    }

    /* диапазон от $1 до $2 */
    function function_range($a, $b)     { return "range($a,$b)"; }

    /* проверка, массив это или нет? */
    function function_is_array($a)      { return "is_array($a)"; }

    /* число элементов в массиве */
    function function_count($e)         { return "self::array_count($e)"; }

    /* подмассив по номерам элементов */
    function function_subarray()        { $a = func_get_args(); return "array_slice(" . join(",", $a) . ")"; }
    function function_array_slice()     { $a = func_get_args(); return "array_slice(" . join(",", $a) . ")"; }

    /* подмассив по кратности номеров элементов */
    function function_subarray_divmod() { $a = func_get_args(); return "self::exec_subarray_divmod(" . join(",", $a) . ")"; }

    /* 0) получить "корневую" переменную по неконстантному ключу
       1) получить элемент хеша/массива по неконстантному ключу (например get(iteration.array, rand(5)))
          по-моему, это лучше, чем Template Toolkit'овский ад - hash.key.${another.hash.key}.зюка.хрюка и т.п.
       2) получить элемент выражения-массива - ибо в PHP не работает (...expression...)['key'],
          к примеру не работает range(1,10)[0]
          но у нас-то можно написать get(range(1,10), 0), поэтому мы должны это поддерживать
          хотя это и не будет lvalue */
    function function_get($a, $k=NULL)
    {
        if ($k === NULL)
            return "\$this->tpldata[$a]";
        /* проверяем синтаксис выражения */
        if (@eval('return true; '.$a.'[0];'))
            return $a."[$k]";
        return "self::exec_get($a, $k)";
    }
    function function_hget($a, $k=NULL) { return $this->function_get($a, $k); }
    function function_aget($a, $k=NULL) { return $this->function_get($a, $k); }

    /* присваивание (только lvalue) */
    function function_set($l, $r)       { return "($l = $r)"; }

    /* объединение массивов */
    function function_array_merge()     { $a = func_get_args(); return "array_merge(" . join(",", $a) . ")"; }

    /* shift, unshift, pop, push */
    function function_shift($a)         { return "array_shift($a)"; }
    function function_pop($a)           { return "array_pop($a)"; }
    function function_unshift($a, $v)   { return "array_unshift($a, $v)"; }
    function function_push($a, $v)      { return "array_push($a, $v)"; }

    /** Прочее **/

    /* игнорирование результата (а-ля js) */
    function function_void($a)          { return "self::void($a)"; }
    function void($a)                   { return ''; }

    /* дамп переменной */
    function function_var_dump($var)
    {
        return "self::exec_dump($var)";
    }
    function function_dump($var)
    {
        return "self::exec_dump($var)";
    }

    /* JSON-кодирование */
    function function_json($v)  { return "json_encode($v)"; }

    /* включение другого файла или блока:
       process('файл')
       process('файл', 'функция')
       process('файл', 'функция', hash(аргументы))
       process('::функция', hash(аргументы))
       не рекомендуется, но возможно:
       process('', 'код', hash(аргументы))
       process('', 'код', 'функция', hash(аргументы))
    */
    function function_include() { $a = func_get_args(); return "\$this->parse(" . join(",", $a) . ")"; }
    function function_parse()   { $a = func_get_args(); return "\$this->parse(" . join(",", $a) . ")"; }
    function function_process() { $a = func_get_args(); return "\$this->parse(" . join(",", $a) . ")"; }

    /* вызов функции объекта по вычисляемому имени */
    function function_call()
    {
        $a = func_get_args();
        $o = array_shift($a);
        $m = array_shift($a);
        array_unshift($a, "array($o, $m)");
        return "call_user_func_array(".implode(", ", $a).")";
    }

    /* map() */
    function function_map($f)
    {
        if (!method_exists($this, "function_$f"))
        {
            $this->error("Unknown function specified for map(): $f");
            return NULL;
        }
        $f = "function_$f";
        $f = $this->$f('$arg');
        $args = func_get_args();
        array_shift($args);
        array_unshift($args, "create_function('$arg',$f)");
        return self::fearr("array_map", $args);
    }

    /*** Реализации функций ***/

    // дамп переменной
    static function exec_dump($var)
    {
        ob_start();
        var_dump($var);
        $var = ob_get_contents();
        ob_end_clean();
        return $var;
    }

    // подмассив по кратности номеров элементов
    // exec_subarray_divmod([], 2)
    // exec_subarray_divmod([], 2, 1)
    static function exec_subarray_divmod($array, $div, $mod)
    {
        if (!$div || !is_array($array))
            return $array;
        if (!$mod)
            $mod = 0;
        $i = 0;
        $r = array();
        foreach ($array as $k => $v)
            if (($i % $div) == $mod)
                $r[$k] = $v;
        return $r;
    }

    // выполняет подстановку function_subst
    static function exec_subst($str)
    {
        $args = func_get_args();
        $str = preg_replace_callback('/(?<!\\\\)((?:\\\\\\\\)*)\$(?:([1-9]\d*)|\{([1-9]\d*)\})/is', create_function('$m', 'return $args[$m[2]?$m[2]:$m[3]];'), $str);
        return $str;
    }

    // выполняет сортировку и возвращает сортированный массив
    static function exec_sort($array)
    {
        sort($array);
        return $array;
    }

    // возвращает элемент массива
    static function exec_get($array, $key)
    {
        return $array[$key];
    }

    // ограничение длины строки $maxlen символами на границе пробелов и добавление '...', если что.
    static function strlimit($str, $maxlen, $dots = '...')
    {
        if (!$maxlen || $maxlen < 1 || strlen($str) <= $maxlen)
            return $str;
        $str = substr($str, 0, $maxlen);
        $p = strrpos($str, ' ');
        if (!$p || ($pt = strrpos($str, "\t")) > $p)
            $p = $pt;
        if ($p)
            $str = substr($str, 0, $p);
        return $str . $dots;
    }

    // то же, но в UTF-8 (точнее, в текущей mb_internal_encoding())
    static function mb_strlimit($str, $maxlen, $dots = '...')
    {
        if (!$maxlen || $maxlen < 1 || mb_strlen($str) <= $maxlen)
            return $str;
        $str = mb_substr($str, 0, $maxlen);
        $p = mb_strrpos($str, ' ');
        if (!$p || ($pt = mb_strrpos($str, "\t")) > $p)
            $p = $pt;
        if ($p)
            $str = mb_substr($str, 0, $p);
        return $str . $dots;
    }

    // lcfirst() и ucfirst() для UTF-8
    static function mb_lcfirst($str)
    {
        return mb_strtolower(mb_substr($str, 0, 1)) . mb_substr($str, 0, 1);
    }

    // lcfirst() и ucfirst() для UTF-8
    static function mb_ucfirst($str)
    {
        return mb_strtoupper(mb_substr($str, 0, 1)) . mb_substr($str, 0, 1);
    }

    // ограниченная распознавалка дат
    static function timestamp($ts = 0, $format = 0)
    {
        if (!self::$Mon)
        {
            self::$Mon = split(' ', 'Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec');
            self::$mon = array_reverse(split(' ', 'jan feb mar apr may jun jul aug sep oct nov dec'));
            self::$Wday = split(' ', 'Sun Mon Tue Wed Thu Fri Sat');
        }
        if (!strcmp(intval($ts), $ts))
        {
            // TS_UNIX or Epoch
            if (!$ts)
                $ts = time;
        }
        elseif (preg_match('/^\D*(\d{4,})\D*(\d{2})\D*(\d{2})\D*(?:(\d{2})\D*(\d{2})\D*(\d{2})\D*([\+\- ]\d{2}\D*)?)?$/s', $ts, $m))
        {
            // TS_DB, TS_DB_DATE, TS_MW, TS_EXIF, TS_ISO_8601
            $ts = mktime(0+$m[4], 0+$m[5], 0+$m[6], $m[2], $m[3], $m[1]);
        }
        elseif (preg_match('/^\s*(\d\d?)-(...)-(\d\d(?:\d\d)?)\s*(\d\d)\.(\d\d)\.(\d\d)/s', $ts, $m))
        {
            // TS_ORACLE
            $ts = mktime($m[4], $m[5], $m[6], $mon[strtolower($m[2])]+1, intval($m[1]), $m[3] < 100 ? $m[3]+1900 : $m[3]);
        }
        elseif (preg_match('/^\s*..., (\d\d?) (...) (\d{4,}) (\d\d):(\d\d):(\d\d)\s*([\+\- ]\d\d)\s*$/s', $ts, $m))
        {
            // TS_RFC822
            $ts = mktime($m[4], $m[5], $m[6], $mon[strtolower($m[2])]+1, intval($m[1]), $m[3]);
        }
        else
        {
            // Bogus value, return NULL
            return NULL;
        }

        if (!$format)
        {
            // TS_UNIX
            return $ts;
        }
        elseif ($format == TS_MW)
        {
            return strftime("%Y%m%d%H%M%S", $ts);
        }
        elseif ($format == TS_DB)
        {
            return strftime("%Y-%m-%d %H:%M:%S", $ts);
        }
        elseif ($format == TS_DB_DATE)
        {
            return strftime("%Y-%m-%d", $ts);
        }
        elseif ($format == TS_ISO_8601)
        {
            return strftime("%Y-%m-%dT%H:%M:%SZ", $ts);
        }
        elseif ($format == TS_EXIF)
        {
            return strftime("%Y:%m:%d %H:%M:%S", $ts);
        }
        elseif ($format == TS_RFC822)
        {
            $l = localtime($ts);
            return strftime($Wday[$l[6]].", %d ".$Mon[$l[4]]." %Y %H:%M:%S %z", $ts);
        }
        elseif ($format == TS_ORACLE)
        {
            $l = localtime($ts);
            return strftime("%d-".$Mon[$l[4]]."-%Y %H.%M.%S %p", $ts);
        }
        return $ts;
    }
}
