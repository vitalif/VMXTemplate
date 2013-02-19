<?php

# "Ох уж эти перлисты... что ни пишут - всё Template Toolkit получается!"

# "Oh that perlists... anything they write is just another Template Toolkit"
# Rewritten 3 times: phpbb -> regex -> index() -> recursive descent.
# Needs another rewrite using a LALR parser generator, maybe LIME...

# Homepage: http://yourcmc.ru/wiki/VMX::Template
# Author: Vitaliy Filippov, 2006-2013
# $Id$

class VMXTemplateState
{
    // Old-style blocks
    var $blocks = array();

    // Stack of code fragments for END checking
    // array(array($instruction, $subject))
    // E.g. $instruction = FOR, $subject = varref
    var $in = array();

    // Functions
    var $functions = array();

    // Template filename
    var $input_filename = '';

    // Stack of references to output strings
    var $output = array();
}

if (!defined('TS_UNIX'))
{
    // Global timestamp format constants
    define('TS_UNIX', 0);
    define('TS_DB', 1);
    define('TS_DB_DATE', 2);
    define('TS_MW', 3);
    define('TS_EXIF', 4);
    define('TS_ORACLE', 5);
    define('TS_ISO_8601', 6);
    define('TS_RFC822', 7);
}

class VMXTemplate
{
    static $Mon, $mon, $Wday;
    static $cache_type  = NULL;
    static $cache       = array();
    static $safe_tags   = '<div> <span> <a> <b> <i> <u> <p> <h1> <h2> <h3> <h4> <h5> <h6> <strike> <strong> <small> <big> <blink> <center> <ol> <pre> <sub> <sup> <font> <br> <table> <tr> <td> <th> <tbody> <tfoot> <thead> <tt> <ul> <li> <em> <img> <marquee>';

    // Timestamp format constants
    const TS_UNIX       = 0;
    const TS_DB         = 1;
    const TS_DB_DATE    = 2;
    const TS_MW         = 3;
    const TS_EXIF       = 4;
    const TS_ORACLE     = 5;
    const TS_ISO_8601   = 6;
    const TS_RFC822     = 7;

    // Version of code classes, saved into static $version
    const CODE_VERSION  = 3;

    // Logged errors
    var $errors = array();

    // Data passed to the template
    var $tpldata = array();

    // Parent 'VMXTemplate' object for compiled templates
    // parse_anything() functions are always called on $this->parent
    var $parent = NULL;

    // Failed-to-load filenames, saved to skip them during the request
    var $failed = array();

    // Search path for template functions (filenames indexed by function name)
    var $function_search_path = array();

    // Options object
    var $options;

    /**
     * Constructor
     *
     * @param array $options Options
     */
    function __construct($options)
    {
        $this->options = new VMXTemplateOptions($options);
    }

    /**
     * Log an error
     */
    function error($e, $fatal = false)
    {
        $this->errors[] = $e;
        if ($this->options->raise_error && $fatal)
            die(__CLASS__." error: $e");
        elseif ($this->options->print_error)
            print __CLASS__." error: $e<br />";
    }

    /**
     * Clear template data
     */
    function clear()
    {
        $this->tpldata = array();
        return true;
    }

    /**
     * Shortcut for $this->vars()
     */
    function assign_vars($new = NULL, $value = NULL)
    {
        $this->vars($new, $value);
    }

    /**
     * Set template data value/values.
     * $obj->vars($key, $value);
     * or
     * $obj->vars(array(key => value, ...));
     */
    function vars($new = NULL, $value = NULL)
    {
        if (is_array($new))
        {
            $this->tpldata = array_merge($this->tpldata, $new);
        }
        elseif ($new && $value !== NULL)
        {
            $this->tpldata[$new] = $value;
        }
    }

    /*** Cache support - XCache/APC/eAccelerator ***/

