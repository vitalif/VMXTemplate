<?php

/**
 * Homepage: http://yourcmc.ru/wiki/VMX::Template
 * License: GNU GPLv3 or later
 * Author: Vitaliy Filippov, 2006-2016
 * Version: V3 (LALR), 2017-02-24
 *
 * This file contains the implementation of VMX::Template compiler.
 * It is only used when a template is compiled in runtime.
 */

/**
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 * http://www.gnu.org/copyleft/gpl.html
 */

class VMXTemplateCompiler
{
    // Function aliases
    static $functions = array(
        'i'                 => 'int',
        'intval'            => 'int',
        'lower'             => 'lc',
        'lowercase'         => 'lc',
        'upper'             => 'uc',
        'uppercase'         => 'uc',
        'addslashes'        => 'quote',
        'q'                 => 'quote',
        'sq'                => 'sql_quote',
        're_quote'          => 'requote',
        'preg_quote'        => 'requote',
        'uri_escape'        => 'urlencode',
        'uriquote'          => 'urlencode',
        'substring'         => 'substr',
        'htmlspecialchars'  => 'html',
        's'                 => 'html',
        'strip_tags'        => 'strip',
        't'                 => 'strip',
        'h'                 => 'strip_unsafe',
        'implode'           => 'join',
        'truncate'          => 'strlimit',
        'hash_keys'         => 'keys',
        'array_keys'        => 'keys',
        'array_slice'       => 'subarray',
        'hget'              => 'get',
        'aget'              => 'get',
        'var_dump'          => 'dump',
        'process'           => 'parse',
        'include'           => 'parse',
        'process_inline'    => 'parse_inline',
        'include_inline'    => 'parse_inline',
    );

    // Functions that do escape HTML, for safe mode
    const Q_ALWAYS = -1;
    const Q_IF_ALL = -2;
    const Q_ALL_BUT_FIRST = -3;
    static $functionSafeness = array(
        'int'               => self::Q_ALWAYS,
        'raw'               => self::Q_ALWAYS,
        'html'              => self::Q_ALWAYS,
        'strip'             => self::Q_ALWAYS,
        'strip_unsafe'      => self::Q_ALWAYS,
        'parse'             => self::Q_ALWAYS,
        'parse_inline'      => self::Q_ALWAYS,
        'exec'              => self::Q_ALWAYS,
        'exec_from'         => self::Q_ALWAYS,
        'exec_from_inline'  => self::Q_ALWAYS,
        'quote'             => self::Q_ALWAYS,
        'sql_quote'         => self::Q_ALWAYS,
        'requote'           => self::Q_ALWAYS,
        'urlencode'         => self::Q_ALWAYS,
        'and'               => self::Q_ALWAYS,
        'or'                => self::Q_IF_ALL,
        'not'               => self::Q_ALWAYS,
        'add'               => self::Q_ALWAYS,
        'sub'               => self::Q_ALWAYS,
        'mul'               => self::Q_ALWAYS,
        'div'               => self::Q_ALWAYS,
        'mod'               => self::Q_ALWAYS,
        'min'               => self::Q_IF_ALL,
        'max'               => self::Q_IF_ALL,
        'round'             => self::Q_ALWAYS,
        'log'               => self::Q_ALWAYS,
        'even'              => self::Q_ALWAYS,
        'odd'               => self::Q_ALWAYS,
        'eq'                => self::Q_ALWAYS,
        'ne'                => self::Q_ALWAYS,
        'gt'                => self::Q_ALWAYS,
        'lt'                => self::Q_ALWAYS,
        'ge'                => self::Q_ALWAYS,
        'le'                => self::Q_ALWAYS,
        'seq'               => self::Q_ALWAYS,
        'sne'               => self::Q_ALWAYS,
        'sgt'               => self::Q_ALWAYS,
        'slt'               => self::Q_ALWAYS,
        'sge'               => self::Q_ALWAYS,
        'sle'               => self::Q_ALWAYS,
        'neq'               => self::Q_ALWAYS,
        'nne'               => self::Q_ALWAYS,
        'ngt'               => self::Q_ALWAYS,
        'nlt'               => self::Q_ALWAYS,
        'nge'               => self::Q_ALWAYS,
        'nle'               => self::Q_ALWAYS,
        'strlen'            => self::Q_ALWAYS,
        'strftime'          => self::Q_ALWAYS,
        'str_replace'       => self::Q_ALL_BUT_FIRST,
        'substr'            => 1,   // parameter number to take safeness from
        'trim'              => 1,
        'split'             => 1,
        'nl2br'             => 1,
        'concat'            => self::Q_IF_ALL,
        'join'              => self::Q_IF_ALL,
        'subst'             => self::Q_IF_ALL,
        'strlimit'          => 1,
        'plural_ru'         => self::Q_ALL_BUT_FIRST,
        'hash'              => self::Q_IF_ALL,
        'keys'              => 1,
        'values'            => 1,
        'sort'              => 1,
        'pairs'             => 1,
        'array'             => self::Q_IF_ALL,
        'range'             => self::Q_ALWAYS,
        'is_array'          => self::Q_ALWAYS,
        'count'             => self::Q_ALWAYS,
        'subarray'          => 1,
        'subarray_divmod'   => 1,
        'set'               => 2,
        'array_merge'       => self::Q_IF_ALL,
        'shift'             => 1,
        'pop'               => 1,
        'unshift'           => self::Q_ALWAYS,
        'push'              => self::Q_ALWAYS,
        'void'              => self::Q_ALWAYS,
        'json'              => self::Q_ALWAYS,
        'map'               => self::Q_ALL_BUT_FIRST,
        'yesno'             => self::Q_ALL_BUT_FIRST,
    );

    var $options, $st, $lexer, $parser;

    function __construct($options)
    {
        $this->options = $options;
    }

    /**
     * Translate a template to PHP
     *
     * @param $code full template code
     * @param $filename input filename for error reporting
     * @param $func_ns suffix for class name (Template_SUFFIX)
     */
    function parse_all($code, $filename, $func_ns)
    {
        $this->st = new VMXTemplateState();
        $this->options->input_filename = $filename;
        $this->st->functions['main'] = array(
            'name' => 'main',
            'args' => array(),
            'body' => '',
        );
        if (!$this->lexer)
        {
            $this->lexer = new VMXTemplateLexer($this->options);
            $this->parser = new parse_engine(new VMXTemplateParser());
            $this->parser->parser->template = $this;
        }
        $this->lexer->set_code($code);
        $this->lexer->feed($this->parser);

        if ($this->st->functions['main']['body'] === '')
        {
            // Parse error
            unset($this->st->functions['main']);
        }

        // Generate code for functions
        $code = '';
        $functions = [];
        $smap = [];
        $l = 9;
        foreach ($this->st->functions as $n => $f)
        {
            $ms = [];
            preg_match_all('/(?:^|\n)# line (\d+)|\n/', $f['body'], $ms, PREG_SET_ORDER);
            foreach ($ms as $m)
            {
                $l++;
                if (!empty($m[1]))
                    $smap[] = [ $l, $m[1] ];
            }
            $code .= $f['body'];
            $functions[$n] = $f['args'];
        }

        // Assemble the class code
        $functions = var_export($functions, true);
        $smap = var_export($smap, true);
        $rfn = addcslashes($this->options->input_filename, '\\\'');
        $code = "<?php // {$this->options->input_filename}
class Template_$func_ns extends VMXTemplate {
static \$template_filename = '$rfn';
static \$version = ".VMXTemplate::CODE_VERSION.";
function __construct(\$t) {
\$this->tpldata = &\$t->tpldata;
\$this->parent = &\$t;
}
$code
static \$functions = $functions;
static \$smap = $smap;
}
";

        return $code;
    }

    function compile_function($fn, $args)
    {
        $fn = strtolower($fn);
        if (isset(self::$functions[$fn]))
        {
            // Function alias
            $fn = self::$functions[$fn];
        }
        $argv = [];
        $q = isset(self::$functionSafeness[$fn]) ? self::$functionSafeness[$fn] : false;
        if ($q > 0)
        {
            $q = isset($args[$q-1]) ? $args[$q-1][1] : true;
        }
        elseif ($q == self::Q_ALWAYS)
        {
            $q = true;
        }
        elseif ($q == self::Q_IF_ALL || $q == self::Q_ALL_BUT_FIRST)
        {
            $q = true;
            $n = count($args);
            for ($i = ($q == self::Q_ALL_BUT_FIRST ? 1 : 0); $i < $n; $i++)
            {
                $q = $q && $args[$i][1];
            }
        }
        foreach ($args as $a)
        {
            $argv[] = $a[0];
        }
        if (method_exists($this, "function_$fn"))
        {
            // Builtin function call using name
            $r = call_user_func_array(array($this, "function_$fn"), $argv);
        }
        elseif (isset($this->options->compiletime_functions[$fn]))
        {
            // Custom compile-time function call
            $r = call_user_func($this->options->compiletime_functions[$fn], $this, $argv);
        }
        else
        {
            // A block reference or unknown function
            $r = "\$this->parent->call_block_list('$fn', array(".implode(', ', $argv)."), '".addcslashes($this->lexer->errorinfo(), "'\\")."')";
            $q = true;
        }
        return [ $r, $q ];
    }

    /*** Functions ***/

    /** Utilities for function parsing **/

    // Code for operator-like function
    static function fmop($op, $args)
    {
        return "((" . join(") $op (", $args) . "))";
    }

    /** Числа, логические операции **/

    /* логические операции */
    function function_or()       { $a = func_get_args(); return "self::perlish_or(".join(",", $a).")"; }
    function function_and()      { $a = func_get_args(); return self::fmop('&&', $a); }
    function function_not($e)    { return "!($e)"; }

    /* арифметические операции */
    function function_add()      { $a = func_get_args(); return self::fmop('+', $a); }
    function function_sub()      { $a = func_get_args(); return self::fmop('-', $a); }
    function function_mul()      { $a = func_get_args(); return self::fmop('*', $a); }
    function function_div()      { $a = func_get_args(); return self::fmop('/', $a); }
    function function_mod($a,$b) { return "(($a) % ($b))"; }

    /* минимум и максимум, округление */
    function function_min()      { $a = func_get_args(); return "min([ ".implode(', ', $a)." ])"; }
    function function_max()      { $a = func_get_args(); return "max([ ".implode(', ', $a)." ])"; }
    function function_round($a)  { return "round($a)"; }

    /* логарифм */
    function function_log($e)    { return "log($e)"; }

    /* чётный, нечётный */
    function function_even($e)   { return "!(($e) & 1)"; }
    function function_odd($e)    { return "(($e) & 1)"; }

    /* приведение к целому числу */
    function function_int($e)    { return "intval($e)"; }

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
    function function_lc($e)         { return ($this->options->use_utf8 ? "mb_" : "") . "strtolower($e)"; }

    /* верхний регистр */
    function function_uc($e)         { return ($this->options->use_utf8 ? "mb_" : "") . "strtoupper($e)"; }

    /* нижний регистр первого символа */
    function function_lcfirst($e)    { return ($this->options->use_utf8 ? "self::mb_" : "") . "lcfirst($e)"; }

    /* верхний регистр первого символа */
    function function_ucfirst($e)    { return ($this->options->use_utf8 ? "self::mb_" : "") . "ucfirst($e)"; }

    /* экранирование кавычек */
    function function_quote($e)      { return "str_replace(array(\"\\n\",\"\\r\"),array(\"\\\\n\",\"\\\\r\"),addslashes($e))"; }

    /* экранирование кавычек в SQL- или CSV- стиле (кавычка " превращается в двойную кавычку "") */
    function function_sql_quote($e)  { return "str_replace('\"','\"\"',$e)"; }

    /* экранирование символов, специальных для регулярного выражения */
    function function_requote($e)    { return "preg_quote($e)"; }

    /* экранирование в стиле URL */
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
    function function_strlen($s) { return ($this->options->use_utf8 ? "mb_" : "") . "strlen($s)"; }

    /* подстрока */
    function function_substr($s, $start, $length = NULL)
    {
        return ($this->options->use_utf8 ? "mb_" : "") . "substr($s, $start" . ($length !== NULL ? ", $length" : "") . ")";
    }

    /* убиение пробелов в начале и конце */
    function function_trim($s) { return "trim($s)"; }

    /* разбиение строки по регулярному выражению */
    function function_split($re, $v, $limit = -1)
    {
        return "preg_split('#'.str_replace('#','\\\\#',$re).'#s', $v, $limit)";
    }

    /* пустое преобразование, для отмены автоэкранирования HTML */
    function function_raw($e)                   { return $e; }

    /* преобразование символов <>&'" в HTML-сущности &lt; &gt; &amp; &apos; &quot; */
    function function_html($e)                  { return "htmlspecialchars($e,ENT_QUOTES)"; }

    /* удаление всех или заданных тегов */
    function function_strip($e, $t='')          { return "self::strip_tags($e".($t?",$t":"").")"; }

    /* удаление "небезопасных" HTML-тегов */
    /* TODO: м.б исправлять некорректную разметку? */
    function function_strip_unsafe($e)          { return "self::strip_tags($e, self::\$safe_tags)"; }

    /* заменить \n на <br /> */
    function function_nl2br($s)                 { return "nl2br($s)"; }

    /* конкатенация строк */
    function function_concat()                  { $a = func_get_args(); return self::fmop('.', $a); }

    /* объединение всех скаляров и всех элементов аргументов-массивов */
    function function_join()
    {
        $a = func_get_args();
        $sep = array_shift($a);
        return "call_user_func('implode', $sep, self::merge_to_array(".implode(', ', $a)."))";
    }

    /* подставляет на места $1, $2 и т.п. в строке аргументы */
    function function_subst()
    {
        $a = func_get_args();
        return "call_user_func_array('VMXTemplate::exec_subst', self::merge_to_array(".implode(', ', $a)."))";
    }

    /* sprintf */
    function function_sprintf()
    {
        $a = func_get_args();
        return "call_user_func_array('sprintf', self::merge_to_array(".implode(', ', $a)."))";
    }

