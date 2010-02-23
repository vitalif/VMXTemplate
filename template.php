<?php

# "Ох уж эти перлисты... что ни пишут - всё Template Toolkit получается!"
# Компилятор переписан уже 2 раза - сначала на regexы, потом на index() :-)
# А обратная совместимость по синтаксису, как ни странно, до сих пор цела.

class TemplateState
{
    var $blocks = array();
    var $in = array();
    var $included = array();
    var $in_set = 0;
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
    var $use_utf8      = true;    // шаблоны в UTF-8 и с флагом UTF-8
    var $begin_code    = '<!--';  // начало кода
    var $end_code      = '-->';   // конец кода
    var $eat_code_line = true;    // съедать "лишний" перевод строки, если в строке только инструкция?
    var $begin_subst   = '{';     // начало подстановки (необязательно)
    var $end_subst     = '}';     // конец подстановки (необязательно)
    var $strict_end    = false;   // жёстко требовать имя блока в его завершающей инструкции (<!-- end block -->)
    var $raise_error   = false;   // говорить die() при ошибках в шаблонах
    var $print_error   = false;   // печатать фатальные ошибки

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
            print __CLASS__."::error: $e\n";
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

    // Функция загружает, компилирует и возвращает результат для хэндла
    // $page = $obj->parse( 'file/name.tpl' );
    // $page = $obj->parse( 'template {CODE}', true );
    function parse($fn, $inline = false)
    {
        $this->errors = array();
        if ($inline)
        {
            $text = $fn;
            $fn = '';
            if (!$text)
                return '';
        }
        else
        {
            if (!strlen($fn))
            {
                $this->error("Template: empty filename '$fn'", true);
                return NULL;
            }
            if (substr($fn, 0, 1) != '/')
                $fn = $this->root.$fn;
            if (!($text = $this->loadfile($fn)))
            {
                $this->error("Template: couldn't load template file '$fn'", true);
                return NULL;
            }
        }
        if (!($file = $this->compile($text, $fn)))
            return NULL;
        $stack = array();
        include $file;
        $w = $this->wrapper;
        if (is_callable($w))
            $w(&$t);
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
    // print $t;
    function compile($code, $fn)
    {
        $md5 = md5($code);
        $file = $this->cache_dir . 'tpl' . $md5 . '.php';
        if (file_exists($file))
            return $file;

        // начала/концы спецстрок
        $bc = $this->begin_code;
        if (!$bc)
            $bc = '<!--';
        $ec = $this->end_code;
        if (!$ec)
            $ec = '-->';

        // маркер начала, маркер конца, обработчик, съедать ли начало и конец строки
        $blk = array(array($bc, $ec, 'compile_code_fragment', $this->{eat_code_line}));
        if ($this->begin_subst && $this->end_subst)
            $blk[] = array($this->{begin_subst}, $this->{end_subst}, 'compile_substitution');
        foreach ($blk as &$v)
        {
            $v[4] = strlen($v[0]);
            $v[5] = strlen($v[1]);
        }

        $st = new TemplateState();

        // ищем фрагменты кода - на регэкспах-то было не очень правильно, да и медленно!
        $r = '';
        $pp = 0;
        $l = strlen($code);
        while ($code && $pp < $l)
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
                    $t = $frag;
                    if (!preg_match('/^\s*\n/s', $frag))
                        $frag = $this->$f($st, $frag);
                    else
                        $frag = NULL;
                    if (!is_null($frag))
                    {
                        // есть инструкция
                        $pp -= $blk[$b][4];
                        if ($pp > 0)
                        {
                            $text = substr($code, 0, $pp);
                            $code = substr($code, $pp);
                            $text = addcslashes($text, '\\\'');
                            // съедаем перевод строки, если надо
                            if ($blk[$b][5])
                                $text = preg_replace('/\r?\n\r?[ \t]*$/s', '', $text);
                            if (strlen($text))
                                $r .= "\$t.='$text';\n";
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

        // дописываем начало и конец кода
        if (!$fn)
        {
            $c = debug_backtrace();
            $c = $c[2];
            $fn = 'inline code in '.$c['class'].$c['type'].$c['function'].'() at '.$c['file'].':'.$c['line'];
        }
        $code = "<?php // $fn\n\$t = '';\n$r\n";
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
        if (!$e)
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
            $this->error("END $t without BEGIN, IF or SET");
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
            $st->in_set--;
            return $this->varref($in[1]) . " = \$t;\n\$t = array_pop(\$stack);\n";
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
        if ($m[3])
        {
            $e = $this->compile_expression($m[3]);
            if (!$e)
            {
                $this->error("Invalid expression in $kw: ($m[3])");
                return NULL;
            }
            return $this->varref($m[1]) . ' = ' . $e . ";\n";
        }
        $st->in[] = array('set', $m[1]);
        $st->in_set++;
        return "\$stack[] = \$t;\n\$t = '';\n";
    }

    // INCLUDE template.tpl
    function compile_code_fragment_include($st, $kw, $t)
    {
        $t = addcslashes($t, '\\\'');
        return "\$t.=\$this->parse('$t');\n";
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
        if (preg_match('/^([a-z_][a-z0-9_]*)(?:\s+AT\s+(.+))?(?:\s+BY\s+(.+))?(?:\s+TO\s+(.+))?/is', $t, $m))
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
        else if (!is_null($t = $this->compile_expression($e)))
            return "\$t.=$t;\n";
        return NULL;
    }

    // компиляция подстановки переменной {...} это просто выражение
    function compile_substitution($st, $e)
    {
        $e = $this->compile_expression($e);
        if ($e)
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
        // функция нескольких аргументов
        else if (preg_match('/^([a-z_][a-z0-9_]*)\s*\((.*)$/is', $e, $m))
        {
            $f = strtolower($m[1]);
            if (!method_exists($this, "function_$f"))
            {
                $this->error("Unknown function: '$f'");
                return NULL;
            }
            $a = $m[2];
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
            if ($a)
            {
                if (!$after)
                    return NULL;
                $after[0] = $a;
            }
            return call_user_func_array(array($this, "function_$f"), $args);
        }
        // функция одного аргумента
        else if (preg_match('/^([a-z_][a-z0-9_]*)\s+(?=\S)(.*)$/is', $e, $m))
        {
            $f = strtolower($m[1]);
            if (!method_exists($this, "function_$f"))
            {
                $this->error("Unknown function: '$f' in '$e'");
                return NULL;
            }
            $a = $m[2];
            $arg = $this->compile_expression($a, array(&$a));
            if (!$arg)
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
        else if (preg_match('/^((?:[a-z0-9_]+\.)*(?:[a-z0-9_]+\#?))(?:\/([a-z]+))?\s*(.*)$/is', $e, $m))
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

    /* функции */

    /* "или", "и", +, -, *, /, конкатенация */
    function function_or()       { $a = func_get_args(); return $this->fmop('||', $a); }
    function function_and()      { $a = func_get_args(); return $this->fmop('&&', $a); }
    function function_add()      { $a = func_get_args(); return $this->fmop('+', $a); }
    function function_sub()      { $a = func_get_args(); return $this->fmop('-', $a); }
    function function_mul()      { $a = func_get_args(); return $this->fmop('*', $a); }
    function function_div()      { $a = func_get_args(); return $this->fmop('/', $a); }
    function function_mod($a,$b) { return "(($a) % ($b))"; }
    function function_concat()   { $a = func_get_args(); return $this->fmop('.', $a); }

    /* логарифм, количество элементов, "не", "чётное?", "нечётное?", приведение к целому */
    function function_log($e)   { return "log($e)"; }
    function function_count($e) { return "self::array_count($e)"; }
    function function_not($e)   { return "!($e)"; }
    function function_even($e)  { return "!(($e) & 1)"; }
    function function_odd($e)   { return "(($e) & 1)"; }
    function function_int($e)   { return "intval($e)"; }
    function function_i($e)     { return "intval($e)"; }

    /* сравнения: == != > < >= <= */
    function function_eq($a,$b) { return "(($a) == ($b))"; }
    function function_ne($a,$b) { return "(($a) != ($b))"; }
    function function_gt($a,$b) { return "(($a) > ($b))"; }
    function function_lt($a,$b) { return "(($a) < ($b))"; }
    function function_ge($a,$b) { return "(($a) >= ($b))"; }
    function function_le($a,$b) { return "(($a) <= ($b))"; }

    /* нижний регистр */
    function function_lc($e)         { return "strtolower($e)"; }
    function function_lower($e)      { return "strtolower($e)"; }
    function function_lowercase($e)  { return "strtolower($e)"; }

    /* верхний регистр */
    function function_uc($e)         { return "strtoupper($e)"; }
    function function_upper($e)      { return "strtoupper($e)"; }
    function function_uppercase($e)  { return "strtoupper($e)"; }
    function function_strlimit($s,$l){ return "self::strlimit($s,$l)"; }

    /* экранирование символов, специльных для регулярок */
    function function_requote($e)    { return "preg_quote($e)"; }
    function function_re_quote($e)   { return "preg_quote($e)"; }
    function function_preg_quote($e) { return "preg_quote($e)"; }

    /* замены - по регулярке и по подстроке */
    function function_replace($re, $sub, $v)
    {
        return "preg_replace('#'.str_replace('#','\\\\#',$re).'#s', $sub, $v)";
    }
    function function_str_replace($s, $sub, $v)
    {
        return "str_replace($s, $sub, $v)";
    }

    /* разбиение строки по регулярному выражению */
    function function_split($re, $v, $limit=-1)
    {
        return "preg_split('#'.str_replace('#','\\\\#',$re).'#s', $v, $limit)";
    }

    /* экранирование кавычек */
    function function_quote($e)                 { return "addslashes($e)"; }
    function function_addslashes($e)            { return "addslashes($e)"; }
    function function_q($e)                     { return "addslashes($e)"; }

    /* преобразование символов <>&'" в HTML-сущности &lt; &gt; &amp; &apos; &quot; */
    function function_htmlspecialchars($e)      { return "htmlspecialchars($e,ENT_QUOTES)"; }
    function function_html($e)                  { return "htmlspecialchars($e,ENT_QUOTES)"; }
    function function_s($e)                     { return "htmlspecialchars($e,ENT_QUOTES)"; }

    /* экранирование в стиле URI */
    function function_uriquote($e)              { return "urlencode($e)"; }
    function function_uri_escape($e)            { return "urlencode($e)"; }
    function function_urlencode($e)             { return "urlencode($e)"; }

    /* удаление всех, заданных или "небезопасных" HTML-тегов */
    function function_strip($e, $t)             { return "strip_tags($e".($t?",$t":"").")"; }
    function function_t($e, $t)                 { return "strip_tags($e".($t?",$t":"").")"; }
    function function_strip_unsafe($e)          { return "strip_tags($e, self::\$safe_tags)"; }
    function function_h($e)                     { return "strip_tags($e, self::\$safe_tags)"; }

    /* объединение всех скаляров и всех элементов аргументов-массивов */
    function function_join()    { $a = func_get_args(); return self::fearr("'join'", $a); }
    function function_implode() { $a = func_get_args(); return self::fearr("'join'", $a); }

    /* подставляет на места $1, $2 и т.п. в строке аргументы */
    function function_subst()   { $a = func_get_args(); return self::fearr("'VMX_Template::exec_subst'", $a); }

    /* sprintf */
    function function_sprintf() { $a = func_get_args(); return self::fearr("'sprintf'", $a); }

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

    // создание массива
    function function_array()
    {
        $a = func_get_args();
        return "array(" . join(",", $a) . ")";
    }

    // подмассив по номерам элементов
    function function_subarray()        { $a = func_get_args(); return "array_slice(" . join(",", $a) . ")"; }
    function function_array_slice()     { $a = func_get_args(); return "array_slice(" . join(",", $a) . ")"; }

    // подмассив по кратности номеров элементов
    function function_subarray_divmod() { $a = func_get_args(); return "self::exec_subarray_divmod(" . join(",", $a) . ")"; }

    // получить элемент хеша/массива по неконстантному ключу (например get(iteration.array, rand(5)))
    // по-моему, это лучше, чем Template Toolkit'овский ад - hash.key.${another.hash.key}.зюка.хрюка и т.п.
    function function_get($a, $k)       { return $a."[$k]"; }
    function function_hget($a, $k)      { return $a."[$k]"; }
    function function_aget($a, $k)      { return $a."[$k]"; }

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

    // strftime
    function function_strftime($fmt, $date, $time = '')
    {
        $e = $time ? "($date).' '.($time)" : $date;
        return "strftime($fmt, self::timestamp($e))";
    }

    // выполняет подстановку function_subst
    static function exec_subst($str)
    {
        $args = func_get_args();
        $str = preg_replace_callback('/(?<!\\\\)((?:\\\\\\\\)*)\$(?:([1-9]\d*)|\{([1-9]\d*)\})/is', create_function('$m', 'return $args[$m[2]?$m[2]:$m[3]];'), $str);
        return $str;
    }

    // ограничение длины строки $maxlen символами на границе пробелов и добавление '...', если что.
    static function strlimit($str, $maxlen)
    {
        if (!$maxlen || $maxlen < 1 || strlen($str) <= $maxlen)
            return $str;
        $str = substr($str, 0, $maxlen);
        $p = strrpos($str, ' ');
        if (!$p || ($pt = strrpos($str, "\t")) > $ps)
            $p = $pt;
        if ($p)
            $str = substr($str, 0, $p);
        return $str . '...';
    }

    // ограниченная распознавалка дат
    function timestamp($ts = 0, $format = 0)
    {
        if (!self::$Mon)
        {
            self::$Mon = split(' ', 'Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec');
            self::$mon = array_reverse(split(' ', 'jan feb mar apr may jun jul aug sep oct nov dec'));
            self::$Wday = split(' ', 'Sun Mon Tue Wed Thu Fri Sat');
        }
        if (intval($ts) == $ts)
        {
            // TS_UNIX or Epoch
            if (!$ts)
                $ts = time;
        }
        elseif (preg_match('/^\D*(\d{4,})\D*(\d{2})\D*(\d{2})\D*(?:(\d{2})\D*(\d{2})\D*(\d{2})\D*([\+\- ]\d{2}\D*)?)?$/s', $ts, $m))
        {
            // TS_DB, TS_DB_DATE, TS_MW, TS_EXIF, TS_ISO_8601
            $ts = mktime($m[4], $m[5], $m[6], $m[2], $m[3], $m[1]);
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