    static function cache_check_type()
    {
        if (is_null(self::$cache_type))
        {
            if (function_exists('xcache_get'))
                self::$cache_type = 'x';
            elseif (function_exists('apc_store'))
                self::$cache_type = 'a';
            elseif (function_exists('eaccelerator_get'))
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
            elseif (self::$cache_type == 'a')
                self::$cache[$key] = apc_fetch($key);
            elseif (self::$cache_type == 'e')
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
        elseif (self::$cache_type == 'a')
            apc_delete($key);
        elseif (self::$cache_type == 'e')
            eaccelerator_rm($key);
    }

    static function cache_set($key, $value)
    {
        self::cache_check_type();
        self::$cache[$key] = $value;
        if (self::$cache_type == 'x')
            xcache_set($key, $value);
        elseif (self::$cache_type == 'a')
            apc_store($key, $value);
        elseif (self::$cache_type == 'e')
            eaccelerator_put($key, $value);
    }

    /*** Parse functions ***/

    /**
     * Normal (main) parse function.
     * Use it to run the template.
     *
     * @param string $filename Template filename
     * @param array $vars Optional data, will override $this->tpldata
     */
    function parse($filename, $vars = NULL)
    {
        return $this->parse_real($filename, NULL, 'main', $vars);
    }

    /**
     * Call template block (= macro/function)
     *
     * @param string $filename Template filename
     * @param string $function Function name
     * @param array $vars Optional data
     */
    function exec_from($filename, $function, $vars = NULL)
    {
        return $this->parse_real($filename, NULL, $function, $vars);
    }

    /**
     * Should not be used without great need.
     * Run template passed as argument.
     */
    function parse_inline($code, $vars = NULL)
    {
        return $this->parse_real(NULL, $code, 'main', $vars);
    }

    /**
     * Should not be used without great need.
     * Execute a function from the code passed as argument.
     */
    function exec_from_inline($code, $function, $vars = NULL)
    {
        return $this->parse_real(NULL, $code, $function, $vars);
    }

    /**
     * parse_real variant that does not require $vars to be an lvalue
     */
    protected function parse_discard($fn, $inline, $func, $vars = NULL)
    {
        return $this->parse_real($fn, $inline, $func, $vars);
    }

    /**
     * "Real" parse function, handles all parse_*()
     */
    protected function parse_real($fn, $inline, $func, &$vars = NULL)
    {
        if (!$fn)
        {
            if (!strlen($inline))
                return '';
            $class = 'Template_X'.md5($inline);
            if (!($file = $this->compile($inline, '')))
                return NULL;
            include $file;
        }
        else
        {
            if (substr($fn, 0, 1) != '/')
                $fn = $this->options->root.$fn;
            /* Don't reload already loaded classes - optimal for multiple parse() calls.
               But if we would like to reload templates during ONE request some day... */
            $class = 'Template_'.md5($fn);
            if (!class_exists($class))
            {
                if (isset($this->failed[$fn]))
                {
                    // Fail recorded, don't retry until next request
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
                if (!class_exists($class) || !isset($class::$version) || $class::$version < self::CODE_VERSION)
                {
                    // Cache file from some older version - reset it
                    $this->error("Please, clear template cache path after upgrading VMX::Template", true);
                    $this->failed[$fn] = true;
                    return NULL;
                }
                foreach ($class::$functions as $loaded_function)
                {
                    // FIXME Do it better
                    // Remember functions during file loading
                    $this->function_search_path[$loaded_function][] = $fn;
                }
            }
        }
        $func = "fn_$func";
        $tpl = new $class($this);
        if ($vars)
        {
            $tpl->tpldata = &$vars;
        }
        $old = error_reporting();
        if ($old & E_NOTICE)
        {
            error_reporting($old & ~E_NOTICE);
        }
        $t = $tpl->$func();
        if ($old & E_NOTICE)
        {
            error_reporting($old);
        }
        if ($this->options->filters)
        {
            $filters = $this->options->filters;
            if (is_callable($filters) || is_string($filters) && is_callable(array(__CLASS__, "filter_$filters")))
            {
                $filters = array($filters);
            }
            foreach ($filters as $w)
            {
                if (is_string($w) && is_callable(array(__CLASS__, "filter_$w")))
                {
                    $w = array(__CLASS__, "filter_$w");
                }
                elseif (!is_callable($w))
                {
                    continue;
                }
                call_user_func_array($w, array(&$t));
            }
        }
        return $t;
    }

    /**
     * Load file (with caching)
     *
     * @param string $fn Filename
     */
    function loadfile($fn)
    {
        $load = false;
        if (!($text = self::cache_get("U$fn")) || $this->options->reload)
        {
            $mtime = stat($fn);
            $mtime = $mtime[9];
            if (!$text)
            {
                $load = true;
            }
            else
            {
                $ctime = self::cache_get("T$fn");
                if ($ctime < $mtime)
                {
                    $load = true;
                }
            }
        }
        // Reload if file changed
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
            {
                return NULL;
            }
            // Different keys may expire separately, but that's not a problem here
            self::cache_set("T$fn", $mtime);
            self::cache_set("U$fn", $text);
        }
        return $text;
    }

    /**
     * Compile code into a file and return its filename.
     * This file, evaluated, will create the "Template_XXX" class
     *
     * $file = $this->compile($code, $fn);
     * require $file;
     */
    function compile($code, $fn, $reload = false)
    {
        $md5 = md5($code);
        $file = $this->options->cache_dir . 'tpl' . $md5 . '.php';
        if (file_exists($file) && !$reload)
        {
            return $file;
        }

        if (!$fn)
        {
            // Mock filename for inline code
            $func_ns = 'X' . $md5;
            $c = debug_backtrace();
            $c = $c[2];
            $fn = '(inline template at '.$c['file'].':'.$c['line'].')';
        }
        else
        {
            $func_ns = md5($fn);
        }

        $parser = new VMXTemplateParser($this->options);
        $compiled = $parser->parse_all($code, $fn, $func_ns);
        if (!file_put_contents($file, $compiled))
        {
            throw new VMXTemplateException("Failed writing $file");
        }

        return $file;
    }

    /**
     * Call template block / "function" from the template where it was defined
     */
    function call_block($block, $args, $errorinfo)
    {
        if (isset($this->function_search_path[$block]))
        {
            // FIXME maybe do it better!
            $fn = $this->function_search_path[$block][0];
            return $this->parse_real($fn, NULL, $block, $args);
        }
        throw new VMXTemplateException("$errorinfo Unknown block '$block'");
    }

    /*** Built-in filters ***/

    /**
     * Strips space from the beginning and ending of each line
     */
    static function filter_strip_space(&$text)
    {
        $text = preg_replace('/^[ \t\v]+/m', '', $text);
        $text = preg_replace('/[ \t\v]+$/m', '', $text);
    }

    /*** Function implementations ***/

    static function array1($a)
    {
        if (is_null($a))
            return array();
        if (is_array($a) && !self::is_assoc($a))
            return $a;
        return array($a);
    }

    // Guess if the array is associative based on the first key (for performance)
    static function is_assoc($a)
    {
        reset($a);
        return $a && !is_int(key($a));
    }

    // Merge all scalar and list arguments into one list
    static function merge_to_array()
    {
        $args = func_get_args();
        $aa = (array) array_shift($args);
        if (self::is_assoc($aa))
            $aa = array($aa);
        foreach ($args as $a)
        {
            if (is_array($a) && !self::is_assoc($a))
                foreach ($a as $v)
                    $aa[] = $v;
            else
                $aa[] = $a;
        }
        return $aa;
    }

    // Returns count of elements for arrays and 0 for others
    static function array_count($a)
    {
        if (is_array($a))
            return count($a);
        return 0;
    }

    // Perlish OR operator - returns first true value
    static function perlish_or()
    {
        $a = func_get_args();
        $last = array_pop($a);
        foreach ($a as $v)
            if ($v)
                return $v;
        return $last;
    }

    // Call a function
    function exec_call($f, $sub, $args)
    {
        if (is_callable($sub))
            return call_user_func_array($sub, $args);
        $this->error("Unknown function: '$f'");
        return NULL;
    }

    // Variable dump
    static function exec_dump($var)
    {
        ob_start();
        var_dump($var);
        $var = ob_get_contents();
        ob_end_clean();
        return $var;
    }

    // Extract values from an array by modulus of their indexes
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

    // Executes subst()
    static function exec_subst($str)
    {
        $args = func_get_args();
        $str = preg_replace_callback('/(?<!\\\\)((?:\\\\\\\\)*)\$(?:([1-9]\d*)|\{([1-9]\d*)\})/is', create_function('$m', 'return $args[$m[2]?$m[2]:$m[3]];'), $str);
        return $str;
    }

    // Normal sort, but returns the sorted array
    static function exec_sort($array)
    {
        sort($array);
        return $array;
    }

    // Returns array item
    static function exec_get($array, $key)
    {
        return $array[$key];
    }

    // Creates hash from an array
    static function exec_hash($array)
    {
        $hash = array();
        $l = count($array);
        for ($i = 0; $i < $l; $i += 2)
            $hash[$array[$i]] = $array[$i+1];
        return $hash;
    }

    // For a hash, returns an array with pairs { key => 'key', value => 'value' }
    static function exec_pairs($array)
    {
        $r = array();
        foreach ($array as $k => $v)
            $r[] = array('key' => $k, 'value' => $v);
        return $r;
    }

    // Limit string length, cut it on space boundary and add '...' if length is over
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

    // UTF-8 (mb_internal_encoding() really) variant of strlimit()
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

    // UTF-8 lcfirst()
    static function mb_lcfirst($str)
    {
        return mb_strtolower(mb_substr($str, 0, 1)) . mb_substr($str, 0, 1);
    }

    // UTF-8 ucfirst()
    static function mb_ucfirst($str)
    {
        return mb_strtoupper(mb_substr($str, 0, 1)) . mb_substr($str, 0, 1);
    }

    // Limited-edition timestamp parser
    static function timestamp($ts = 0, $format = 0)
    {
        if (!self::$Mon)
        {
            self::$Mon = explode(' ', 'Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec');
            self::$mon = array_reverse(explode(' ', 'jan feb mar apr may jun jul aug sep oct nov dec'));
            self::$Wday = explode(' ', 'Sun Mon Tue Wed Thu Fri Sat');
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
        elseif ($format == self::TS_MW)
        {
            return strftime("%Y%m%d%H%M%S", $ts);
        }
        elseif ($format == self::TS_DB)
        {
            return strftime("%Y-%m-%d %H:%M:%S", $ts);
        }
        elseif ($format == self::TS_DB_DATE)
        {
            return strftime("%Y-%m-%d", $ts);
        }
        elseif ($format == self::TS_ISO_8601)
        {
            return strftime("%Y-%m-%dT%H:%M:%SZ", $ts);
        }
        elseif ($format == self::TS_EXIF)
        {
            return strftime("%Y:%m:%d %H:%M:%S", $ts);
        }
        elseif ($format == self::TS_RFC822)
        {
            $l = localtime($ts);
            return strftime($Wday[$l[6]].", %d ".$Mon[$l[4]]." %Y %H:%M:%S %z", $ts);
        }
        elseif ($format == self::TS_ORACLE)
        {
            $l = localtime($ts);
            return strftime("%d-".$Mon[$l[4]]."-%Y %H.%M.%S %p", $ts);
        }
        return $ts;
    }
}

/**
 * Template exception classes
 */
class VMXTemplateException extends Exception {}
class VMXTemplateParseException extends VMXTemplateException {}

/**
 * Options class
 */
class VMXTemplateOptions
{
    var $begin_code    = '<!--';    // instruction start
    var $end_code      = '-->';     // instruction end
    var $begin_subst   = '{';       // substitution start (optional)
    var $end_subst     = '}';       // substitution end (optional)
    var $no_code_subst = false;     // do not substitute expressions in instructions
    var $eat_code_line = true;      // remove the "extra" lines which contain instructions only
    var $root          = '.';       // directory with templates
    var $cache_dir     = false;     // compiled templates cache directory
    var $reload        = 1;         // 0 means to not check for new versions of cached templates
    var $filters       = array();   // filter to run on output of every template
    var $use_utf8      = true;      // use UTF-8 for all string operations on template variables
    var $raise_error   = false;     // die() on fatal template errors
    var $print_error   = false;     // print fatal template errors
    var $strict_end    = false;     // require block name in ending instructions for FOR, BEGIN, SET and FUNCTION <!-- END block -->
    var $strip_space   = false;     // strip spaces from beginning and end of each line
    var $compiletime_functions = array();   // custom compile-time functions (code generators)

    function __construct($options = array())
    {
        $this->set($options);
    }

    function set($options)
    {
        foreach ($options as $k => $v)
        {
            if (isset($this->$k))
            {
                $this->$k = $v;
            }
        }
        if ($this->strip_space)
        {
            $this->filters[] = 'strip_space';
        }
        if (!$this->begin_subst || !$this->end_subst)
        {
            $this->begin_subst = false;
            $this->end_subst = false;
            $this->no_code_subst = false;
        }
        $this->cache_dir = preg_replace('!/*$!s', '/', $this->cache_dir);
        if (!is_writable($this->cache_dir))
        {
            throw new VMXTemplateException('VMXTemplate: cache_dir='.$this->cache_dir.' is not writable');
        }
        $this->root = preg_replace('!/*$!s', '/', $this->root);
    }
}

/**
 * Parser of templates and expressions into PHP code.
 *
 * Includes:
 * - Lexical analyzer (~regexp)
 * - O(n) recursive descent syntactic analyzer and translator
 *   I.e. no backtracking, but performance maybe is worse than with LALR.
 */
class VMXTemplateParser
{
    // Options, state
    var $options, $st;

    // Code (string) and current position inside it
    var $code, $codelen, $pos, $lineno;

    // Extracted tokens (array), their source positions and current token number
    var $tokens, $tokpos, $tokline, $ptr;

    // Possible tokens consisting of special characters
    static $chartokens = '+ - = * / % ! , . < > ( ) { } [ ] | || && == != <= >= =>';

    // ops_and: ops_eq | ops_eq "&&" ops_and | ops_eq "AND" ops_and
    // ops_eq: ops_cmp | ops_cmp "==" ops_cmp | ops_cmp "!=" ops_cmp
    // ops_cmp: ops_add | ops_add '<' ops_add | ops_add '>' ops_add | ops_add "<=" ops_add | ops_add ">=" ops_add
    // ops_add: ops_mul | ops_mul '+' ops_add | ops_mul '-' ops_add
    // ops_mul: exp_neg | exp_neg '*' ops_mul | exp_neg '/' ops_mul | exp_neg '%' ops_mul
    static $ops = array(
        'or'  => array(array('||', '$or', '$xor'), 'and', true),
        'and' => array(array('&&', '$and'), 'eq', true),
        'eq'  => array(array('==', '!='), 'cmp', false),
        'cmp' => array(array('<', '>', '<=', '>='), 'add', false),
        'add' => array(array('+', '-'), 'mul', true),
        'mul' => array(array('*', '/', '%'), 'neg', true),
    );

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

    /**
     * USAGE:
     * $p = new VMXTemplateParser($options);
     * try { $e = $p->parse_all($code); } catch (Exception $e) { ... }
     */
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
    }

    /*** Lexical analysis ***/

    function clear_tokens()
    {
        $this->tokens = array();
        $this->tokpos = array();
        $this->tokline = array();
        $this->ptr = 0;
    }

    function set_code($code)
    {
        $this->code = $code;
        $this->pos = $this->lineno = 0;
        $this->codelen = strlen($this->code);
        $this->clear_tokens();
    }

    /**
     * Get (current+$num) token from buffer or read it from the source
     */
    function tok($num = 0)
    {
        while (($this->ptr+$num >= count($this->tokens)) && $this->read_token())
        {
            // Read tokens
        }
        if ($this->ptr+$num >= count($this->tokens))
        {
            return false;
        }
        return $this->tokens[$this->ptr+$num];
    }

    /**
     * Get current token position
     */
    function tokpos($num = 0)
    {
        if (!$this->tok($num))
        {
            return false;
        }
        return array($this->tokpos[$this->ptr+$num], $this->tokline[$this->ptr+$num]);
    }

    function errorinfo()
    {
        $l = strlen($this->code);
        $linestart = strrpos($this->code, "\n", $this->pos-$l-1) ?: -1;
        $lineend = strpos($this->code, "\n", $this->pos) ?: $l;
        $line = substr($this->code, $linestart+1, $this->pos-$linestart-1);
        $line .= '^^^';
        $line .= substr($this->code, $this->pos, $lineend-$this->pos);
        $in = '';
        $trace = debug_backtrace(DEBUG_BACKTRACE_IGNORE_ARGS);
        foreach ($trace as $frame)
        {
            if ($frame['function'] == 'parse_all')
            {
                break;
            }
            elseif (substr($frame['function'], 0, 6) == 'parse_')
            {
                $in = strtoupper(substr($frame['function'], 6)).", ";
                break;
            }
        }
        return "in $in{$this->st->input_filename}, line ".($this->lineno+1).", byte {$this->pos}, marked by ^^^ in $line";
    }

    function warn($text)
    {
        if ($this->options->print_error)
        {
            if (PHP_SAPI == 'cli')
            {
                print "$text\n";
            }
            else
            {
                print htmlspecialchars($text).'<br />';
            }
        }
    }

    function raise($msg)
    {
        throw new VMXTemplateParseException(
            $msg.' '.$this->errorinfo()
        );
    }

    /**
     * Read next token from the stream and append it to $this->tokens,tokpos,tokline
     * Returns true if a token was read, and false if EOF occurred
     */
    function read_token()
    {
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
            // Identifier
            $this->tokpos[] = $this->pos;
            $this->tokline[] = $this->lineno;
            $this->tokens[] = '$'.$m[0];
            $this->pos += strlen($m[0]);
        }
        elseif (preg_match(
            '/((\")(?:[^\"\\\\]+|\\\\.)*\"|\'(?:[^\'\\\\]+|\\\\.)*\''.
            '|0\d+|\d+(\.\d+)?|0x\d+)/Ais', $this->code, $m, 0, $this->pos))
        {
            // String or numeric non-negative literal
            $t = $m[1];
            if (isset($m[2]))
                $t = str_replace('$', '\\$', $t);
            $this->tokpos[] = $this->pos;
            $this->tokline[] = $this->lineno;
            $this->tokens[] = '#'.$t;
            $this->pos += strlen($m[0]);
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
                    $this->tokpos[] = $this->pos;
                    $this->tokline[] = $this->lineno;
                    $this->tokens[] = $t;
                    $this->pos += $l;
                    return true;
                }
            }
            // Unknown character
            $this->raise(
                "Unexpected character '".$this->code{$this->pos}."'"
            );
        }
        return true;
    }

    /**
     * Assume $token is next in the stream (case-insensitive)
     * and move pointer forward.
     *
     * $token may be '$' (assume name), '#' (assume literal),
     * or an exact value of one of others. For names and literals,
     * a value is returned, and the token itself for others.
     */
    function consume($token)
    {
        $t = $this->tok();
        if ($t === false)
            $this->unexpected($token, 1);
        elseif ($token == '$' || $token == '#')
        {
            if ($t{0} == $token)
            {
                $this->ptr++;
                return substr($t, 1);
            }
            else
                $this->unexpected($token, 1);
        }
        elseif (!in_array(strtolower($t), (array)$token))
            $this->unexpected($token, 1);
        $this->ptr++;
        return $t;
    }

    /**
     * Assume next token is "EOD" (end-of-directive)
     * Used in "stateful" directives to prevent changing state on incorrect parse
     */
    function assume_eod()
    {
        if ($this->tok() != $this->eod)
        {
            $this->unexpected($this->eod, 1);
        }
    }

    /**
     * Raise "unexpected token" error
     */
    function unexpected($expected, $skip_frames = 0)
    {
        $expected = (array)$expected;
        foreach ($expected as &$e)
        {
            if ($e == '#')
                $e = 'literal';
            elseif ($e == '$')
                $e = 'identifier';
        }
        $tok = $this->tok();
        if ($tok === false)
            $tok = '<EOF>';
        else
        {
            if ($tok{0} == '#' || $tok{0} == '$')
                $tok = substr($tok, 1);
            $tok = "'$tok'";
        }
        $text = "Unexpected $tok, expected ";
        if (count($expected) > 1)
            $text .= "one of '";
        $text .= implode("', '", $expected)."'";
        $this->raise($text);
    }

    /*** Syntactic analysis ***/

    // Tokenize, parse and return parsed code
    // @throws VMXTemplateParseException
    function parse()
    {
        $this->clear_tokens();
        $r = $this->parse_exp();
        if ($this->ptr < count($this->tokens))
            $this->unexpected("<END>");
        return $r;
    }

    /**
     * Parse all code and return compiled template
     *
     * @param $code full template code
     * @param $filename input filename for error reporting
     * @param $func_ns suffix for class name (Template_SUFFIX)
     */
    function parse_all($code, $filename, $func_ns)
    {
        $blocks = array(
            array(
                'begin' => $this->options->begin_code,
                'end' => $this->options->end_code,
                'handler' => 'parse_code',
                'eat' => $this->options->eat_code_line
            ),
        );
        if ($this->options->begin_subst)
        {
            $blocks[] = array(
                'begin' => $this->options->begin_subst,
                'end' => $this->options->end_subst,
                'handler' => 'parse_subst',
                'eat' => false,
            );
        }
        // Set code
        $this->set_code($code);
        // Create new state object
        $this->st = new VMXTemplateState();
        $this->st->input_filename = $filename;
        $this->st->functions['main'] = array(
            'name' => 'main',
            'args' => array(),
            'body' => '',
        );
        $this->st->output = array(&$this->st->functions['main']['body']);
        // $text_pos = Position up to which all text was already printed
        // $pos = Instruction start position
        // $this->pos = Instruction end position
        $text_pos = 0;
        $lineno = 0;
        while ($this->pos < $this->codelen)
        {
            // Find nearest code fragment or substitution
            $min = -1;
            foreach ($blocks as $i => &$b)
            {
                $b['pos'] = strpos($this->code, $b['begin'], $this->pos);
                if ($b['pos'] !== false && ($min < 0 || $b['pos'] < $blocks[$min]['pos']))
                {
                    $min = $i;
                }
            }
            // Save outputRef before trying to run a handler because
            // if we don't the last text portion from function body will be added to MAIN
            $outputRef = &$this->st->output[count($this->st->output)-1];
            $r = '';
            if ($min >= 0)
            {
                // Set source position and line number
                $lineno = $this->lineno;
                $pos = $blocks[$min]['pos'];
                if ($pos > $this->pos)
                {
                    $this->lineno += substr_count($this->code, "\n", $this->pos, $pos-$this->pos);
                }
                $this->pos = $pos + strlen($blocks[$min]['begin']);
                if ($blocks[$min]['eat'])
                {
                    // TODO configurable eat, like in TT [%+ [%-
                    // Eat line beginning (when there are only spaces)
                    $p = $pos;
                    while ($p > 0 && ctype_space($c = $this->code{$p-1}) && $c != "\n")
                    {
                        $p--;
                    }
                    if ($p == 0 || $c == "\n")
                    {
                        $pos = $p;
                    }
                }
                // Reset token buffer
                $this->clear_tokens();
                $this->eod = $blocks[$min]['end'];
                $handler = $blocks[$min]['handler'];
                try
                {
                    // Try to parse from here, skip invalid parts
                    $r = $this->$handler();
                    $this->consume($this->eod);
                    // Add newline count from code fragment
                    $this->lineno += substr_count($this->code, "\n", $pos, $this->pos-$pos);
                }
                catch (VMXTemplateParseException $e)
                {
                    $this->warn($e->getMessage());
                    // Only skip 1 starting character and try again
                    $this->pos = $blocks[$min]['pos']+1;
                    $this->lineno = $lineno;
                    continue;
                }
                if ($blocks[$min]['eat'])
                {
                    // Eat line end (when there are only spaces)
                    $p = $this->pos;
                    while ($p < $this->codelen && ctype_space($c = $this->code{$p}) && $c != "\n")
                    {
                        $p++;
                    }
                    if ($c == "\n")
                    {
                        $this->lineno++;
                    }
                    if ($p == $this->codelen || $c == "\n")
                    {
                        if ($p < $this->codelen)
                        {
                            $p++;
                        }
                        $this->pos = $p;
                    }
                }
            }
            else
            {
                // No more code fragments and substitutions :-(
                $pos = $this->pos = $this->codelen;
            }
            if ($pos > $text_pos)
            {
                // Append text fragment
                $text = substr($this->code, $text_pos, $pos-$text_pos);
                $text = addcslashes($text, '\\\'');
                $outputRef .= "\$t.='$text';\n";
            }
            $text_pos = $this->pos;
            if ($r !== '')
            {
                // Append compiled fragment
                $outputRef .= $r."\n";
            }
        }

        // Generate code for functions
        $code = '';
        foreach ($this->st->functions as $f)
        {
            $code .= "function fn_".$f['name']." () {\n";
            $code .= "\$stack = array();\n\$t = '';\n";
            $code .= $f['body'];
            $code .= "return \$t;\n}\n";
        }

        // Assemble the class code
        $functions = var_export(array_keys($this->st->functions), true);
        $rfn = addcslashes($this->st->input_filename, '\\\'');
        $code = "<?php // {$this->st->input_filename}
class Template_$func_ns extends VMXTemplate {
static \$template_filename = '$rfn';
static \$version = ".VMXTemplate::CODE_VERSION.";
static \$functions = $functions;
function __construct(\$t) {
\$this->tpldata = &\$t->tpldata;
\$this->parent = &\$t;
}
$code
}
";

        return $code;
    }

    // Substitution
    function parse_subst()
    {
        $e = $this->parse_exp();
        return "\$t.=$e;";
    }

    // code: "IF" exp | "ELSE" | elseif exp | "END" |
    //  "SET" varref | "SET" varref '=' exp |
    //  fn name | fn name '=' exp |
    //  for varref '=' exp | for varref |
    //  "BEGIN" name bparam | "END" name | exp
    // fn: "FUNCTION" | "BLOCK" | "MACRO"
    // for: "FOR" | "FOREACH"
    // elseif: "ELSE" "IF" | "ELSIF" | "ELSEIF"
    function parse_code()
    {
        $t = strtolower($this->tok());
        if ($t == '$if')
        {
            $this->ptr++;
            $e = $this->parse_exp();
            $this->assume_eod();
            $this->st->in[] = array('if');
            return "if ($e) {";
        }
        elseif ($t == '$else')
        {
            $this->ptr++;
            if (strtolower($this->tok()) == '$if')
            {
                // Go to elseif
                $t = '$elseif';
            }
            else
                return "} else {";
        }
        // We can go to $elseif from $else, so start if() chain again
        if ($t == '$elseif' || $t == '$elsif')
        {
            $this->ptr++;
            return "} elseif (".$this->parse_exp().") {";
        }
        elseif ($t == '$for' || $t == '$foreach')
        {
            // Foreach-style loop
            // FOR[EACH] varref = array
            // (default array = varref itself)
            $this->ptr++;
            $parts = $this->parse_varref();
            $exp = false;
            if ($this->tok() == '=')
            {
                $this->ptr++;
                $exp = $this->parse_exp();
            }
            $this->assume_eod();
            $this->st->in[] = array('for', $parts, $exp);
            return $this->gen_foreach($parts, $exp);
        }
        elseif ($t == '$begin')
        {
            // Old-style loop
            $this->ptr++;
            return $this->parse_begin();
        }
        elseif ($t == '$end')
        {
            // End directive
            $this->ptr++;
            return $this->parse_end();
        }
        elseif ($t == '$set')
        {
            if ($this->tok(1) == '(')
            {
                // This is the set() function, parse it as an expression
                return $this->parse_exp();
            }
            // SET directive
            $this->ptr++;
            $def = $this->parse_varref();
            if ($this->tok() == '=')
            {
                // SET varref = exp
                $this->ptr++;
                $e = $this->parse_exp();
                return $this->gen_varref($def) . ' = ' . $e . ';';
            }
            $this->assume_eod();
            $this->st->in[] = array('set', $def);
            return "\$stack[] = \$t;\n\$t = '';";
        }
        elseif ($t == '$function' || $t == '$block' || $t == '$macro')
        {
            // Function declaration
            $this->ptr++;
            return $this->parse_function();
        }
        // Expression
        $t = $this->parse_exp();
        if ($this->options->no_code_subst)
        {
            // Substitute only $subst_begin..$subst_end
            return "$t;";
        }
        return "\$t.=$t;";
    }

    // Parse an old-style loop
    // BEGIN block [AT e] [BY e] [TO e]
    function parse_begin()
    {
        $bname = $this->consume('$');
        $at = $by = $to = false;
        while (true)
        {
            $tok = strtolower($this->tok());
            $this->ptr++;
            if ($at === false && $tok == '$at')
                $at = $this->parse_exp();
            elseif ($by === false && $tok == '$by')
                $by = $this->parse_exp();
            elseif ($to === false && $tok == '$to')
                $to = $this->parse_exp();
            else
            {
                $this->ptr--;
                break;
            }
        }
        $this->assume_eod();
        $this->st->blocks[] = $bname;
        $parts = $this->st->blocks;
        $this->st->in[] = array('begin', array($bname), $t);
        $exp = $this->gen_varref($parts);
        if ($at || $to)
        {
            $exp = "array_slice($e, ";
            $exp .= $at ? $at : 0;
            if ($to)
                $exp .= ", $to";
            $exp .= ")";
        }
        if ($by)
            $exp = "self::exec_subarray_divmod($exp, $by)";
        return $this->gen_foreach($parts, $exp);
    }

    // Parse END directive - may correspond to one of:
    // FOREACH, BEGIN, IF, SET or FUNCTION
    // Optionally with varref specifying what block should end here.
    function parse_end()
    {
        $end_subj = false;
        if (substr($this->tok(), 0, 1) == '$')
        {
            $end_subj = $this->parse_varref();
        }
        $this->assume_eod();
        if (!count($this->st->in))
        {
            $this->raise("END without begin directive");
        }
        $in = array_pop($this->st->in);
        $w = $in[0];
        $begin_subj = isset($in[1]) ? $in[1] : false;
        if ($begin_subj)
        {
            $b = implode('.', $begin_subj);
            if ($end_subj ? $b != ($e = implode('.', $end_subj)) : $this->options->strict_end)
            {
                $w = strtoupper($w);
                $this->raise(
                    $b ? "END $e after $w $b"
                       : "END subject not specified (after $w $b) in strict mode"
                );
            }
        }
        if ($w == 'set')
        {
            return $this->gen_varref($in[1])." = \$t;\n\$t = array_pop(\$stack);";
        }
        elseif ($w == 'function')
        {
            array_pop($this->st->output);
            return '';
        }
        elseif ($w == 'begin' || $w == 'for')
        {
            if ($w == 'begin')
                array_pop($st->blocks);
            list($varref, $varref_index) = $this->varref_and_index($in[1]);
            return "}
array_pop(\$stack);
$varref_index = array_pop(\$stack);
$varref = array_pop(\$stack);";
        }
        return "}";
    }

    // Function definition (with named arguments)
    // Such functions are always called as fn(name => value, ...)
    // FUNCTION/BLOCK/MACRO name (arglist) [ = expression]
    function parse_function()
    {
        list($pos, $line) = $this->tokpos();
        $name = $this->consume('$');
        $args = array();
        if ($this->tok() == '(')
        {
            $this->ptr++;
            while ($this->tok() != ')')
            {
                $args[] = $this->consume('$');
                if ($this->tok() == ',')
                    $this->ptr++;
            }
        }
        $code = false;
        if ($this->tok() == '=')
        {
            $code = $this->parse_exp();
        }
        $this->assume_eod();
        if (isset($this->st->functions[$name]))
        {
            $this->raise(
                "Attempt to redeclare function $name, previously defined on line ".
                ($this->st->functions[$name]['line']+1)." (byte ".
                ($this->st->functions[$name]['pos']).")"
            );
        }
        $this->st->functions[$name] = array(
            'name' => $name,
            'args' => $args,
            'pos'  => $pos,
            'line' => $line,
            'body' => '',
        );
        $this->st->in[] = array('function', array($name));
        $this->st->output[] = &$this->st->functions[$name]['body'];
    }

    // Make and return loop varref and loop index varref
    function varref_and_index($parts)
    {
        $varref = $this->gen_varref($parts);
        $varref_index = substr($varref, 0, -1) . ".'_index']";
        return array($varref, $varref_index);
    }

    // Generate foreach() code (FOR $parts = $exp)
    function gen_foreach($parts, $exp)
    {
        list($varref, $varref_index) = $this->varref_and_index($parts);
        if (!$exp)
            $exp = $varref;
        // FIXME We'll have a problem in Perl version here (arrays vs hashes)
        return
"\$stack[] = $varref;
\$stack[] = $varref_index;
\$stack[] = 0;
foreach (self::array1($exp) as \$item) {
$varref = \$item;
$varref_index = \$stack[count(\$stack)-1]++;";
    }

    // exp: ops_or | ops_or "|" exp
    function parse_exp()
    {
        if (strtolower($this->tok()) == '$not')
        {
            $this->ptr++;
            return '(!'.$this->parse_exp().')';
        }
        $e = array($this->parse_or());
        while ($this->tok() == '|')
        {
            $this->ptr++;
            $e[] = $this->parse_or();
        }
        $e = "(" . implode(") . (", $e) . ")";
        return $e;
    }

    // ops_or: ops_and | ops_and "||" ops_or | ops_and "OR" ops_or | ops_and "XOR" ops_or
    function parse_or()
    {
        $ops = array('||', '$or', '$xor');
        $e = array($this->parse_ops('and'));
        $xor = false;
        while (in_array($t = strtolower($this->tok()), $ops))
        {
            $this->ptr++;
            if ($t == '$xor')
                $xor = true;
            $e[] = $t == '$xor' ? 'XOR' : '||';
            $e[] = $this->parse_ops('and');
        }
        if (count($e) == 1)
            return $e[0];
        if ($xor)
            return "(".implode(' ', $e).")";
        // Expressions without XOR are executed as the "perlish OR"
        $args = array();
        for ($i = 0, $j = 0; $i < count($e); $i += 2)
            $args[$j++] = $e[$i];
        return "self::perlish_or(".implode(",", $args).")";
    }

    // Parse operator expression. See self::$ops
    function parse_ops($name)
    {
        list($ops, $next, $repeat) = self::$ops[$name];
        if (isset(self::$ops[$next]))
            $next = array(array($this, 'parse_ops'), array($next));
        else
            $next = array(array($this, 'parse_'.$next), array());
        $e = call_user_func_array($next[0], $next[1]);
        $brace = false;
        while (in_array($t = strtolower($this->tok()), $ops))
        {
            $this->ptr++;
            $e .= ' ';
            $e .= $t{0} == '$' ? substr($t, 1) : $t;
            $e .= ' ';
            $e .= call_user_func_array($next[0], $next[1]);
            $brace = true;
            if (!$repeat)
                break;
        }
        return $brace ? "($e)" : $e;
    }

    // exp_neg: exp_not | '-' exp_not
    function parse_neg()
    {
        $neg = false;
        if ($this->tok() == '-')
        {
            $neg = true;
            $this->ptr++;
        }
        $e = $this->parse_not();
        return $neg ? "-($e)" : $e;
    }

    // exp_not: nonbrace | '(' exp ')' varpath | '!' exp_not | "NOT" exp_not
    function parse_not()
    {
        $t = $this->tok();
        if ($t == '!')
        {
            $this->ptr++;
            $r = '(!'.$this->parse_not().')';
        }
        elseif ($t == '(')
        {
            $this->ptr++;
            $r = $this->parse_exp();
            $this->consume(')');
            // FIXME parse_varpath here
        }
        else
        {
            $r = $this->parse_nonbrace();
        }
        return $r;
    }

    // nonbrace: '{' hash '}' | literal | varref | func '(' list ')' | func '(' gthash ')' | func nonbrace
    // func: name | varref varpart
    function parse_nonbrace()
    {
        $t = $this->tok();
        if ($t == '{')
        {
            $this->ptr++;
            if ($this->tok() != '}')
            {
                $r = 'array(' . $this->parse_hash() . ')';
                $this->consume('}');
            }
        }
        elseif ($t{0} == '#')
        {
            // Literal
            $r = substr($t, 1);
            $this->ptr++;
        }
        elseif ($t{0} == '$')
        {
            // Name => varref or function call
            // No support for obj.method().other_method() call syntax
            // as PHP itself is nervous for it
            $parts = $this->parse_varref();
            $t = $this->tok();
            if ($t{0} == '$' || $t{0} == '#' || $t == '{')
            {
                // Name, literal, { -> Single argument function call without braces
                $r = $this->call_ref($parts, 'list', array($this->parse_nonbrace()));
            }
            elseif ($t == '(')
            {
                // ( -> function call with braces
                $this->ptr++;
                list($type, $args) = $this->parse_list_or_gthash();
                $r = $this->call_ref($parts, $type, $args);
                $this->consume(')');
            }
            else
            {
                // Nothing after the varref
                $r = $this->gen_varref($parts);
            }
        }
        else
            $this->unexpected(array('{', '#', '$'));
        return $r;
    }

    // list_or_gthash: list | gthash
    // list: exp | exp ',' list
    // gthash: gtpair | gtpair ',' gthash |
    // gtpair: exp '=>' exp
    function parse_list_or_gthash()
    {
        $beg = $this->ptr;
        try
        {
            $r = $this->parse_exp();
        }
        catch(VMXTemplateParseException $e)
        {
            $this->ptr = $beg;
            return array('list', array());
        }
        $t = $this->tok();
        if ($t == '=>')
        {
            // hash separated with '=>', string output
            $this->ptr++;
            $type = 'hash';
            $r .= ' => ';
            $r .= $this->parse_exp();
            $r .= ', ';
            while ($this->tok() == ',')
            {
                $this->ptr++;
                $r .= $this->parse_exp();
                $r .= ' => ';
                $this->consume('=>');
                $r .= $this->parse_exp();
                $r .= ', ';
            }
            $r = "array($r)";
        }
        else
        {
            // list separated with ',', array output
            $type = 'list';
            $r = array($r);
            while ($this->tok() == ',')
            {
                $this->ptr++;
                $r[] = $this->parse_exp();
            }
        }
        return array($type, $r);
    }

    // list: exp | exp ',' list
    function parse_list()
    {
        $r = $this->parse_exp();
        while ($this->tok() == ',')
        {
            $this->ptr++;
            $r .= ', '.$this->parse_exp();
        }
        return $r;
    }

    // hash: pair | pair ',' hash |
    // pair: exp ',' exp | exp '=>' exp
    function parse_hash()
    {
        $r = '';
        $this->ptr--;
        do
        {
            $this->ptr++;
            if ($this->tok() == '}')
                return $r;
            $k = $this->parse_exp();
            $this->consume(array(',', '=>'));
            $v = $this->parse_exp();
            $r .= "$k => $v, ";
        } while ($this->tok() == ',');
        return $r;
    }

    // varref: name | varref varpart
    // varpart: '.' name | '[' exp ']'
    // varpath: | varpath varpart
    // (always begins with name)
    function parse_varref()
    {
        $r = $this->consume('$');
        $a = array($r);
        $t = $this->tok();
        while ($t == '.' || $t == '[')
        {
            $this->ptr++;
            if ($t == '.')
            {
                $a[] = $this->consume('$');
            }
            else
            {
                $a[] = '['.$this->parse_exp().']';
                $this->consume(']');
            }
            $t = $this->tok();
        }
        return $a;
    }

    // Generate varref code from parse_varref output
    function gen_varref($parts)
    {
        $r = '$this->tpldata[\''.addcslashes($parts[0], '\\\'').'\']';
        for ($i = 1; $i < count($parts); $i++)
        {
            if ($parts[$i]{0} == '[')
                $r .= $parts[$i];
            else
                $r .= '[\''.addcslashes($parts[$i], '\\\'').'\']';
        }
        return $r;
    }

    // Construct function call code from $parts (varref parts)
    // and $args (compiled expressions for function arguments)
    // $args = array('list', <list items>) or array('hash', <hash key>, <hash value>, ...)
    function call_ref($parts, $type, $args)
    {
        $r = false;
        if ($type == 'hash')
        {
            if (count($parts) > 1)
            {
                $this->raise("Object method calls with hash arguments are impossible");
            }
            $r = "\$this->parent->call_block($parts[0], $args, \"".addslashes($this->errorinfo())."\")";
        }
        if (count($parts) == 1)
        {
            $fn = strtolower($parts[0]);
            if (isset(self::$functions[$fn]))
            {
                // Builtin function call using alias
                $fn = 'function_'.self::$functions[$fn];
                $r = call_user_func_array(array($this, $fn), $args);
            }
            elseif (method_exists($this, "function_$fn"))
            {
                // Builtin function call using name
                $fn = "function_$fn";
                $r = call_user_func_array(array($this, $fn), $args);
            }
            elseif (isset($this->options->compiletime_functions[$fn]))
            {
                // Custom compile-time function call
                $r = call_user_func($this->options->compiletime_functions[$fn], $this, $args);
            }
            else
            {
                $this->raise("Unknown function: '$fn'");
            }
        }
        else
        {
            // Object method call
            $fn = array_pop($parts);
            $r = $this->gen_varref($parts).'->';
            if ($fn{0} == '[')
                $r .= '{'.substr($fn, 1, -1).'}';
            elseif (preg_match('/\W/s', $fn))
                $r .= '{\''.addcslashes($fn, '\\\'').'\'}';
            else
                $r .= $fn;
            $r .= '('.implode(', ', $args).')';
        }
        return $r;
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

    /* преобразование символов <>&'" в HTML-сущности &lt; &gt; &amp; &apos; &quot; */
    function function_html($e)                  { return "htmlspecialchars($e,ENT_QUOTES)"; }

    /* удаление всех или заданных тегов */
    function function_strip($e, $t='')          { return "strip_tags($e".($t?",$t":"").")"; }

    /* удаление "небезопасных" HTML-тегов */
    function function_strip_unsafe($e)          { return "strip_tags($e, self::\$safe_tags)"; }

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
        return "self::" . ($this->options->use_utf8 ? "mb_" : "") . "strlimit(".join(",", $a).")";
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

    /* пары id => ключ, name => значение для ассоциативного массива */
    function function_pairs($a) { return "self::exec_pairs(is_array($a) ? $a : array())"; }

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
    function function_dump($var)
    {
        return "self::exec_dump($var)";
    }

    /* JSON-кодирование */
    function function_json($v)  { return "json_encode($v, JSON_UNESCAPED_UNICODE)"; }

    /* Аргументы для функций включения
       аргументы ::= hash(ключ => значение, ...) | ключ => значение, ...
    */
    function auto_hash($args)
    {
        if (!($n = count($args)))
            $args = NULL;
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
        $args = $this->auto_hash($args);
        return "\$this->parent->parse_discard($file, NULL, 'main'$args)";
    }

    /* включение блока из текущего файла: exec('блок'[, аргументы]) */
    function function_exec()
    {
        $args = func_get_args();
        $block = array_shift($args);
        $args = $this->auto_hash($args);
        return "\$this->parent->parse_discard(self::\$template_filename, NULL, $block$args)";
    }

    /* включение блока из другого файла: exec_from('файл', 'блок'[, аргументы]) */
    function function_exec_from()
    {
        $args = func_get_args();
        $file = array_shift($args);
        $block = array_shift($args);
        $args = $this->auto_hash($args);
        return "\$this->parent->parse_discard($file, NULL, $block$args)";
    }

    /* parse не из файла, хотя и не рекомендуется */
    function function_parse_inline()
    {
        $args = func_get_args();
        $code = array_shift($args);
        $args = $this->auto_hash($args);
        return "\$this->parent->parse_discard(NULL, $code, 'main'$args)";
    }

    /* сильно не рекомендуется, но возможно:
       включение блока не из файла:
       exec_from_inline('код', 'блок'[, аргументы]) */
    function function_exec_from_inline()
    {
        $args = func_get_args();
        $code = array_shift($args);
        $block = array_shift($args);
        $args = $this->auto_hash($args);
        return "\$this->parent->parse_discard(NULL, $code, $block$args)";
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
        if (!method_exists($this, "function_$f"))
        {
            $this->raise("Unknown function specified for map(): $f");
            return NULL;
        }
        $f = "function_$f";
        $f = $this->$f('$arg');
        $args = func_get_args();
        array_shift($args);
        return "call_user_func('array_map', create_function('$arg', $f), self::merge_to_array(".implode(", ", $args)."))";
    }
}