    /* strftime */
    function function_strftime($fmt, $date = NULL)
    {
        if ($date !== NULL)
        {
            $date = ", self::timestamp($date)";
        }
        return "strftime($fmt$date)";
    }

    /* ограничение длины строки $maxlen символами на границе пробелов и добавление '...', если что. */
    /* strlimit(string, length, dots = '...') */
    function function_strlimit($a)
    {
        $a = func_get_args();
        return "self::" . ($this->options->use_utf8 ? "mb_" : "") . "strlimit(".join(",", $a).")";
    }

    /* выбор правильной формы множественного числа для русского языка */
    function function_plural_ru($count, $one, $few, $many)
    {
        return "self::plural_ru($count, $one, $few, $many)";
    }

    /** Массивы и хеши **/

    /* создание хеша */
    function function_hash()
    {
        $a = func_get_args();
        if (count($a) == 1)
            return "self::exec_hash(".$a[0].")";
        $s = "array(";
        $i = 0;
        $d = '';
        foreach ($a as $v)
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

    /* значения хеша или массива */
    function function_values($a) { return "array_values(is_array($a) ? $a : array())"; }

    /* сортировка массива/массивов */
    function function_sort()
    {
        $a = func_get_args();
        return "call_user_func('VMXTemplate::exec_sort', self::merge_to_array(".implode(', ', $a)."))";
    }

    /* пары key => ключ, value => значение для ассоциативного массива */
    function function_pairs() { $a = func_get_args(); return "self::exec_pairs(".implode(', ', $a).")"; }

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

    /* подмассив по кратности номеров элементов */
    function function_subarray_divmod() { $a = func_get_args(); return "self::exec_subarray_divmod(" . join(",", $a) . ")"; }

    /* 0) получить "корневую" переменную по неконстантному ключу
       1) получить элемент хеша/массива по неконстантному ключу (например get(iteration.array, rand(5)))
          по-моему, это лучше, чем Template Toolkit'овский ад - hash.key.${another.hash.key}.зюка.хрюка и т.п.
       2) получить элемент выражения-массива - в PHP < 5.4 не работает (...expression...)['key'],
          к примеру не работает range(1,10)[0]
          но у нас-то это поддерживается... */
    function function_get($a, $k = NULL)
    {
        if ($k === NULL)
            return "\$this->tpldata[$a]";
        if (PHP_VERSION_ID > 50400)
            return $a."[$k]";
        return "self::exec_get($a, $k)";
    }

    /* присваивание (только lvalue) */
    function function_set($l, $r)       { return "self::void($l = $r)"; }

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

    /* дамп переменной */
    function function_dump($var)
    {
        return "var_export($var, true)";
    }

    /* JSON-кодирование */
    function function_json($v)  { return "json_encode($v, JSON_UNESCAPED_UNICODE)"; }

    /* Аргументы для функций включения
       аргументы ::= hash(ключ => значение, ...) | ключ => значение, ...
    */
    protected function auto_hash($args)
    {
        if (!($n = count($args)))
            $args = ', $this->tpldata, false';
        elseif ($n == 1)
            $args = ", ".$args[0];
        else
            $args = ", ".call_user_func_array(array($this, 'function_hash'), $args);
        return $args;
    }

    /* включение другого файла: parse('файл'[, аргументы]) */
    function function_parse()
    {
        $args = func_get_args();
        $file = array_shift($args);
        $p = $args ? 'parse_discard' : 'parse_real';
        $args = $this->auto_hash($args);
        return "\$this->parent->$p($file, NULL, 'main'$args)";
    }

    /* включение блока из текущего файла: exec('блок'[, аргументы]) */
    function function_exec()
    {
        $args = func_get_args();
        $block = array_shift($args);
        $p = $args ? 'parse_discard' : 'parse_real';
        $args = $this->auto_hash($args);
        return "\$this->parent->$p(self::\$template_filename, NULL, $block$args)";
    }

    /* включение блока из другого файла: exec_from('файл', 'блок'[, аргументы]) */
    function function_exec_from()
    {
        $args = func_get_args();
        $file = array_shift($args);
        $block = array_shift($args);
        $p = $args ? 'parse_discard' : 'parse_real';
        $args = $this->auto_hash($args);
        return "\$this->parent->$p($file, NULL, $block$args)";
    }

    /* parse не из файла, хотя и не рекомендуется */
    function function_parse_inline()
    {
        $args = func_get_args();
        $code = array_shift($args);
        $p = $args ? 'parse_discard' : 'parse_real';
        $args = $this->auto_hash($args);
        return "\$this->parent->$p(NULL, $code, 'main'$args)";
    }

    /* сильно не рекомендуется, но возможно:
       включение блока не из файла:
       exec_from_inline('код', 'блок'[, аргументы]) */
    function function_exec_from_inline()
    {
        $args = func_get_args();
        $code = array_shift($args);
        $block = array_shift($args);
        $p = $args ? 'parse_discard' : 'parse_real';
        $args = $this->auto_hash($args);
        return "\$this->parent->$p(NULL, $code, $block$args)";
    }

    /* вызов функции объекта по вычисляемому имени:
       call(object, "method", arg1, arg2, ...) или
       call_array(object, "method", array(arg1, arg2, ...)) */
    function function_call()
    {
        $a = func_get_args();
        $o = array_shift($a);
        $m = array_shift($a);
        return "call_user_func_array(array($o, $m), array(".implode(", ", $a)."))";
    }
    function function_call_array($o, $m, $a = NULL)
    {
        return "call_user_func_array(array($o, $m), ".($a ? $a : "array()").")";
    }

    /* map() */
    function function_map($f)
    {
        if (!preg_match('/^(["\'])([a-z_]+)\1$/s', $f, $m))
        {
            $this->lexer->warn("Non-constant function specified for map(): $f");
            return 'false';
        }
        $fn = $m[2];
        if (isset(self::$functions[$fn]))
        {
            // Function alias
            $fn = self::$functions[$fn];
        }
        if (!method_exists($this, "function_$fn"))
        {
            $this->lexer->warn("Unknown function specified for map(): $f");
            return 'false';
        }
        $fn = "function_$fn";
        $fn = $this->$fn('$arg');
        $args = func_get_args();
        array_shift($args);
        return "array_map(function(\$arg) { return $fn; }, self::merge_to_array(".implode(", ", $args)."))";
    }
}

/**
 * State object
 */
class VMXTemplateState
{
    // Functions
    var $functions = array();
}

/**
 * Lexical analyzer (~regexp)
 */
class VMXTemplateLexer
{
    var $options;

    // Code (string) and current position inside it
    var $code, $codelen, $pos, $lineno;

    // Last directive start position, directive and substitution start/end counters
    var $last_start, $last_start_line, $in_code, $in_subst, $force_literal = 0;

    // Possible tokens consisting of special characters
    static $chartokens = '+ - = * / % ! , . < > ( ) { } [ ] & .. || && == != <= >= =>';

    // Reserved keywords
    static $keywords_str = 'OR XOR AND NOT IF ELSE ELSIF ELSEIF END SET FOR FOREACH FUNCTION BLOCK MACRO';

    var $nchar, $lens, $keywords;

    function __construct(VMXTemplateOptions $options)
    {
        $this->options = $options;
        $this->nchar = array();
        foreach (explode(' ', self::$chartokens) as $t)
        {
            $this->nchar[strlen($t)][$t] = true;
        }
        // Add code fragment finishing tokens
        $this->nchar[strlen($this->options->end_code)][$this->options->end_code] = true;
        if ($this->options->end_subst)
        {
            $this->nchar[strlen($this->options->end_subst)][$this->options->end_subst] = true;
        }
        // Reverse-sort lengths
        $this->lens = array_keys($this->nchar);
        rsort($this->lens);
        $this->keywords = array_flip(explode(' ', self::$keywords_str));
    }

    function feed($parser)
    {
        try
        {
            $parser->reset();
            $in = false;
            while ($t = $this->read_token())
            {
                $success = $parser->eat($t[0], $t[1]);
                if (!$success)
                {
                    // Pass $in from last step so we skip to the beginning
                    // of directive even if it just ended and $this->in_* == 0
                    $this->skip_error(end($parser->parser->errors), $in);
                }
                $in = $this->in_code || $this->in_subst;
            }
            $parser->eat_eof();
        }
        catch (parse_error $e)
        {
            $this->options->error($e->getMessage());
        }
    }

    function set_code($code)
    {
        $this->code = $code;
        $this->codelen = strlen($this->code);
        $this->pos = $this->lineno = 0;
    }

    function errorinfo()
    {
        $linestart = strrpos($this->code, "\n", $this->pos-$this->codelen-1) ?: -1;
        $lineend = strpos($this->code, "\n", $this->pos) ?: $this->codelen;
        $line = substr($this->code, $linestart+1, $this->pos-$linestart-1);
        $line .= '^^^';
        $line .= substr($this->code, $this->pos, $lineend-$this->pos);
        return " in {$this->options->input_filename}, line ".($this->lineno+1).", byte {$this->pos}, marked by ^^^ in $line";
    }

    function warn($text)
    {
        $this->options->error($text.$this->errorinfo());
    }

    /**
     * Skip a directive
     */
    function skip_error($e, $force = false)
    {
        if (substr($e, 0, 18) !== 'error not expected')
        {
            $this->warn($e);
            if ($this->in_code || $this->in_subst || $force)
            {
                $this->in_code = $this->in_subst = 0;
                $this->pos = $this->last_start;
                $this->lineno = $this->last_start_line;
                $this->force_literal = 1;
            }
        }
    }

    /**
     * Read next token from the stream
     * Returns array($token, $value) or false for EOF
     */
    function read_token()
    {
        if ($this->pos >= $this->codelen)
        {
            // End of code
            return false;
        }
        if ($this->in_code <= 0 && $this->in_subst <= 0)
        {
            $was_code = true;
            $code_pos = strpos($this->code, $this->options->begin_code, $this->pos+$this->force_literal);
            $subst_pos = strpos($this->code, $this->options->begin_subst, $this->pos+$this->force_literal);
            $this->force_literal = 0;
            if ($code_pos === false && $subst_pos === false)
            {
                $r = array('literal', "'".addcslashes(substr($this->code, $this->pos), "'\\")."'");
                $this->lineno += substr_count($r[1], "\n");
                $this->pos = $this->codelen;
            }
            elseif ($subst_pos === false || $code_pos !== false && $subst_pos > $code_pos)
            {
                // Code starts closer
                if ($code_pos > $this->pos)
                {
                    // We didn't yet reach the code beginning
                    $str = substr($this->code, $this->pos, $code_pos-$this->pos);
                    if ($this->options->eat_code_line)
                    {
                        $str = preg_replace('/\n[ \t]*$/s', $was_code ? '' : "\n", $str);
                    }
                    $r = array('literal', "'".addcslashes($str, "'\\")."'");
                    $this->lineno += substr_count($r[1], "\n");
                    $this->pos = $code_pos;
                }
                elseif ($code_pos !== false)
                {
                    // We are at the code beginning ($this->pos == $code_pos)
                    $i = $this->pos+strlen($this->options->begin_code);
                    while ($i < $this->codelen && (($c = $this->code{$i}) == ' ' || $c == "\t"))
                    {
                        $i++;
                    }
                    if ($i < $this->codelen && $this->code{$i} == '#')
                    {
                        // Strip comment
                        $i = strpos($this->code, $this->options->end_code, $i);
                        $this->pos = $i ? $i+strlen($this->options->end_code) : $this->codelen;
                        return $this->read_token();
                    }
                    $r = array('<!--', $this->options->begin_code);
                    $this->last_start = $this->pos;
                    $this->last_start_line = $this->lineno;
                    $this->pos += strlen($this->options->begin_code);
                    $this->in_code = 1;
                }
                $was_code = true;
            }
            else
            {
                // Substitution is closer
                if ($subst_pos > $this->pos)
                {
                    $r = array('literal', "'".addcslashes(substr($this->code, $this->pos, $subst_pos-$this->pos), "'\\")."'");
                    $this->lineno += substr_count($r[1], "\n");
                    $this->pos = $subst_pos;
                }
                else
                {
                    $r = array('{{', $this->options->begin_subst);
                    $this->last_start = $this->pos;
                    $this->last_start_line = $this->lineno;
                    $this->pos++;
                    $this->in_subst = 1;
                }
                $was_code = false;
            }
            return $r;
        }
        while ($this->pos < $this->codelen)
        {
            // Skip whitespace
            $t = $this->code{$this->pos};
            if ($t == "\n")
                $this->lineno++;
            elseif ($t != "\t" && $t != ' ')
                break;
            $this->pos++;
        }
        if ($this->pos >= $this->codelen)
        {
            // End of code
            return false;
        }
        if (preg_match('#[a-z_][a-z0-9_]*#Ais', $this->code, $m, 0, $this->pos))
        {
            $this->pos += strlen($m[0]);
            if (isset($this->keywords[$l = strtoupper($m[0])]))
            {
                // Keyword
                return array($l, $m[0]);
            }
            // Identifier
            return array('name', $m[0]);
        }
        elseif (preg_match(
            '/((\")(?:[^\"\\\\]+|\\\\.)*\"|\'(?:[^\'\\\\]+|\\\\.)*\''.
            '|0\d+|\d+(\.\d+)?|0x\d+)/Ais', $this->code, $m, 0, $this->pos))
        {
            // String or numeric non-negative literal
            $t = $m[1];
            if (isset($m[2]))
            {
                $t = str_replace('$', '\\$', $t);
            }
            $this->pos += strlen($m[0]);
            return array('literal', $t);
        }
        else
        {
            // Special characters
            foreach ($this->lens as $l)
            {
                $a = $this->nchar[$l];
                $t = substr($this->code, $this->pos, $l);
                if (isset($a[$t]))
                {
                    $this->pos += $l;
                    if ($this->in_code)
                    {
                        $this->in_code += ($t === $this->options->begin_code);
                        $this->in_code -= ($t === $this->options->end_code);
                        if (!$this->in_code)
                        {
                            return array('-->', $t);
                        }
                    }
                    elseif ($this->in_subst)
                    {
                        $this->in_subst += ($t === $this->options->begin_subst);
                        $this->in_subst -= ($t === $this->options->end_subst);
                        if (!$this->in_subst)
                        {
                            return array('}}', $t);
                        }
                    }
                    return array($t, false);
                }
            }
            // Unknown character
            $this->skip_error(
                "Unexpected character '".$this->code{$this->pos}."'"
            );
            return array('error', false);
        }
    }
}

/**
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Library General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

define('LIME_CALL_PROTOCOL', '$tokens, &$result');

abstract class lime_parser {
}

/**
 * The input doesn't match the grammar
 */
class parse_error extends Exception {
}

/**
 * Bug, I made a mistake
 */
class parse_bug extends Exception {
}

class parse_unexpected_token extends parse_error {
	public function __construct($type, $state) {
		parent::__construct("Unexpected token of type {$type}");

		$this->type = $type;
		$this->state = $state;
	}
}

class parse_premature_eof extends parse_error {
	public function __construct(array $expect) {
		parent::__construct('Premature EOF');
	}
}

class parse_stack {
	public $q;
	public $qs = array();
	/**
	 * Stack of semantic actions
	 */
	public $ss = array();

