<?php

/**
 * "Ох уж эти перлисты... что ни пишут - всё Template Toolkit получается!"
 * "Oh, those perlists... they could write anything, and a result is another Template Toolkit"
 * Rewritten 4 times: phpbb -> regex -> index() -> recursive descent -> LIME LALR(1)
 *
 * Homepage: http://yourcmc.ru/wiki/VMX::Template
 * License: GNU GPLv3 or later
 * Author: Vitaliy Filippov, 2006-2013
 * $Id$
 *
 * The template engine is split into two parts:
 * (1) This file - always used when running templates
 * (2) template.parser.php - used only when compiling new templates
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

# TODO For perl version - rewrite it and prevent auto-vivification on a.b

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
    static $safe_tags   = 'div|blockquote|span|a|b|i|u|p|h1|h2|h3|h4|h5|h6|strike|strong|small|big|blink|center|ol|pre|sub|sup|font|br|table|tr|td|th|tbody|tfoot|thead|tt|ul|li|em|img|marquee|cite';

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
    const CODE_VERSION  = 4;

    // Data passed to the template
    var $tpldata = array();

    // Parent 'VMXTemplate' object for compiled templates
    // parse_anything() functions are always called on $this->parent
    var $parent = NULL;

    // Failed-to-load filenames, saved to skip them during the request
    var $failed = array();

    // Search path for template functions (filenames indexed by function name)
    var $function_search_path = array();

    // Options, compiler objects
    var $options, $compiler;

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
        return @self::$cache[$key];
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
            if (!class_exists($class))
            {
                if (!($file = $this->compile($inline, '')))
                    return NULL;
                include $file;
            }
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
                    $e = error_get_last();
                    $this->options->error("couldn't load template file '$fn': ".$e['message'], true);
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
                    $this->options->error("error including compiled template for '$fn'", true);
                    $this->failed[$fn] = true;
                    return NULL;
                }
                if (!class_exists($class) || !isset($class::$version) || $class::$version < self::CODE_VERSION)
                {
                    // Force recompile
                    $file = $this->compile($text, $fn, true);
                    $this->options->error(
                        "Invalid or stale cache '$file' for template '$fn'. Caused by one of:".
                        " template upgrade (error should go away on next run), two templates with same content (change or merge), or an MD5 collision :)", true
                    );
                    return NULL;
                }
                foreach ($class::$functions as $loaded_function => $true)
                {
                    // FIXME Do it better
                    // Remember functions during file loading
                    $this->function_search_path[$loaded_function][] = $fn;
                }
            }
        }
        if (!isset($class::$functions[$func]))
        {
            $this->options->error("No function '$func' found in ".($fn ? "template $fn" : 'inline template'), true);
            return NULL;
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
            $mtime = @stat($fn);
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
            if ($fp = @fopen($fn, "rb"))
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

        if (!$this->compiler)
        {
            require_once(dirname(__FILE__).'/template.parser.php');
            $this->compiler = new VMXTemplateCompiler($this->options);
        }
        $compiled = $this->compiler->parse_all($code, $fn, $func_ns);
        if (!file_put_contents($file, $compiled))
        {
            throw new VMXTemplateException("Failed writing $file");
        }

        return $file;
    }

    /*** Built-in filters ***/

    /**
     * Strips space from the beginning and ending of each line
     */
    static function filter_strip_space(&$text)
    {
        $text = preg_replace('/^[ \t]+/m', '', $text);
        $text = preg_replace('/[ \t]+$/m', '', $text);
    }

    /*** Function implementations ***/

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
        $this->parent->options->error("Unknown function: '$f'");
        return NULL;
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

    // Replace tags with whitespace
    static function strip_tags($str, $allowed = false)
    {
        $allowed = $allowed ? '(?!/?('.$allowed.'))' : '';
        return preg_replace('#(<'.$allowed.'/?[a-z][a-z0-9-]*(\s+[^<>]*)?>\s*)+#is', ' ', $str);
    }

    // Ignore result
    function void($a)
    {
        return '';
    }

    // Select one of 3 plural forms for russian language
    static function plural_ru($count, $one, $few, $many)
    {
        $sto = $count % 100;
        if ($sto >= 10 && $sto <= 20)
            return $many;
        switch ($count % 10)
        {
            case 1: return $one;
            case 2:
            case 3:
            case 4: return $few;
        }
        return $many;
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
                $ts = time();
        }
        elseif (preg_match('/^\D*(\d{4,})\D*(\d{2})\D*(\d{2})\D*(?:(\d{2})\D*(\d{2})\D*(\d{2})\D*([\+\- ]\d{2}\D*)?)?$/s', $ts, $m))
        {
            // TS_DB, TS_DB_DATE, TS_MW, TS_EXIF, TS_ISO_8601
            $ts = mktime(0+@$m[4], 0+@$m[5], 0+@$m[6], $m[2], $m[3], $m[1]);
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

/**
 * Options class
 */
class VMXTemplateOptions
{
    var $begin_code    = '<!--';    // instruction start
    var $end_code      = '-->';     // instruction end
    var $begin_subst   = '{';       // substitution start (may be turned off via false)
    var $end_subst     = '}';       // substitution end (may be turned off via false)
    var $no_code_subst = false;     // do not substitute expressions in instructions
    var $eat_code_line = true;      // remove the "extra" lines which contain instructions only
    var $root          = '.';       // directory with templates
    var $cache_dir     = false;     // compiled templates cache directory
    var $reload        = 1;         // 0 means to not check for new versions of cached templates
    var $filters       = array();   // filter to run on output of every template
    var $use_utf8      = true;      // use UTF-8 for all string operations on template variables
    var $raise_error   = false;     // die() on fatal template errors
    var $log_error     = false;     // send errors to standard error output
    var $print_error   = false;     // print fatal template errors
    var $strip_space   = false;     // strip spaces from beginning and end of each line
    var $auto_escape   = false;     // "safe mode" (try 's' for HTML) - automatically escapes substituted
                                    // values via this functions if not escaped explicitly
    var $compiletime_functions = array();   // custom compile-time functions (code generators)

    // Logged errors (not an option)
    var $input_filename;
    var $errors;

    function __construct($options = array())
    {
        $this->set($options);
        $this->errors = array();
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
        if ($this->strip_space && array_search('strip_space', $this->filters) === false)
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

    function __destruct()
    {
        if ($this->print_error && $this->errors && PHP_SAPI != 'cli')
        {
            print '<div id="template-errors" style="display: block; border: 1px solid black; padding: 8px; background: #fcc">'.
                'VMXTemplate errors:<ul><li>'.
                implode('</li><li>', array_map('nl2br', array_map('htmlspecialchars', $this->errors))).
                '</li></ul>';
                $fp = fopen("php://stderr", 'a');
                fputs($fp, "VMXTemplate errors:\n".implode("\n", $this->errors));
                fclose($fp);
        }
    }

    /**
     * Log an error or a warning
     */
    function error($e, $fatal = false)
    {
        $this->errors[] = $e;
        if ($this->raise_error && $fatal)
            die("VMXTemplate error: $e");
        if ($this->log_error)
            error_log("VMXTemplate error: $e");
        elseif ($this->print_error && PHP_SAPI == 'cli')
            print("VMXTemplate error: $e\n");
    }
}