	public function __construct($qi) {
		$this->q = $qi;
	}

	public function shift($q, $semantic) {
		$this->ss[] = $semantic;
		$this->qs[] = $this->q;

		$this->q = $q;

		// echo "Shift $q -- $semantic\n";
	}

	public function top_n($n) {
		if (!$n) {
			return array();
		}

		return array_slice($this->ss, 0 - $n);
	}

	public function pop_n($n) {
		if (!$n) {
			return array();
		}

		$qq = array_splice($this->qs, 0 - $n);
		$this->q = $qq[0];

		return array_splice($this->ss, 0 - $n);
	}

	public function occupied() {
		return !empty($this->ss);
	}

	public function index($n) {
		if ($n) {
			$this->q = $this->qs[count($this->qs) - $n];
		}
	}

	public function text() {
		return $this->q . ' : ' . implode(' . ', array_reverse($this->qs));
	}
}

class parse_engine {
	public $debug = false;

	public $parser;
	public $qi;
	public $rule;
	public $step;
	public $descr;
	/**
	 * @var boolean
	 */
	public $accept;
	/**
	 * @var parse_stack
	 */
	public $stack;

	public function __construct($parser) {
		$this->parser = $parser;
		$this->qi = $parser->qi;
		$this->rule = $parser->a;
		$this->step = $parser->i;
		$this->descr = $parser->d;

		$this->reset();
	}

	public function reset() {
		$this->accept = false;
		$this->stack = new parse_stack($this->qi);
		$this->parser->errors = array();
	}

	private function enter_error_tolerant_state() {
		while ($this->stack->occupied()) {
			if ($this->has_step_for('error')) {
				return true;
			}

			if ($this->debug) echo "Dropped an item from the stack, {" . implode(', ', $this->get_steps()) . "} left\n";
			if ($this->debug) echo 'Currently in state ' . $this->state() . "\n";

			$this->drop();
		}

		return false;
	}

	private function drop() {
		$this->stack->pop_n(1);
	}

	/*
	 * So that I don't get any brilliant misguided ideas:
	 *
	 * The "accept" step happens when we try to eat a start symbol.
	 * That happens because the reductions up the stack at the end
	 * finally (and symetrically) tell the parser to eat a symbol
	 * representing what they've just shifted off the end of the stack
	 * and reduced. However, that doesn't put the parser into any
	 * special different state. Therefore, it's back at the start
	 * state.
	 *
	 * That being said, the parser is ready to reduce an EOF to the
	 * empty program, if given a grammar that allows them.
	 *
	 * So anyway, if you literally tell the parser to eat an EOF
	 * symbol, then after it's done reducing and accepting the prior
	 * program, it's going to think it has another symbol to deal with.
	 * That is the EOF symbol, which means to reduce the empty program,
	 * accept it, and then continue trying to eat the terminal EOF.
	 *
	 * This infinte loop quickly runs out of memory.
	 *
	 * That's why the real EOF algorithm doesn't try to pretend that
	 * EOF is a terminal. Like the invented start symbol, it's special.
	 *
	 * Instead, we pretend to want to eat EOF, but never actually
	 * try to get it into the parse stack. (It won't fit.) In short,
	 * we look up what reduction is indicated at each step in the
	 * process of rolling up the parse stack.
	 *
	 * The repetition is because one reduction is not guaranteed to
	 * cascade into another and clean up the entire parse stack.
	 * Rather, it will instead shift each partial production as it
	 * is forced to completion by the EOF lookahead.
	 */
	public function eat_eof() {
		// We must reduce as if having read the EOF symbol
		do {
			// and we have to try at least once, because if nothing
			// has ever been shifted, then the stack will be empty
			// at the start.
			list($opcode, $operand) = $this->step_for('#');

			switch ($opcode) {
			case 'r':
				$this->reduce($operand);
				break;
			case 'e':
				$this->premature_eof();
				break;
			default:
				throw new parse_bug();
			}
		} while ($this->stack->occupied());

		// If the sentence is well-formed according to the grammar, then
		// this will eventually result in eating a start symbol, which
		// causes the "accept" instruction to fire. Otherwise, the
		// step('#') method will indicate an error in the syntax, which
		// here means a premature EOF.
		//
		// Incidentally, some tremendous amount of voodoo with the parse
		// stack might help find the beginning of some unfinished
		// production that the sentence was cut off during, but as a
		// general rule that would require deeper knowledge.
		if (!$this->accept) {
			throw new parse_bug();
		}

		return $this->semantic;
	}

	private function premature_eof() {
		$seen = array();

		$expect = $this->get_steps();

		while ($this->enter_error_tolerant_state() || $this->has_step_for('error')) {
			if (isset($seen[$this->state()])) {
				// This means that it's pointless to try here.
				// We're guaranteed that the stack is occupied.
				$this->drop();
				continue;
			}

			$seen[$this->state()] = true;

			$this->eat('error', 'Premature EOF');

			if ($this->has_step_for('#')) {
				// Good. We can continue as normal.
				return;
			} else {
				// That attempt to resolve the error condition
				// did not work. There's no point trying to
				// figure out how much to slice off the stack.
				// The rest of the algorithm will make it happen.
			}
		}

		throw new parse_premature_eof($expect);
	}

	private function current_row() {
		return $this->step[$this->state()];
	}

	private function step_for($type) {
		$row = $this->current_row();
		if (isset($row[$type])) {
			return explode(' ', $row[$type]);
		}
		if (isset($row[''])) {
			return explode(' ', $row['']);
		}
		return array('e', $this->stack->q);
	}

	private function get_steps() {
		$out = array();
		foreach($this->current_row() as $type => $row) {
			foreach($this->rule as $rule) {
				if ($rule['symbol'] == $type) {
					continue 2;
				}
			}

			list($opcode) = explode(' ', $row, 2);
			if ($opcode != 'e') {
				$out[] = $type === '' ? '$default' : $type;
			}
		}

		return $out;
	}

	private function has_step_for($type) {
		$row = $this->current_row();
		return isset($row[$type]);
	}

	private function state() {
		return $this->stack->q;
	}

	function eat($type, $semantic) {
		// assert('$type == trim($type)');
		if ($this->debug) echo "Trying to eat a ($type)\n";
		list($opcode, $operand) = $this->step_for($type);

		switch ($opcode) {
		case 's':
			if ($this->debug) echo "shift $type to state $operand\n";
			$this->stack->shift($operand, $semantic);
			// echo $this->stack->text()." shift $type<br/>\n";
			break;
		case 'r':
			if ($this->debug) echo "Reducing $type via rule $operand\n";
			$this->reduce($operand);
			// Yes, this is tail-recursive. It's also the simplest way.
			return $this->eat($type, $semantic);
		case 'a':
			if ($this->stack->occupied()) {
				throw new parse_bug('Accept should happen with empty stack.');
			}

			$this->accept = true;
			if ($this->debug) echo ("Accept\n\n");
			$this->semantic = $semantic;
			break;
		case 'e':
			// This is thought to be the uncommon, exceptional path, so
			// it's OK that this algorithm will cause the stack to
			// flutter while the parse engine waits for an edible token.
			if ($this->debug) echo "($type) causes a problem.\n";

			// get these before doing anything
			$expected = $this->get_steps();

			$this->parser->errors[] = $this->descr($type, $semantic) . ' not expected, expected one of ' . implode(', ', $expected);

			if ($this->debug) echo "Possibilities before error fixing: {" . implode(', ', $expected) . "}\n";

			if ($this->enter_error_tolerant_state() || $this->has_step_for('error')) {
				$this->eat('error', end($this->parser->errors));
				if ($this->has_step_for($type)) {
					$this->eat($type, $semantic);
				}
				return false;
			} else {
				// If that didn't work, give up:
				throw new parse_error('Parse Error: ' . $this->descr($type, $semantic) . ' not expected, expected one of ' . implode(', ', $expected));
			}
			break;
		default:
			throw new parse_bug("Bad parse table instruction " . htmlspecialchars($opcode));
		}
		return true;
	}

	private function descr($type, $semantic) {
		if (isset($this->descr[$type])) {
			return $this->descr[$type];
		} elseif ("$semantic" !== "") {
			return $type . ' (' . $semantic . ')';
		} else {
			return $type;
		}
	}

	private function reduce($rule_id) {
		$rule = $this->rule[$rule_id];
		$len = $rule['len'];
		$semantic = $this->perform_action($rule_id, $this->stack->top_n($len));

		//echo $semantic.br();
		if ($rule['replace']) {
			$this->stack->pop_n($len);
		} else {
			$this->stack->index($len);
		}

		$this->eat($rule['symbol'], $semantic);
	}

	private function perform_action($rule_id, $slice) {
		// we have this weird calling convention....
		$result = null;
		$method = $this->parser->method[$rule_id];

		//if ($this->debug) echo "rule $id: $method\n";
		$this->parser->$method($slice, $result);

		return $result;
	}
}

/*
 *** DON'T EDIT THIS FILE! ***
 *
 * This file was automatically generated by the Lime parser generator.
 * The real source code you should be looking at is in one or more
 * grammar files in the Lime format.
 *
 * THE ONLY REASON TO LOOK AT THIS FILE is to see where in the grammar
 * file that your error happened, because there are enough comments to
 * help you debug your grammar.

 * If you ignore this warning, you're shooting yourself in the brain,
 * not the foot.
 */
class VMXTemplateParser extends lime_parser {
  public $qi = 0;
  public $i = array(
    array(
      'chunks' => 's 1',
      'template' => 's 187',
      "'start'" => "a 'start'",
      'literal' => 'r 1',
      '<!--' => 'r 1',
      '{{' => 'r 1',
      '#' => 'r 1'
    ),
    array(
      'chunk' => 's 2',
      'literal' => 's 3',
      '<!--' => 's 4',
      '{{' => 's 161',
      'error' => 's 164',
      '#' => 'r 0'
    ),
    array(
      '' => 'r 2'
    ),
    array(
      '' => 'r 3'
    ),
    array(
      'code_chunk' => 's 5',
      'c_if' => 's 7',
      'c_set' => 's 8',
      'c_fn' => 's 9',
      'c_for' => 's 10',
      'exp' => 's 11',
      'IF' => 's 118',
      'SET' => 's 129',
      'fn' => 's 137',
      'for' => 's 148',
      'FUNCTION' => 's 156',
      'BLOCK' => 's 157',
      'MACRO' => 's 158',
      'FOR' => 's 159',
      'FOREACH' => 's 160',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '-->' => 's 6'
    ),
    array(
      '' => 'r 4'
    ),
    array(
      '' => 'r 7'
    ),
    array(
      '' => 'r 8'
    ),
    array(
      '' => 'r 9'
    ),
    array(
      '' => 'r 10'
    ),
    array(
      '..' => 's 12',
      '||' => 's 14',
      'OR' => 's 16',
      'XOR' => 's 18',
      '&&' => 's 20',
      'AND' => 's 22',
      '==' => 's 24',
      '!=' => 's 26',
      '<' => 's 28',
      '>' => 's 30',
      '<=' => 's 32',
      '>=' => 's 34',
      '+' => 's 36',
      '-' => 's 38',
      '&' => 's 40',
      '*' => 's 42',
      '/' => 's 44',
      '%' => 's 46',
      '-->' => 'r 11'
    ),
    array(
      'exp' => 's 13',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '..' => 'r 31',
      '||' => 's 14',
      'OR' => 's 16',
      'XOR' => 's 18',
      '&&' => 's 20',
      'AND' => 's 22',
      '==' => 's 24',
      '!=' => 's 26',
      '<' => 's 28',
      '>' => 's 30',
      '<=' => 's 32',
      '>=' => 's 34',
      '+' => 's 36',
      '-' => 's 38',
      '&' => 's 40',
      '*' => 's 42',
      '/' => 's 44',
      '%' => 's 46',
      '-->' => 'r 31',
      ')' => 'r 31',
      ',' => 'r 31',
      '=>' => 'r 31',
      ']' => 'r 31',
      '}}' => 'r 31',
      '}' => 'r 31'
    ),
    array(
      'exp' => 's 15',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '..' => 'r 32',
      '||' => 'r 32',
      'OR' => 'r 32',
      'XOR' => 'r 32',
      '&&' => 's 20',
      'AND' => 's 22',
      '==' => 's 24',
      '!=' => 's 26',
      '<' => 's 28',
      '>' => 's 30',
      '<=' => 's 32',
      '>=' => 's 34',
      '+' => 's 36',
      '-' => 's 38',
      '&' => 's 40',
      '*' => 's 42',
      '/' => 's 44',
      '%' => 's 46',
      '-->' => 'r 32',
      ')' => 'r 32',
      ',' => 'r 32',
      '=>' => 'r 32',
      ']' => 'r 32',
      '}}' => 'r 32',
      '}' => 'r 32'
    ),
    array(
      'exp' => 's 17',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '..' => 'r 33',
      '||' => 'r 33',
      'OR' => 'r 33',
      'XOR' => 'r 33',
      '&&' => 's 20',
      'AND' => 's 22',
      '==' => 's 24',
      '!=' => 's 26',
      '<' => 's 28',
      '>' => 's 30',
      '<=' => 's 32',
      '>=' => 's 34',
      '+' => 's 36',
      '-' => 's 38',
      '&' => 's 40',
      '*' => 's 42',
      '/' => 's 44',
      '%' => 's 46',
      '-->' => 'r 33',
      ')' => 'r 33',
      ',' => 'r 33',
      '=>' => 'r 33',
      ']' => 'r 33',
      '}}' => 'r 33',
      '}' => 'r 33'
    ),
    array(
      'exp' => 's 19',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '..' => 'r 34',
      '||' => 'r 34',
      'OR' => 'r 34',
      'XOR' => 'r 34',
      '&&' => 's 20',
      'AND' => 's 22',
      '==' => 's 24',
      '!=' => 's 26',
      '<' => 's 28',
      '>' => 's 30',
      '<=' => 's 32',
      '>=' => 's 34',
      '+' => 's 36',
      '-' => 's 38',
      '&' => 's 40',
      '*' => 's 42',
      '/' => 's 44',
      '%' => 's 46',
      '-->' => 'r 34',
      ')' => 'r 34',
      ',' => 'r 34',
      '=>' => 'r 34',
      ']' => 'r 34',
      '}}' => 'r 34',
      '}' => 'r 34'
    ),
    array(
      'exp' => 's 21',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '..' => 'r 35',
      '||' => 'r 35',
      'OR' => 'r 35',
      'XOR' => 'r 35',
      '&&' => 'r 35',
      'AND' => 'r 35',
      '==' => 's 24',
      '!=' => 's 26',
      '<' => 's 28',
      '>' => 's 30',
      '<=' => 's 32',
      '>=' => 's 34',
      '+' => 's 36',
      '-' => 's 38',
      '&' => 's 40',
      '*' => 's 42',
      '/' => 's 44',
      '%' => 's 46',
      '-->' => 'r 35',
      ')' => 'r 35',
      ',' => 'r 35',
      '=>' => 'r 35',
      ']' => 'r 35',
      '}}' => 'r 35',
      '}' => 'r 35'
    ),
    array(
      'exp' => 's 23',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '..' => 'r 36',
      '||' => 'r 36',
      'OR' => 'r 36',
      'XOR' => 'r 36',
      '&&' => 'r 36',
      'AND' => 'r 36',
      '==' => 's 24',
      '!=' => 's 26',
      '<' => 's 28',
      '>' => 's 30',
      '<=' => 's 32',
      '>=' => 's 34',
      '+' => 's 36',
      '-' => 's 38',
      '&' => 's 40',
      '*' => 's 42',
      '/' => 's 44',
      '%' => 's 46',
      '-->' => 'r 36',
      ')' => 'r 36',
      ',' => 'r 36',
      '=>' => 'r 36',
      ']' => 'r 36',
      '}}' => 'r 36',
      '}' => 'r 36'
    ),
    array(
      'exp' => 's 25',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '..' => 'r 37',
      '||' => 'r 37',
      'OR' => 'r 37',
      'XOR' => 'r 37',
      '&&' => 'r 37',
      'AND' => 'r 37',
      '+' => 's 36',
      '-' => 's 38',
      '&' => 's 40',
      '*' => 's 42',
      '/' => 's 44',
      '%' => 's 46',
      '-->' => 'r 37',
      ')' => 'r 37',
      ',' => 'r 37',
      '=>' => 'r 37',
      ']' => 'r 37',
      '}}' => 'r 37',
      '}' => 'r 37'
    ),
    array(
      'exp' => 's 27',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '..' => 'r 38',
      '||' => 'r 38',
      'OR' => 'r 38',
      'XOR' => 'r 38',
      '&&' => 'r 38',
      'AND' => 'r 38',
      '+' => 's 36',
      '-' => 's 38',
      '&' => 's 40',
      '*' => 's 42',
      '/' => 's 44',
      '%' => 's 46',
      '-->' => 'r 38',
      ')' => 'r 38',
      ',' => 'r 38',
      '=>' => 'r 38',
      ']' => 'r 38',
      '}}' => 'r 38',
      '}' => 'r 38'
    ),
    array(
      'exp' => 's 29',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '..' => 'r 39',
      '||' => 'r 39',
      'OR' => 'r 39',
      'XOR' => 'r 39',
      '&&' => 'r 39',
      'AND' => 'r 39',
      '+' => 's 36',
      '-' => 's 38',
      '&' => 's 40',
      '*' => 's 42',
      '/' => 's 44',
      '%' => 's 46',
      '-->' => 'r 39',
      ')' => 'r 39',
      ',' => 'r 39',
      '=>' => 'r 39',
      ']' => 'r 39',
      '}}' => 'r 39',
      '}' => 'r 39'
    ),
    array(
      'exp' => 's 31',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '..' => 'r 40',
      '||' => 'r 40',
      'OR' => 'r 40',
      'XOR' => 'r 40',
      '&&' => 'r 40',
      'AND' => 'r 40',
      '+' => 's 36',
      '-' => 's 38',
      '&' => 's 40',
      '*' => 's 42',
      '/' => 's 44',
      '%' => 's 46',
      '-->' => 'r 40',
      ')' => 'r 40',
      ',' => 'r 40',
      '=>' => 'r 40',
      ']' => 'r 40',
      '}}' => 'r 40',
      '}' => 'r 40'
    ),
    array(
      'exp' => 's 33',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '..' => 'r 41',
      '||' => 'r 41',
      'OR' => 'r 41',
      'XOR' => 'r 41',
      '&&' => 'r 41',
      'AND' => 'r 41',
      '+' => 's 36',
      '-' => 's 38',
      '&' => 's 40',
      '*' => 's 42',
      '/' => 's 44',
      '%' => 's 46',
      '-->' => 'r 41',
      ')' => 'r 41',
      ',' => 'r 41',
      '=>' => 'r 41',
      ']' => 'r 41',
      '}}' => 'r 41',
      '}' => 'r 41'
    ),
    array(
      'exp' => 's 35',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '..' => 'r 42',
      '||' => 'r 42',
      'OR' => 'r 42',
      'XOR' => 'r 42',
      '&&' => 'r 42',
      'AND' => 'r 42',
      '+' => 's 36',
      '-' => 's 38',
      '&' => 's 40',
      '*' => 's 42',
      '/' => 's 44',
      '%' => 's 46',
      '-->' => 'r 42',
      ')' => 'r 42',
      ',' => 'r 42',
      '=>' => 'r 42',
      ']' => 'r 42',
      '}}' => 'r 42',
      '}' => 'r 42'
    ),
    array(
      'exp' => 's 37',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '..' => 'r 43',
      '||' => 'r 43',
      'OR' => 'r 43',
      'XOR' => 'r 43',
      '&&' => 'r 43',
      'AND' => 'r 43',
      '==' => 'r 43',
      '!=' => 'r 43',
      '<' => 'r 43',
      '>' => 'r 43',
      '<=' => 'r 43',
      '>=' => 'r 43',
      '+' => 'r 43',
      '-' => 'r 43',
      '&' => 's 40',
      '*' => 's 42',
      '/' => 's 44',
      '%' => 's 46',
      '-->' => 'r 43',
      ')' => 'r 43',
      ',' => 'r 43',
      '=>' => 'r 43',
      ']' => 'r 43',
      '}}' => 'r 43',
      '}' => 'r 43'
    ),
    array(
      'exp' => 's 39',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '..' => 'r 44',
      '||' => 'r 44',
      'OR' => 'r 44',
      'XOR' => 'r 44',
      '&&' => 'r 44',
      'AND' => 'r 44',
      '==' => 'r 44',
      '!=' => 'r 44',
      '<' => 'r 44',
      '>' => 'r 44',
      '<=' => 'r 44',
      '>=' => 'r 44',
      '+' => 'r 44',
      '-' => 'r 44',
      '&' => 's 40',
      '*' => 's 42',
      '/' => 's 44',
      '%' => 's 46',
      '-->' => 'r 44',
      ')' => 'r 44',
      ',' => 'r 44',
      '=>' => 'r 44',
      ']' => 'r 44',
      '}}' => 'r 44',
      '}' => 'r 44'
    ),
    array(
      'exp' => 's 41',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '..' => 'r 45',
      '||' => 'r 45',
      'OR' => 'r 45',
      'XOR' => 'r 45',
      '&&' => 'r 45',
      'AND' => 'r 45',
      '==' => 'r 45',
      '!=' => 'r 45',
      '<' => 'r 45',
      '>' => 'r 45',
      '<=' => 'r 45',
      '>=' => 'r 45',
      '+' => 'r 45',
      '-' => 'r 45',
      '&' => 'r 45',
      '*' => 's 42',
      '/' => 's 44',
      '%' => 's 46',
      '-->' => 'r 45',
      ')' => 'r 45',
      ',' => 'r 45',
      '=>' => 'r 45',
      ']' => 'r 45',
      '}}' => 'r 45',
      '}' => 'r 45'
    ),
    array(
      'exp' => 's 43',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '' => 'r 46'
    ),
    array(
      'exp' => 's 45',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '' => 'r 47'
    ),
    array(
      'exp' => 's 47',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '' => 'r 48'
    ),
    array(
      '' => 'r 49'
    ),
    array(
      '' => 'r 50'
    ),
    array(
      'p11' => 's 51',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '' => 'r 51'
    ),
    array(
      '' => 'r 52'
    ),
    array(
      'exp' => 's 54',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '..' => 's 12',
      '||' => 's 14',
      'OR' => 's 16',
      'XOR' => 's 18',
      '&&' => 's 20',
      'AND' => 's 22',
      '==' => 's 24',
      '!=' => 's 26',
      '<' => 's 28',
      '>' => 's 30',
      '<=' => 's 32',
      '>=' => 's 34',
      '+' => 's 36',
      '-' => 's 38',
      '&' => 's 40',
      '*' => 's 42',
      '/' => 's 44',
      '%' => 's 46',
      ')' => 's 55'
    ),
    array(
      'varpath' => 's 56',
      '.' => 'r 82',
      '[' => 'r 82',
      '%' => 'r 82',
      '/' => 'r 82',
      '*' => 'r 82',
      '&' => 'r 82',
      '-' => 'r 82',
      '+' => 'r 82',
      '>=' => 'r 82',
      '<=' => 'r 82',
      '>' => 'r 82',
      '<' => 'r 82',
      '!=' => 'r 82',
      '==' => 'r 82',
      'AND' => 'r 82',
      '&&' => 'r 82',
      'XOR' => 'r 82',
      'OR' => 'r 82',
      '||' => 'r 82',
      '..' => 'r 82',
      '-->' => 'r 82',
      ')' => 'r 82',
      ',' => 'r 82',
      '=>' => 'r 82',
      ']' => 'r 82',
      '}}' => 'r 82',
      '}' => 'r 82'
    ),
    array(
      '.' => 's 57',
      '[' => 's 73',
      'varpart' => 's 117',
      '%' => 'r 53',
      '/' => 'r 53',
      '*' => 'r 53',
      '&' => 'r 53',
      '-' => 'r 53',
      '+' => 'r 53',
      '>=' => 'r 53',
      '<=' => 'r 53',
      '>' => 'r 53',
      '<' => 'r 53',
      '!=' => 'r 53',
      '==' => 'r 53',
      'AND' => 'r 53',
      '&&' => 'r 53',
      'XOR' => 'r 53',
      'OR' => 'r 53',
      '||' => 'r 53',
      '..' => 'r 53',
      '-->' => 'r 53',
      ')' => 'r 53',
      ',' => 'r 53',
      '=>' => 'r 53',
      ']' => 'r 53',
      '}}' => 'r 53',
      '}' => 'r 53'
    ),
    array(
      'namekw' => 's 58',
      'name' => 's 101',
      'IF' => 's 102',
      'END' => 's 103',
      'ELSE' => 's 104',
      'ELSIF' => 's 105',
      'ELSEIF' => 's 106',
      'SET' => 's 107',
      'OR' => 's 108',
      'XOR' => 's 109',
      'AND' => 's 110',
      'NOT' => 's 111',
      'FUNCTION' => 's 112',
      'BLOCK' => 's 113',
      'MACRO' => 's 114',
      'FOR' => 's 115',
      'FOREACH' => 's 116'
    ),
    array(
      '(' => 's 59',
      '.' => 'r 78',
      '[' => 'r 78',
      '%' => 'r 78',
      '/' => 'r 78',
      '*' => 'r 78',
      '&' => 'r 78',
      '-' => 'r 78',
      '+' => 'r 78',
      '>=' => 'r 78',
      '<=' => 'r 78',
      '>' => 'r 78',
      '<' => 'r 78',
      '!=' => 'r 78',
      '==' => 'r 78',
      'AND' => 'r 78',
      '&&' => 'r 78',
      'XOR' => 'r 78',
      'OR' => 'r 78',
      '||' => 'r 78',
      '..' => 'r 78',
      '-->' => 'r 78',
      ')' => 'r 78',
      ',' => 'r 78',
      '=>' => 'r 78',
      '=' => 'r 78',
      ']' => 'r 78',
      '}}' => 'r 78',
      '}' => 'r 78'
    ),
    array(
      'exp' => 's 60',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76',
      ')' => 's 98',
      'list' => 's 99'
    ),
    array(
      '..' => 's 12',
      '||' => 's 14',
      'OR' => 's 16',
      'XOR' => 's 18',
      '&&' => 's 20',
      'AND' => 's 22',
      '==' => 's 24',
      '!=' => 's 26',
      '<' => 's 28',
      '>' => 's 30',
      '<=' => 's 32',
      '>=' => 's 34',
      '+' => 's 36',
      '-' => 's 38',
      '&' => 's 40',
      '*' => 's 42',
      '/' => 's 44',
      '%' => 's 46',
      ',' => 's 61',
      ')' => 'r 63'
    ),
    array(
      'exp' => 's 60',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76',
      'list' => 's 97'
    ),
    array(
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'p11' => 's 63',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '' => 'r 54'
    ),
    array(
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      'p11' => 's 65',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '' => 'r 55'
    ),
    array(
      'exp' => 's 67',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'hash' => 's 91',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76',
      'pair' => 's 93',
      'gtpair' => 's 96',
      '}' => 'r 70'
    ),
    array(
      '..' => 's 12',
      '||' => 's 14',
      'OR' => 's 16',
      'XOR' => 's 18',
      '&&' => 's 20',
      'AND' => 's 22',
      '==' => 's 24',
      '!=' => 's 26',
      '<' => 's 28',
      '>' => 's 30',
      '<=' => 's 32',
      '>=' => 's 34',
      '+' => 's 36',
      '-' => 's 38',
      '&' => 's 40',
      '*' => 's 42',
      '/' => 's 44',
      '%' => 's 46',
      ',' => 's 68',
      '=>' => 's 79'
    ),
    array(
      'exp' => 's 69',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '..' => 's 12',
      '||' => 's 14',
      'OR' => 's 16',
      'XOR' => 's 18',
      '&&' => 's 20',
      'AND' => 's 22',
      '==' => 's 24',
      '!=' => 's 26',
      '<' => 's 28',
      '>' => 's 30',
      '<=' => 's 32',
      '>=' => 's 34',
      '+' => 's 36',
      '-' => 's 38',
      '&' => 's 40',
      '*' => 's 42',
      '/' => 's 44',
      '%' => 's 46',
      ',' => 'r 73',
      '}' => 'r 73'
    ),
    array(
      '' => 'r 57'
    ),
    array(
      'varpart' => 's 72',
      '.' => 's 57',
      '[' => 's 73',
      '%' => 'r 58',
      '/' => 'r 58',
      '*' => 'r 58',
      '&' => 'r 58',
      '-' => 'r 58',
      '+' => 'r 58',
      '>=' => 'r 58',
      '<=' => 'r 58',
      '>' => 'r 58',
      '<' => 'r 58',
      '!=' => 'r 58',
      '==' => 'r 58',
      'AND' => 'r 58',
      '&&' => 'r 58',
      'XOR' => 'r 58',
      'OR' => 'r 58',
      '||' => 'r 58',
      '..' => 'r 58',
      '-->' => 'r 58',
      ')' => 'r 58',
      ',' => 'r 58',
      '=>' => 'r 58',
      ']' => 'r 58',
      '}}' => 'r 58',
      '}' => 'r 58'
    ),
    array(
      '' => 'r 77'
    ),
    array(
      'exp' => 's 74',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '..' => 's 12',
      '||' => 's 14',
      'OR' => 's 16',
      'XOR' => 's 18',
      '&&' => 's 20',
      'AND' => 's 22',
      '==' => 's 24',
      '!=' => 's 26',
      '<' => 's 28',
      '>' => 's 30',
      '<=' => 's 32',
      '>=' => 's 34',
      '+' => 's 36',
      '-' => 's 38',
      '&' => 's 40',
      '*' => 's 42',
      '/' => 's 44',
      '%' => 's 46',
      ']' => 's 75'
    ),
    array(
      '' => 'r 79'
    ),
    array(
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76',
      '(' => 's 77',
      'nonbrace' => 's 90',
      '.' => 'r 76',
      '[' => 'r 76',
      '%' => 'r 76',
      '/' => 'r 76',
      '*' => 'r 76',
      '&' => 'r 76',
      '-' => 'r 76',
      '+' => 'r 76',
      '>=' => 'r 76',
      '<=' => 'r 76',
      '>' => 'r 76',
      '<' => 'r 76',
      '!=' => 'r 76',
      '==' => 'r 76',
      'AND' => 'r 76',
      '&&' => 'r 76',
      'XOR' => 'r 76',
      'OR' => 'r 76',
      '||' => 'r 76',
      '..' => 'r 76',
      '-->' => 'r 76',
      ')' => 'r 76',
      ',' => 'r 76',
      '=>' => 'r 76',
      ']' => 'r 76',
      '}}' => 'r 76',
      '}' => 'r 76'
    ),
    array(
      'exp' => 's 78',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76',
      ')' => 's 81',
      'list' => 's 82',
      'gthash' => 's 84',
      'gtpair' => 's 86'
    ),
    array(
      '..' => 's 12',
      '||' => 's 14',
      'OR' => 's 16',
      'XOR' => 's 18',
      '&&' => 's 20',
      'AND' => 's 22',
      '==' => 's 24',
      '!=' => 's 26',
      '<' => 's 28',
      '>' => 's 30',
      '<=' => 's 32',
      '>=' => 's 34',
      '+' => 's 36',
      '-' => 's 38',
      '&' => 's 40',
      '*' => 's 42',
      '/' => 's 44',
      '%' => 's 46',
      ',' => 's 61',
      '=>' => 's 79',
      ')' => 'r 63'
    ),
    array(
      'exp' => 's 80',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '..' => 's 12',
      '||' => 's 14',
      'OR' => 's 16',
      'XOR' => 's 18',
      '&&' => 's 20',
      'AND' => 's 22',
      '==' => 's 24',
      '!=' => 's 26',
      '<' => 's 28',
      '>' => 's 30',
      '<=' => 's 32',
      '>=' => 's 34',
      '+' => 's 36',
      '-' => 's 38',
      '&' => 's 40',
      '*' => 's 42',
      '/' => 's 44',
      '%' => 's 46',
      ',' => 'r 75',
      '}' => 'r 75',
      ')' => 'r 75'
    ),
    array(
      '' => 'r 59'
    ),
    array(
      ')' => 's 83'
    ),
    array(
      '' => 'r 60'
    ),
    array(
      ')' => 's 85'
    ),
    array(
      '' => 'r 61'
    ),
    array(
      ',' => 's 87',
      ')' => 'r 71'
    ),
    array(
      'exp' => 's 88',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76',
      'gtpair' => 's 86',
      'gthash' => 's 89'
    ),
    array(
      '..' => 's 12',
      '||' => 's 14',
      'OR' => 's 16',
      'XOR' => 's 18',
      '&&' => 's 20',
      'AND' => 's 22',
      '==' => 's 24',
      '!=' => 's 26',
      '<' => 's 28',
      '>' => 's 30',
      '<=' => 's 32',
      '>=' => 's 34',
      '+' => 's 36',
      '-' => 's 38',
      '&' => 's 40',
      '*' => 's 42',
      '/' => 's 44',
      '%' => 's 46',
      '=>' => 's 79'
    ),
    array(
      '' => 'r 72'
    ),
    array(
      '' => 'r 62'
    ),
    array(
      '}' => 's 92'
    ),
    array(
      '' => 'r 56'
    ),
    array(
      ',' => 's 94',
      '}' => 'r 68'
    ),
    array(
      'exp' => 's 67',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76',
      'pair' => 's 93',
      'hash' => 's 95',
      'gtpair' => 's 96',
      '}' => 'r 70'
    ),
    array(
      '' => 'r 69'
    ),
    array(
      '' => 'r 74'
    ),
    array(
      '' => 'r 64'
    ),
    array(
      '' => 'r 80'
    ),
    array(
      ')' => 's 100'
    ),
    array(
      '' => 'r 81'
    ),
    array(
      '' => 'r 84'
    ),
    array(
      '' => 'r 85'
    ),
    array(
      '' => 'r 86'
    ),
    array(
      '' => 'r 87'
    ),
    array(
      '' => 'r 88'
    ),
    array(
      '' => 'r 89'
    ),
    array(
      '' => 'r 90'
    ),
    array(
      '' => 'r 91'
    ),
    array(
      '' => 'r 92'
    ),
    array(
      '' => 'r 93'
    ),
    array(
      '' => 'r 94'
    ),
    array(
      '' => 'r 95'
    ),
    array(
      '' => 'r 96'
    ),
    array(
      '' => 'r 97'
    ),
    array(
      '' => 'r 98'
    ),
    array(
      '' => 'r 99'
    ),
    array(
      '' => 'r 83'
    ),
    array(
      'exp' => 's 119',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '-->' => 's 120',
      '..' => 's 12',
      '||' => 's 14',
      'OR' => 's 16',
      'XOR' => 's 18',
      '&&' => 's 20',
      'AND' => 's 22',
      '==' => 's 24',
      '!=' => 's 26',
      '<' => 's 28',
      '>' => 's 30',
      '<=' => 's 32',
      '>=' => 's 34',
      '+' => 's 36',
      '-' => 's 38',
      '&' => 's 40',
      '*' => 's 42',
      '/' => 's 44',
      '%' => 's 46'
    ),
    array(
      'chunks' => 's 121',
      'literal' => 'r 1',
      '<!--' => 'r 1',
      '{{' => 'r 1'
    ),
    array(
      'chunk' => 's 2',
      'literal' => 's 3',
      '<!--' => 's 122',
      '{{' => 's 161',
      'error' => 's 164',
      'c_elseifs' => 's 175'
    ),
    array(
      'code_chunk' => 's 5',
      'c_if' => 's 7',
      'c_set' => 's 8',
      'c_fn' => 's 9',
      'c_for' => 's 10',
      'exp' => 's 11',
      'IF' => 's 118',
      'END' => 's 123',
      'ELSE' => 's 124',
      'elseif' => 's 170',
      'SET' => 's 129',
      'fn' => 's 137',
      'for' => 's 148',
      'FUNCTION' => 's 156',
      'BLOCK' => 's 157',
      'MACRO' => 's 158',
      'FOR' => 's 159',
      'FOREACH' => 's 160',
      'ELSIF' => 's 173',
      'ELSEIF' => 's 174',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '' => 'r 12'
    ),
    array(
      '-->' => 's 125',
      'IF' => 's 169'
    ),
    array(
      'chunks' => 's 126',
      'literal' => 'r 1',
      '<!--' => 'r 1',
      '{{' => 'r 1'
    ),
    array(
      'chunk' => 's 2',
      'literal' => 's 3',
      '<!--' => 's 127',
      '{{' => 's 161',
      'error' => 's 164'
    ),
    array(
      'code_chunk' => 's 5',
      'c_if' => 's 7',
      'c_set' => 's 8',
      'c_fn' => 's 9',
      'c_for' => 's 10',
      'exp' => 's 11',
      'IF' => 's 118',
      'END' => 's 128',
      'SET' => 's 129',
      'fn' => 's 137',
      'for' => 's 148',
      'FUNCTION' => 's 156',
      'BLOCK' => 's 157',
      'MACRO' => 's 158',
      'FOR' => 's 159',
      'FOREACH' => 's 160',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '' => 'r 13'
    ),
    array(
      'varref' => 's 130',
      'name' => 's 165'
    ),
    array(
      '=' => 's 131',
      '-->' => 's 133',
      'varpart' => 's 72',
      '.' => 's 57',
      '[' => 's 73'
    ),
    array(
      'exp' => 's 132',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '..' => 's 12',
      '||' => 's 14',
      'OR' => 's 16',
      'XOR' => 's 18',
      '&&' => 's 20',
      'AND' => 's 22',
      '==' => 's 24',
      '!=' => 's 26',
      '<' => 's 28',
      '>' => 's 30',
      '<=' => 's 32',
      '>=' => 's 34',
      '+' => 's 36',
      '-' => 's 38',
      '&' => 's 40',
      '*' => 's 42',
      '/' => 's 44',
      '%' => 's 46',
      '-->' => 'r 18'
    ),
    array(
      'chunks' => 's 134',
      'literal' => 'r 1',
      '<!--' => 'r 1',
      '{{' => 'r 1'
    ),
    array(
      'chunk' => 's 2',
      'literal' => 's 3',
      '<!--' => 's 135',
      '{{' => 's 161',
      'error' => 's 164'
    ),
    array(
      'code_chunk' => 's 5',
      'c_if' => 's 7',
      'c_set' => 's 8',
      'c_fn' => 's 9',
      'c_for' => 's 10',
      'exp' => 's 11',
      'IF' => 's 118',
      'SET' => 's 129',
      'END' => 's 136',
      'fn' => 's 137',
      'for' => 's 148',
      'FUNCTION' => 's 156',
      'BLOCK' => 's 157',
      'MACRO' => 's 158',
      'FOR' => 's 159',
      'FOREACH' => 's 160',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '' => 'r 19'
    ),
    array(
      'name' => 's 138'
    ),
    array(
      '(' => 's 139'
    ),
    array(
      'arglist' => 's 140',
      'name' => 's 166',
      ')' => 'r 67'
    ),
    array(
      ')' => 's 141'
    ),
    array(
      '=' => 's 142',
      '-->' => 's 144'
    ),
    array(
      'exp' => 's 143',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '..' => 's 12',
      '||' => 's 14',
      'OR' => 's 16',
      'XOR' => 's 18',
      '&&' => 's 20',
      'AND' => 's 22',
      '==' => 's 24',
      '!=' => 's 26',
      '<' => 's 28',
      '>' => 's 30',
      '<=' => 's 32',
      '>=' => 's 34',
      '+' => 's 36',
      '-' => 's 38',
      '&' => 's 40',
      '*' => 's 42',
      '/' => 's 44',
      '%' => 's 46',
      '-->' => 'r 20'
    ),
    array(
      'chunks' => 's 145',
      'literal' => 'r 1',
      '<!--' => 'r 1',
      '{{' => 'r 1'
    ),
    array(
      'chunk' => 's 2',
      'literal' => 's 3',
      '<!--' => 's 146',
      '{{' => 's 161',
      'error' => 's 164'
    ),
    array(
      'code_chunk' => 's 5',
      'c_if' => 's 7',
      'c_set' => 's 8',
      'c_fn' => 's 9',
      'c_for' => 's 10',
      'exp' => 's 11',
      'IF' => 's 118',
      'SET' => 's 129',
      'fn' => 's 137',
      'END' => 's 147',
      'for' => 's 148',
      'FUNCTION' => 's 156',
      'BLOCK' => 's 157',
      'MACRO' => 's 158',
      'FOR' => 's 159',
      'FOREACH' => 's 160',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '' => 'r 21'
    ),
    array(
      'varref' => 's 149',
      'name' => 's 165'
    ),
    array(
      '=' => 's 150',
      'varpart' => 's 72',
      '.' => 's 57',
      '[' => 's 73'
    ),
    array(
      'exp' => 's 151',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '-->' => 's 152',
      '..' => 's 12',
      '||' => 's 14',
      'OR' => 's 16',
      'XOR' => 's 18',
      '&&' => 's 20',
      'AND' => 's 22',
      '==' => 's 24',
      '!=' => 's 26',
      '<' => 's 28',
      '>' => 's 30',
      '<=' => 's 32',
      '>=' => 's 34',
      '+' => 's 36',
      '-' => 's 38',
      '&' => 's 40',
      '*' => 's 42',
      '/' => 's 44',
      '%' => 's 46'
    ),
    array(
      'chunks' => 's 153',
      'literal' => 'r 1',
      '<!--' => 'r 1',
      '{{' => 'r 1'
    ),
    array(
      'chunk' => 's 2',
      'literal' => 's 3',
      '<!--' => 's 154',
      '{{' => 's 161',
      'error' => 's 164'
    ),
    array(
      'code_chunk' => 's 5',
      'c_if' => 's 7',
      'c_set' => 's 8',
      'c_fn' => 's 9',
      'c_for' => 's 10',
      'exp' => 's 11',
      'IF' => 's 118',
      'SET' => 's 129',
      'fn' => 's 137',
      'for' => 's 148',
      'END' => 's 155',
      'FUNCTION' => 's 156',
      'BLOCK' => 's 157',
      'MACRO' => 's 158',
      'FOR' => 's 159',
      'FOREACH' => 's 160',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '' => 'r 22'
    ),
    array(
      '' => 'r 23'
    ),
    array(
      '' => 'r 24'
    ),
    array(
      '' => 'r 25'
    ),
    array(
      '' => 'r 26'
    ),
    array(
      '' => 'r 27'
    ),
    array(
      'exp' => 's 162',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '}}' => 's 163',
      '..' => 's 12',
      '||' => 's 14',
      'OR' => 's 16',
      'XOR' => 's 18',
      '&&' => 's 20',
      'AND' => 's 22',
      '==' => 's 24',
      '!=' => 's 26',
      '<' => 's 28',
      '>' => 's 30',
      '<=' => 's 32',
      '>=' => 's 34',
      '+' => 's 36',
      '-' => 's 38',
      '&' => 's 40',
      '*' => 's 42',
      '/' => 's 44',
      '%' => 's 46'
    ),
    array(
      '' => 'r 5'
    ),
    array(
      '' => 'r 6'
    ),
    array(
      '' => 'r 76'
    ),
    array(
      ',' => 's 167',
      ')' => 'r 65'
    ),
    array(
      'name' => 's 166',
      'arglist' => 's 168',
      ')' => 'r 67'
    ),
    array(
      '' => 'r 66'
    ),
    array(
      '' => 'r 28'
    ),
    array(
      'exp' => 's 171',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '-->' => 's 172',
      '..' => 's 12',
      '||' => 's 14',
      'OR' => 's 16',
      'XOR' => 's 18',
      '&&' => 's 20',
      'AND' => 's 22',
      '==' => 's 24',
      '!=' => 's 26',
      '<' => 's 28',
      '>' => 's 30',
      '<=' => 's 32',
      '>=' => 's 34',
      '+' => 's 36',
      '-' => 's 38',
      '&' => 's 40',
      '*' => 's 42',
      '/' => 's 44',
      '%' => 's 46'
    ),
    array(
      '' => 'r 16'
    ),
    array(
      '' => 'r 29'
    ),
    array(
      '' => 'r 30'
    ),
    array(
      'chunks' => 's 176',
      'literal' => 'r 1',
      '<!--' => 'r 1',
      '{{' => 'r 1'
    ),
    array(
      'chunk' => 's 2',
      'literal' => 's 3',
      '<!--' => 's 177',
      '{{' => 's 161',
      'error' => 's 164'
    ),
    array(
      'code_chunk' => 's 5',
      'c_if' => 's 7',
      'c_set' => 's 8',
      'c_fn' => 's 9',
      'c_for' => 's 10',
      'exp' => 's 11',
      'IF' => 's 118',
      'END' => 's 178',
      'ELSE' => 's 179',
      'elseif' => 's 184',
      'SET' => 's 129',
      'fn' => 's 137',
      'for' => 's 148',
      'FUNCTION' => 's 156',
      'BLOCK' => 's 157',
      'MACRO' => 's 158',
      'FOR' => 's 159',
      'FOREACH' => 's 160',
      'ELSIF' => 's 173',
      'ELSEIF' => 's 174',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '' => 'r 14'
    ),
    array(
      '-->' => 's 180',
      'IF' => 's 169'
    ),
    array(
      'chunks' => 's 181',
      'literal' => 'r 1',
      '<!--' => 'r 1',
      '{{' => 'r 1'
    ),
    array(
      'chunk' => 's 2',
      'literal' => 's 3',
      '<!--' => 's 182',
      '{{' => 's 161',
      'error' => 's 164'
    ),
    array(
      'code_chunk' => 's 5',
      'c_if' => 's 7',
      'c_set' => 's 8',
      'c_fn' => 's 9',
      'c_for' => 's 10',
      'exp' => 's 11',
      'IF' => 's 118',
      'END' => 's 183',
      'SET' => 's 129',
      'fn' => 's 137',
      'for' => 's 148',
      'FUNCTION' => 's 156',
      'BLOCK' => 's 157',
      'MACRO' => 's 158',
      'FOR' => 's 159',
      'FOREACH' => 's 160',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '' => 'r 15'
    ),
    array(
      'exp' => 's 185',
      'p10' => 's 48',
      'p11' => 's 49',
      '-' => 's 50',
      'nonbrace' => 's 52',
      '(' => 's 53',
      '!' => 's 62',
      'NOT' => 's 64',
      '{' => 's 66',
      'literal' => 's 70',
      'varref' => 's 71',
      'name' => 's 76'
    ),
    array(
      '-->' => 's 186',
      '..' => 's 12',
      '||' => 's 14',
      'OR' => 's 16',
      'XOR' => 's 18',
      '&&' => 's 20',
      'AND' => 's 22',
      '==' => 's 24',
      '!=' => 's 26',
      '<' => 's 28',
      '>' => 's 30',
      '<=' => 's 32',
      '>=' => 's 34',
      '+' => 's 36',
      '-' => 's 38',
      '&' => 's 40',
      '*' => 's 42',
      '/' => 's 44',
      '%' => 's 46'
    ),
    array(
      '' => 'r 17'
    ),
    array(
      '' => 'r 100'
    )
  );
  public $d = array(
    '..' => "concatenation operator '..'",
    '||' => "OR operator '||'",
    'OR' => "OR operator 'OR'",
    'XOR' => "XOR operator 'XOR'",
    'AND' => "AND operator 'AND'",
    '&&' => "AND operator '&&'",
    '&' => "bitwise AND operator '&'",
    '==' => "equality operator '=='",
    '!=' => "non-equality operator '!='",
    '<' => "less than operator '<'",
    '>' => "greater than operator '>'",
    '<=' => "less or equal operator '<='",
    '>=' => "greater or equal operator '>='",
    '+' => "plus operator '+'",
    '-' => "minus operator '-'",
    '*' => "multiply operator '*'",
    '/' => "divide operator '/'",
    '%' => "mod operator '%'",
    '(' => "left round brace '('",
    ')' => "right round brace '('",
    '!' => "NOT operator '!'",
    'NOT' => "NOT operator 'NOT'",
    '{' => "left curly brace '{'",
    '}' => "right curly brace '}'",
    ',' => "comma ','",
    '=>' => "hash item operator '=>'",
    '[' => "left square brace '['",
    ']' => "right square brace ']'",
    '<!--' => 'directive begin',
    '-->' => 'directive end',
    '{{' => 'substitution begin',
    '}}' => 'substitution end'
  );
  public $errors = array();
  function reduce_0_template_1($tokens, &$result) {
    // (0) template :=  chunks
    $result = reset($tokens);

    $this->template->st->functions['main']['body'] = "function fn_main() {\$stack = array();\n\$t = '';\n".$tokens[0]."\nreturn \$t;\n}\n";
    $result = '';
  }

  function reduce_1_chunks_1($tokens, &$result) {
    // (1) chunks :=  ε
    $result = reset($tokens);

    $result = '';
  }

  function reduce_2_chunks_2($tokens, &$result) {
    // (2) chunks :=  chunks  chunk
    $result = reset($tokens);

    $result = $tokens[0] . "# line ".$this->template->lexer->lineno."\n" . $tokens[1];
  }

  function reduce_3_chunk_1($tokens, &$result) {
    // (3) chunk :=  literal
    $result = reset($tokens);

    $result = ($tokens[0] != "''" && $tokens[0] != '""' ? '$t .= ' . $tokens[0] . ";\n" : '');
  }

  function reduce_4_chunk_2($tokens, &$result) {
    // (4) chunk :=  <!--  code_chunk  -->
    $result = reset($tokens);
    $c = &$tokens[1];

    $result = $c;
  }

  function reduce_5_chunk_3($tokens, &$result) {
    // (5) chunk :=  {{  exp  }}
    $result = reset($tokens);
    $e = &$tokens[1];

    $result = '$t .= ' . ($e[1] || !$this->template->options->auto_escape ? $e[0] : $this->template->compile_function($this->template->options->auto_escape, [ $e ])[0]) . ";\n";
  }

  function reduce_6_chunk_4($tokens, &$result) {
    // (6) chunk :=  error
    $result = reset($tokens);
    $e = &$tokens[0];

    $result = '';
  }

  function reduce_7_code_chunk_1($tokens, &$result) {
    // (7) code_chunk :=  c_if
    $result = $tokens[0];
  }

  function reduce_8_code_chunk_2($tokens, &$result) {
    // (8) code_chunk :=  c_set
    $result = $tokens[0];
  }

  function reduce_9_code_chunk_3($tokens, &$result) {
    // (9) code_chunk :=  c_fn
    $result = $tokens[0];
  }

  function reduce_10_code_chunk_4($tokens, &$result) {
    // (10) code_chunk :=  c_for
    $result = $tokens[0];
  }

  function reduce_11_code_chunk_5($tokens, &$result) {
    // (11) code_chunk :=  exp
    $result = reset($tokens);
    $e = &$tokens[0];

    $result = '$t .= ' . ($e[1] || !$this->template->options->auto_escape ? $e[0] : $this->template->compile_function($this->template->options->auto_escape, [ $e ])[0]) . ";\n";
  }

  function reduce_12_c_if_1($tokens, &$result) {
    // (12) c_if :=  IF  exp  -->  chunks  <!--  END
    $result = reset($tokens);
    $e = &$tokens[1];
    $if = &$tokens[3];

    $result = "if (" . $e[0] . ") {\n" . $if . "}\n";
  }

  function reduce_13_c_if_2($tokens, &$result) {
    // (13) c_if :=  IF  exp  -->  chunks  <!--  ELSE  -->  chunks  <!--  END
    $result = reset($tokens);
    $e = &$tokens[1];
    $if = &$tokens[3];
    $else = &$tokens[7];

    $result = "if (" . $e[0] . ") {\n" . $if . "} else {\n" . $else . "}\n";
  }

  function reduce_14_c_if_3($tokens, &$result) {
    // (14) c_if :=  IF  exp  -->  chunks  c_elseifs  chunks  <!--  END
    $result = reset($tokens);
    $e = &$tokens[1];
    $if = &$tokens[3];
    $ei = &$tokens[4];
    $ec = &$tokens[5];

    $result = "if (" . $e[0] . ") {\n" . $if . $ei . $ec . "}\n";
  }

  function reduce_15_c_if_4($tokens, &$result) {
    // (15) c_if :=  IF  exp  -->  chunks  c_elseifs  chunks  <!--  ELSE  -->  chunks  <!--  END
    $result = reset($tokens);
    $e = &$tokens[1];
    $if = &$tokens[3];
    $ei = &$tokens[4];
    $ec = &$tokens[5];
    $else = &$tokens[9];

    $result = "if (" . $e[0] . ") {\n" . $if . $ei . $ec . "} else {\n" . $else . "}\n";
  }

  function reduce_16_c_elseifs_1($tokens, &$result) {
    // (16) c_elseifs :=  <!--  elseif  exp  -->
    $result = reset($tokens);
    $e = &$tokens[2];

    $result = "} elseif (" . $e[0] . ") {\n";
  }

  function reduce_17_c_elseifs_2($tokens, &$result) {
    // (17) c_elseifs :=  c_elseifs  chunks  <!--  elseif  exp  -->
    $result = reset($tokens);
    $p = &$tokens[0];
    $cs = &$tokens[1];
    $e = &$tokens[4];

    $result = $p . $cs . "} elseif (" . $e[0] . ") {\n";
  }

  function reduce_18_c_set_1($tokens, &$result) {
    // (18) c_set :=  SET  varref  =  exp
    $result = reset($tokens);
    $v = &$tokens[1];
    $e = &$tokens[3];

    $result = $v[0] . ' = ' . $e[0] . ";\n";
  }

  function reduce_19_c_set_2($tokens, &$result) {
    // (19) c_set :=  SET  varref  -->  chunks  <!--  END
    $result = reset($tokens);
    $v = &$tokens[1];
    $cs = &$tokens[3];

    $result = "\$stack[] = \$t;\n\$t = '';\n" . $cs . $v[0] . " = \$t;\n\$t = array_pop(\$stack);\n";
  }

  function reduce_20_c_fn_1($tokens, &$result) {
    // (20) c_fn :=  fn  name  (  arglist  )  =  exp
    $result = reset($tokens);
    $name = &$tokens[1];
    $args = &$tokens[3];
    $exp = &$tokens[6];

    $this->template->st->functions[$name] = array(
      'name' => $name,
      'args' => $args,
      'body' => 'function fn_'.$name." () {\nreturn ".$exp.";\n}\n",
      //'line' => $line, Ой, я чо - аргументы не юзаю?
      //'pos' => $pos,
    );
    $result = '';
  }

  function reduce_21_c_fn_2($tokens, &$result) {
    // (21) c_fn :=  fn  name  (  arglist  )  -->  chunks  <!--  END
    $result = reset($tokens);
    $name = &$tokens[1];
    $args = &$tokens[3];
    $cs = &$tokens[6];

    $this->template->st->functions[$name] = array(
      'name' => $name,
      'args' => $args,
      'body' => 'function fn_'.$name." () {\$stack = array();\n\$t = '';\n".$cs."\nreturn \$t;\n}\n",
      //'line' => $line,
      //'pos' => $pos,
    );
    $result = '';
  }

  function reduce_22_c_for_1($tokens, &$result) {
    // (22) c_for :=  for  varref  =  exp  -->  chunks  <!--  END
    $result = reset($tokens);
    $varref = &$tokens[1];
    $exp = &$tokens[3];
    $cs = &$tokens[5];

        $varref_index = substr($varref[0], 0, -1) . ".'_index']";
        $result = "\$stack[] = ".$varref[0].";
    \$stack[] = ".$varref_index.";
    \$stack[] = 0;
    foreach ((array)($exp[0]) as \$item) {
    ".$varref[0]." = \$item;
    ".$varref_index." = \$stack[count(\$stack)-1]++;
    ".$cs."}
    array_pop(\$stack);
    ".$varref_index." = array_pop(\$stack);
    ".$varref[0]." = array_pop(\$stack);
    ";
  }

  function reduce_23_fn_1($tokens, &$result) {
    // (23) fn :=  FUNCTION
    $result = reset($tokens);
  }

  function reduce_24_fn_2($tokens, &$result) {
    // (24) fn :=  BLOCK
    $result = reset($tokens);
  }

  function reduce_25_fn_3($tokens, &$result) {
    // (25) fn :=  MACRO
    $result = reset($tokens);
  }

  function reduce_26_for_1($tokens, &$result) {
    // (26) for :=  FOR
    $result = reset($tokens);
  }

  function reduce_27_for_2($tokens, &$result) {
    // (27) for :=  FOREACH
    $result = reset($tokens);
  }

  function reduce_28_elseif_1($tokens, &$result) {
    // (28) elseif :=  ELSE  IF
    $result = reset($tokens);
  }

  function reduce_29_elseif_2($tokens, &$result) {
    // (29) elseif :=  ELSIF
    $result = reset($tokens);
  }

  function reduce_30_elseif_3($tokens, &$result) {
    // (30) elseif :=  ELSEIF
    $result = reset($tokens);
  }

  function reduce_31_exp_1($tokens, &$result) {
    // (31) exp :=  exp  ..  exp
    $result = reset($tokens);
    $a = &$tokens[0];
    $b = &$tokens[2];

    $result = [ '(' . $a[0] . ' . ' . $b[0] . ')', $a[1] && $b[1] ];
  }

  function reduce_32_exp_2($tokens, &$result) {
    // (32) exp :=  exp  ||  exp
    $result = reset($tokens);
    $a = &$tokens[0];
    $b = &$tokens[2];

    $result = [ '(' . $a[0] . ' ?: ' . $b[0] . ')', $a[1] && $b[1] ];
  }

  function reduce_33_exp_3($tokens, &$result) {
    // (33) exp :=  exp  OR  exp
    $result = reset($tokens);
    $a = &$tokens[0];
    $b = &$tokens[2];

    $result = [ '(' . $a[0] . ' ?: ' . $b[0] . ')', $a[1] && $b[1] ];
  }

  function reduce_34_exp_4($tokens, &$result) {
    // (34) exp :=  exp  XOR  exp
    $result = reset($tokens);
    $a = &$tokens[0];
    $b = &$tokens[2];

    $result = [ '(' . $a[0] . ' XOR ' . $b[0] . ')', true ];
  }

  function reduce_35_exp_5($tokens, &$result) {
    // (35) exp :=  exp  &&  exp
    $result = reset($tokens);
    $a = &$tokens[0];
    $b = &$tokens[2];

    $result = [ '(' . $a[0] . ' && ' . $b[0] . ')', true ];
  }

  function reduce_36_exp_6($tokens, &$result) {
    // (36) exp :=  exp  AND  exp
    $result = reset($tokens);
    $a = &$tokens[0];
    $b = &$tokens[2];

    $result = [ '(' . $a[0] . ' && ' . $b[0] . ')', true ];
  }

  function reduce_37_exp_7($tokens, &$result) {
    // (37) exp :=  exp  ==  exp
    $result = reset($tokens);
    $a = &$tokens[0];
    $b = &$tokens[2];

    $result = [ '(' . $a[0] . ' == ' . $b[0] . ')', true ];
  }

  function reduce_38_exp_8($tokens, &$result) {
    // (38) exp :=  exp  !=  exp
    $result = reset($tokens);
    $a = &$tokens[0];
    $b = &$tokens[2];

    $result = [ '(' . $a[0] . ' != ' . $b[0] . ')', true ];
  }

  function reduce_39_exp_9($tokens, &$result) {
    // (39) exp :=  exp  <  exp
    $result = reset($tokens);
    $a = &$tokens[0];
    $b = &$tokens[2];

    $result = [ '(' . $a[0] . ' < ' . $b[0] . ')', true ];
  }

  function reduce_40_exp_10($tokens, &$result) {
    // (40) exp :=  exp  >  exp
    $result = reset($tokens);
    $a = &$tokens[0];
    $b = &$tokens[2];

    $result = [ '(' . $a[0] . ' > ' . $b[0] . ')', true ];
  }

  function reduce_41_exp_11($tokens, &$result) {
    // (41) exp :=  exp  <=  exp
    $result = reset($tokens);
    $a = &$tokens[0];
    $b = &$tokens[2];

    $result = [ '(' . $a[0] . ' <= ' . $b[0] . ')', true ];
  }

  function reduce_42_exp_12($tokens, &$result) {
    // (42) exp :=  exp  >=  exp
    $result = reset($tokens);
    $a = &$tokens[0];
    $b = &$tokens[2];

    $result = [ '(' . $a[0] . ' >= ' . $b[0] . ')', true ];
  }

  function reduce_43_exp_13($tokens, &$result) {
    // (43) exp :=  exp  +  exp
    $result = reset($tokens);
    $a = &$tokens[0];
    $b = &$tokens[2];

    $result = [ '(' . $a[0] . ' + ' . $b[0] . ')', true ];
  }

  function reduce_44_exp_14($tokens, &$result) {
    // (44) exp :=  exp  -  exp
    $result = reset($tokens);
    $a = &$tokens[0];
    $b = &$tokens[2];

    $result = [ '(' . $a[0] . ' - ' . $b[0] . ')', true ];
  }

  function reduce_45_exp_15($tokens, &$result) {
    // (45) exp :=  exp  &  exp
    $result = reset($tokens);
    $a = &$tokens[0];
    $b = &$tokens[2];

    $result = [ '(' . $a[0] . ' & ' . $b[0] . ')', true ];
  }

  function reduce_46_exp_16($tokens, &$result) {
    // (46) exp :=  exp  *  exp
    $result = reset($tokens);
    $a = &$tokens[0];
    $b = &$tokens[2];

    $result = [ '(' . $a[0] . ' * ' . $b[0] . ')', true ];
  }

  function reduce_47_exp_17($tokens, &$result) {
    // (47) exp :=  exp  /  exp
    $result = reset($tokens);
    $a = &$tokens[0];
    $b = &$tokens[2];

    $result = [ '(' . $a[0] . ' / ' . $b[0] . ')', true ];
  }

  function reduce_48_exp_18($tokens, &$result) {
    // (48) exp :=  exp  %  exp
    $result = reset($tokens);
    $a = &$tokens[0];
    $b = &$tokens[2];

    $result = [ '(' . $a[0] . ' % ' . $b[0] . ')', true ];
  }

  function reduce_49_exp_19($tokens, &$result) {
    // (49) exp :=  p10
    $result = $tokens[0];
  }

  function reduce_50_p10_1($tokens, &$result) {
    // (50) p10 :=  p11
    $result = $tokens[0];
  }

  function reduce_51_p10_2($tokens, &$result) {
    // (51) p10 :=  -  p11
    $result = reset($tokens);
    $a = &$tokens[1];

    $result = [ '(-'.$a[0].')', true ];
  }

  function reduce_52_p11_1($tokens, &$result) {
    // (52) p11 :=  nonbrace
    $result = reset($tokens);
  }

  function reduce_53_p11_2($tokens, &$result) {
    // (53) p11 :=  (  exp  )  varpath
    $result = reset($tokens);
    $e = &$tokens[1];
    $p = &$tokens[3];

    $result = [ ($p !== '' ? 'self::noop('.$e[0].')'.$p : '('.$e[0].')'), false ];
  }

  function reduce_54_p11_3($tokens, &$result) {
    // (54) p11 :=  !  p11
    $result = reset($tokens);
    $a = &$tokens[1];

    $result = [ '(!'.$a[0].')', true ];
  }

  function reduce_55_p11_4($tokens, &$result) {
    // (55) p11 :=  NOT  p11
    $result = reset($tokens);
    $a = &$tokens[1];

    $result = [ '(!'.$a[0].')', true ];
  }

  function reduce_56_nonbrace_1($tokens, &$result) {
    // (56) nonbrace :=  {  hash  }
    $result = reset($tokens);
    $h = &$tokens[1];

    $result = [ 'array(' . $h . ')', true ];
  }

  function reduce_57_nonbrace_2($tokens, &$result) {
    // (57) nonbrace :=  literal
    $result = reset($tokens);

    $result = [ $tokens[0], true ];
  }

  function reduce_58_nonbrace_3($tokens, &$result) {
    // (58) nonbrace :=  varref
    $result = $tokens[0];
  }

  function reduce_59_nonbrace_4($tokens, &$result) {
    // (59) nonbrace :=  name  (  )
    $result = reset($tokens);
    $f = &$tokens[0];

    $result = $this->template->compile_function($f, []);
  }

  function reduce_60_nonbrace_5($tokens, &$result) {
    // (60) nonbrace :=  name  (  list  )
    $result = reset($tokens);
    $f = &$tokens[0];
    $args = &$tokens[2];

    $result = $this->template->compile_function($f, $args);
  }

  function reduce_61_nonbrace_6($tokens, &$result) {
    // (61) nonbrace :=  name  (  gthash  )
    $result = reset($tokens);
    $f = &$tokens[0];
    $args = &$tokens[2];

    $result = [ "\$this->parent->call_block('".addcslashes($f, "'\\")."', array(".$args."), '".addcslashes($this->template->lexer->errorinfo(), "'\\")."')", true ];
  }

  function reduce_62_nonbrace_7($tokens, &$result) {
    // (62) nonbrace :=  name  nonbrace
    $result = reset($tokens);
    $f = &$tokens[0];
    $arg = &$tokens[1];

    $result = $this->template->compile_function($f, [ $arg ]);
  }

  function reduce_63_list_1($tokens, &$result) {
    // (63) list :=  exp
    $result = reset($tokens);
    $e = &$tokens[0];

    $result = [ $e ];
  }

  function reduce_64_list_2($tokens, &$result) {
    // (64) list :=  exp  ,  list
    $result = reset($tokens);
    $e = &$tokens[0];
    $l = &$tokens[2];

    $result = $l;
    array_unshift($result, $e);
  }

  function reduce_65_arglist_1($tokens, &$result) {
    // (65) arglist :=  name
    $result = reset($tokens);
    $n = &$tokens[0];

    $result = [ $n ];
  }

  function reduce_66_arglist_2($tokens, &$result) {
    // (66) arglist :=  name  ,  arglist
    $result = reset($tokens);
    $n = &$tokens[0];
    $args = &$tokens[2];

    $result = $args;
    array_unshift($result, $n);
  }

  function reduce_67_arglist_3($tokens, &$result) {
    // (67) arglist :=  ε
    $result = reset($tokens);

    $result = [];
  }

  function reduce_68_hash_1($tokens, &$result) {
    // (68) hash :=  pair
    $result = $tokens[0];
  }

  function reduce_69_hash_2($tokens, &$result) {
    // (69) hash :=  pair  ,  hash
    $result = reset($tokens);
    $p = &$tokens[0];
    $h = &$tokens[2];

    $result = $p . ', ' . $h;
  }

  function reduce_70_hash_3($tokens, &$result) {
    // (70) hash :=  ε
    $result = reset($tokens);

    $result = '';
  }

  function reduce_71_gthash_1($tokens, &$result) {
    // (71) gthash :=  gtpair
    $result = $tokens[0];
  }

  function reduce_72_gthash_2($tokens, &$result) {
    // (72) gthash :=  gtpair  ,  gthash
    $result = reset($tokens);
    $p = &$tokens[0];
    $h = &$tokens[2];

    $result = $p . ', ' . $h;
  }

  function reduce_73_pair_1($tokens, &$result) {
    // (73) pair :=  exp  ,  exp
    $result = reset($tokens);
    $k = &$tokens[0];
    $v = &$tokens[2];

    $result = $k[0] . ' => ' . $v[0];
  }

  function reduce_74_pair_2($tokens, &$result) {
    // (74) pair :=  gtpair
    $result = $tokens[0];
  }

  function reduce_75_gtpair_1($tokens, &$result) {
    // (75) gtpair :=  exp  =>  exp
    $result = reset($tokens);
    $k = &$tokens[0];
    $v = &$tokens[2];

    $result = $k[0] . ' => ' . $v[0];
  }

  function reduce_76_varref_1($tokens, &$result) {
    // (76) varref :=  name
    $result = reset($tokens);
    $n = &$tokens[0];

    $result = [ "\$this->tpldata['".addcslashes($n, "\\\'")."']", false ];
  }

  function reduce_77_varref_2($tokens, &$result) {
    // (77) varref :=  varref  varpart
    $result = reset($tokens);
    $v = &$tokens[0];
    $p = &$tokens[1];

    $result = [ $v[0] . $p, false ];
  }

  function reduce_78_varpart_1($tokens, &$result) {
    // (78) varpart :=  .  namekw
    $result = reset($tokens);
    $n = &$tokens[1];

    $result = "['".addcslashes($n, "\\\'")."']";
  }

  function reduce_79_varpart_2($tokens, &$result) {
    // (79) varpart :=  [  exp  ]
    $result = reset($tokens);
    $e = &$tokens[1];

    $result = '['.$e[0].']';
  }

  function reduce_80_varpart_3($tokens, &$result) {
    // (80) varpart :=  .  namekw  (  )
    $result = reset($tokens);
    $n = &$tokens[1];

    $result = '->'.$n.'()';
  }

  function reduce_81_varpart_4($tokens, &$result) {
    // (81) varpart :=  .  namekw  (  list  )
    $result = reset($tokens);
    $n = &$tokens[1];
    $l = &$tokens[3];

    $argv = [];
    foreach ($l as $a) {
      $argv[] = $a[0];
    }
    $result = '->'.$n.'('.implode(', ', $argv).')';
  }

  function reduce_82_varpath_1($tokens, &$result) {
    // (82) varpath :=  ε
    $result = reset($tokens);

    $result = '';
  }

  function reduce_83_varpath_2($tokens, &$result) {
    // (83) varpath :=  varpath  varpart
    $result = reset($tokens);
    $a = &$tokens[0];
    $p = &$tokens[1];

    $result = $a . $p;
  }

  function reduce_84_namekw_1($tokens, &$result) {
    // (84) namekw :=  name
    $result = reset($tokens);
  }

  function reduce_85_namekw_2($tokens, &$result) {
    // (85) namekw :=  IF
    $result = reset($tokens);
  }

  function reduce_86_namekw_3($tokens, &$result) {
    // (86) namekw :=  END
    $result = reset($tokens);
  }

  function reduce_87_namekw_4($tokens, &$result) {
    // (87) namekw :=  ELSE
    $result = reset($tokens);
  }

  function reduce_88_namekw_5($tokens, &$result) {
    // (88) namekw :=  ELSIF
    $result = reset($tokens);
  }

  function reduce_89_namekw_6($tokens, &$result) {
    // (89) namekw :=  ELSEIF
    $result = reset($tokens);
  }

  function reduce_90_namekw_7($tokens, &$result) {
    // (90) namekw :=  SET
    $result = reset($tokens);
  }

  function reduce_91_namekw_8($tokens, &$result) {
    // (91) namekw :=  OR
    $result = reset($tokens);
  }

  function reduce_92_namekw_9($tokens, &$result) {
    // (92) namekw :=  XOR
    $result = reset($tokens);
  }

  function reduce_93_namekw_10($tokens, &$result) {
    // (93) namekw :=  AND
    $result = reset($tokens);
  }

  function reduce_94_namekw_11($tokens, &$result) {
    // (94) namekw :=  NOT
    $result = reset($tokens);
  }

  function reduce_95_namekw_12($tokens, &$result) {
    // (95) namekw :=  FUNCTION
    $result = reset($tokens);
  }

  function reduce_96_namekw_13($tokens, &$result) {
    // (96) namekw :=  BLOCK
    $result = reset($tokens);
  }

  function reduce_97_namekw_14($tokens, &$result) {
    // (97) namekw :=  MACRO
    $result = reset($tokens);
  }

  function reduce_98_namekw_15($tokens, &$result) {
    // (98) namekw :=  FOR
    $result = reset($tokens);
  }

  function reduce_99_namekw_16($tokens, &$result) {
    // (99) namekw :=  FOREACH
    $result = reset($tokens);
  }

  function reduce_100_start_1($tokens, &$result) {
    // (100) 'start' :=  template
    $result = reset($tokens);
  }

  public $method = array(
    'reduce_0_template_1',
    'reduce_1_chunks_1',
    'reduce_2_chunks_2',
    'reduce_3_chunk_1',
    'reduce_4_chunk_2',
    'reduce_5_chunk_3',
    'reduce_6_chunk_4',
    'reduce_7_code_chunk_1',
    'reduce_8_code_chunk_2',
    'reduce_9_code_chunk_3',
    'reduce_10_code_chunk_4',
    'reduce_11_code_chunk_5',
    'reduce_12_c_if_1',
    'reduce_13_c_if_2',
    'reduce_14_c_if_3',
    'reduce_15_c_if_4',
    'reduce_16_c_elseifs_1',
    'reduce_17_c_elseifs_2',
    'reduce_18_c_set_1',
    'reduce_19_c_set_2',
    'reduce_20_c_fn_1',
    'reduce_21_c_fn_2',
    'reduce_22_c_for_1',
    'reduce_23_fn_1',
    'reduce_24_fn_2',
    'reduce_25_fn_3',
    'reduce_26_for_1',
    'reduce_27_for_2',
    'reduce_28_elseif_1',
    'reduce_29_elseif_2',
    'reduce_30_elseif_3',
    'reduce_31_exp_1',
    'reduce_32_exp_2',
    'reduce_33_exp_3',
    'reduce_34_exp_4',
    'reduce_35_exp_5',
    'reduce_36_exp_6',
    'reduce_37_exp_7',
    'reduce_38_exp_8',
    'reduce_39_exp_9',
    'reduce_40_exp_10',
    'reduce_41_exp_11',
    'reduce_42_exp_12',
    'reduce_43_exp_13',
    'reduce_44_exp_14',
    'reduce_45_exp_15',
    'reduce_46_exp_16',
    'reduce_47_exp_17',
    'reduce_48_exp_18',
    'reduce_49_exp_19',
    'reduce_50_p10_1',
    'reduce_51_p10_2',
    'reduce_52_p11_1',
    'reduce_53_p11_2',
    'reduce_54_p11_3',
    'reduce_55_p11_4',
    'reduce_56_nonbrace_1',
    'reduce_57_nonbrace_2',
    'reduce_58_nonbrace_3',
    'reduce_59_nonbrace_4',
    'reduce_60_nonbrace_5',
    'reduce_61_nonbrace_6',
    'reduce_62_nonbrace_7',
    'reduce_63_list_1',
    'reduce_64_list_2',
    'reduce_65_arglist_1',
    'reduce_66_arglist_2',
    'reduce_67_arglist_3',
    'reduce_68_hash_1',
    'reduce_69_hash_2',
    'reduce_70_hash_3',
    'reduce_71_gthash_1',
    'reduce_72_gthash_2',
    'reduce_73_pair_1',
    'reduce_74_pair_2',
    'reduce_75_gtpair_1',
    'reduce_76_varref_1',
    'reduce_77_varref_2',
    'reduce_78_varpart_1',
    'reduce_79_varpart_2',
    'reduce_80_varpart_3',
    'reduce_81_varpart_4',
    'reduce_82_varpath_1',
    'reduce_83_varpath_2',
    'reduce_84_namekw_1',
    'reduce_85_namekw_2',
    'reduce_86_namekw_3',
    'reduce_87_namekw_4',
    'reduce_88_namekw_5',
    'reduce_89_namekw_6',
    'reduce_90_namekw_7',
    'reduce_91_namekw_8',
    'reduce_92_namekw_9',
    'reduce_93_namekw_10',
    'reduce_94_namekw_11',
    'reduce_95_namekw_12',
    'reduce_96_namekw_13',
    'reduce_97_namekw_14',
    'reduce_98_namekw_15',
    'reduce_99_namekw_16',
    'reduce_100_start_1'
  );
  public $a = array(
    array(
      'symbol' => 'template',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'chunks',
      'len' => 0,
      'replace' => true
    ),
    array(
      'symbol' => 'chunks',
      'len' => 2,
      'replace' => true
    ),
    array(
      'symbol' => 'chunk',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'chunk',
      'len' => 3,
      'replace' => true
    ),
    array(
      'symbol' => 'chunk',
      'len' => 3,
      'replace' => true
    ),
    array(
      'symbol' => 'chunk',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'code_chunk',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'code_chunk',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'code_chunk',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'code_chunk',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'code_chunk',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'c_if',
      'len' => 6,
      'replace' => true
    ),
    array(
      'symbol' => 'c_if',
      'len' => 10,
      'replace' => true
    ),
    array(
      'symbol' => 'c_if',
      'len' => 8,
      'replace' => true
    ),
    array(
      'symbol' => 'c_if',
      'len' => 12,
      'replace' => true
    ),
    array(
      'symbol' => 'c_elseifs',
      'len' => 4,
      'replace' => true
    ),
    array(
      'symbol' => 'c_elseifs',
      'len' => 6,
      'replace' => true
    ),
    array(
      'symbol' => 'c_set',
      'len' => 4,
      'replace' => true
    ),
    array(
      'symbol' => 'c_set',
      'len' => 6,
      'replace' => true
    ),
    array(
      'symbol' => 'c_fn',
      'len' => 7,
      'replace' => true
    ),
    array(
      'symbol' => 'c_fn',
      'len' => 9,
      'replace' => true
    ),
    array(
      'symbol' => 'c_for',
      'len' => 8,
      'replace' => true
    ),
    array(
      'symbol' => 'fn',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'fn',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'fn',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'for',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'for',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'elseif',
      'len' => 2,
      'replace' => true
    ),
    array(
      'symbol' => 'elseif',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'elseif',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'exp',
      'len' => 3,
      'replace' => true
    ),
    array(
      'symbol' => 'exp',
      'len' => 3,
      'replace' => true
    ),
    array(
      'symbol' => 'exp',
      'len' => 3,
      'replace' => true
    ),
    array(
      'symbol' => 'exp',
      'len' => 3,
      'replace' => true
    ),
    array(
      'symbol' => 'exp',
      'len' => 3,
      'replace' => true
    ),
    array(
      'symbol' => 'exp',
      'len' => 3,
      'replace' => true
    ),
    array(
      'symbol' => 'exp',
      'len' => 3,
      'replace' => true
    ),
    array(
      'symbol' => 'exp',
      'len' => 3,
      'replace' => true
    ),
    array(
      'symbol' => 'exp',
      'len' => 3,
      'replace' => true
    ),
    array(
      'symbol' => 'exp',
      'len' => 3,
      'replace' => true
    ),
    array(
      'symbol' => 'exp',
      'len' => 3,
      'replace' => true
    ),
    array(
      'symbol' => 'exp',
      'len' => 3,
      'replace' => true
    ),
    array(
      'symbol' => 'exp',
      'len' => 3,
      'replace' => true
    ),
    array(
      'symbol' => 'exp',
      'len' => 3,
      'replace' => true
    ),
    array(
      'symbol' => 'exp',
      'len' => 3,
      'replace' => true
    ),
    array(
      'symbol' => 'exp',
      'len' => 3,
      'replace' => true
    ),
    array(
      'symbol' => 'exp',
      'len' => 3,
      'replace' => true
    ),
    array(
      'symbol' => 'exp',
      'len' => 3,
      'replace' => true
    ),
    array(
      'symbol' => 'exp',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'p10',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'p10',
      'len' => 2,
      'replace' => true
    ),
    array(
      'symbol' => 'p11',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'p11',
      'len' => 4,
      'replace' => true
    ),
    array(
      'symbol' => 'p11',
      'len' => 2,
      'replace' => true
    ),
    array(
      'symbol' => 'p11',
      'len' => 2,
      'replace' => true
    ),
    array(
      'symbol' => 'nonbrace',
      'len' => 3,
      'replace' => true
    ),
    array(
      'symbol' => 'nonbrace',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'nonbrace',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'nonbrace',
      'len' => 3,
      'replace' => true
    ),
    array(
      'symbol' => 'nonbrace',
      'len' => 4,
      'replace' => true
    ),
    array(
      'symbol' => 'nonbrace',
      'len' => 4,
      'replace' => true
    ),
    array(
      'symbol' => 'nonbrace',
      'len' => 2,
      'replace' => true
    ),
    array(
      'symbol' => 'list',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'list',
      'len' => 3,
      'replace' => true
    ),
    array(
      'symbol' => 'arglist',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'arglist',
      'len' => 3,
      'replace' => true
    ),
    array(
      'symbol' => 'arglist',
      'len' => 0,
      'replace' => true
    ),
    array(
      'symbol' => 'hash',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'hash',
      'len' => 3,
      'replace' => true
    ),
    array(
      'symbol' => 'hash',
      'len' => 0,
      'replace' => true
    ),
    array(
      'symbol' => 'gthash',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'gthash',
      'len' => 3,
      'replace' => true
    ),
    array(
      'symbol' => 'pair',
      'len' => 3,
      'replace' => true
    ),
    array(
      'symbol' => 'pair',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'gtpair',
      'len' => 3,
      'replace' => true
    ),
    array(
      'symbol' => 'varref',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'varref',
      'len' => 2,
      'replace' => true
    ),
    array(
      'symbol' => 'varpart',
      'len' => 2,
      'replace' => true
    ),
    array(
      'symbol' => 'varpart',
      'len' => 3,
      'replace' => true
    ),
    array(
      'symbol' => 'varpart',
      'len' => 4,
      'replace' => true
    ),
    array(
      'symbol' => 'varpart',
      'len' => 5,
      'replace' => true
    ),
    array(
      'symbol' => 'varpath',
      'len' => 0,
      'replace' => true
    ),
    array(
      'symbol' => 'varpath',
      'len' => 2,
      'replace' => true
    ),
    array(
      'symbol' => 'namekw',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'namekw',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'namekw',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'namekw',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'namekw',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'namekw',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'namekw',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'namekw',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'namekw',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'namekw',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'namekw',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'namekw',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'namekw',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'namekw',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'namekw',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => 'namekw',
      'len' => 1,
      'replace' => true
    ),
    array(
      'symbol' => "'start'",
      'len' => 1,
      'replace' => true
    )
  );
}

// Time: 4,2855579853058 seconds
// Memory: 11192016 bytes
