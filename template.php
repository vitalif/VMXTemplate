<?php
/***************************************************************************
 *                              template.php
 *                            -------------------
 *   begin                : Saturday, Feb 13, 2001
 *   change               : Thirsday, Aug 03, 2006
 *   copyright            : (C) 2001 The phpBB Group + VMX
 *   email                : vmx@yourcmc.ru
 *
 ***************************************************************************/

/***************************************************************************
 *
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation; either version 2 of the License, or
 *   (at your option) any later version.
 *
 ***************************************************************************/

/**
 * Template class. By Nathan Codding of the phpBB group.
 * The interface was originally inspired by PHPLib templates,
 * and the template file formats are quite similar.
 *
 * 2006 - Corrected and modified by Vitali Filippov [VMX]
 */

/**
 * Documentation:
 * <!-- BEGIN * --> and <!-- END * --> can be placed on one line
 * {block_name.block_name.etc....varname} = varref varname of current iteration of block block_name.block_name.etc...
 * {block_name.block_name.etc....varname|varoption} = varref varname if it's set or block_name.block_name.etc....varoption if not
 * {block_name.#} = number of current iteration of block block_name
 * <!-- BEGIN block_name --> = begin block block_name, blocks can be nested
 * <!-- END block_name --> = end block
 * <!-- INCLUDE filename --> = include file "filename" directly at this point (path relative to current template file path)
 * <!-- BEGIN block_name AT #start[ #count] --> = begin block_name at iteration #start and do #count iterations (or 1 by default)
 * <!-- BEGIN block_name MOD #div #mod --> = do block_name iterations with numbers #no if (#no % #div) = #mod
 *
 * Документация:
 * {VAR} - подстановка корневой переменной VAR
 * <!-- INCLUDE filename --> = дословное включение файла "filename"
 * <!-- BEGIN блок1 --> = обработать в цикле все итерации блока "блок1"
 * <!-- BEGIN блок1 AT <начало>[ <количество>] --> = обработать в цикле <количество> (или все оставшиеся если <количество> не задано) итераций блока "блок1"
 * <!-- BEGIN блок1 MOD <делитель> <остаток> --> = обработать в цикле все итерации блока "блок1", номера которых по модулю <делитель> равны <остаток>
 * <!-- END блок1 --> = конец тела цикла
 * Блоки могут быть вложенными, <!-- BEGIN ... --> и <!-- END ... --> могут быть расположены на одной строке.
 * Подстановки внутриблоковых переменных работают внутри блока :)
 * {блок1.блок2.и_так_далее.VAR} = подстановка переменной VAR блока "блок1.блок2.и_так_далее"
 * {и_так_далее.#} = номер текущей итерации блока "блок1.блок2.и_так_далее", если "и_так_далее" сейчас вложен в "блок1.блок2"
 * {блок1.блок2.и_так_далее.VAR|VAR2} = подстановка переменной VAR, а если она не задана - то VAR2 блока "блок1.блок2.и_так_далее"
 * <!--# Комментарий, не попадающий в выходной HTML файл #-->
 */

class Template
{
	var $classname = "Template";

	// set this variable to cache directory and template compiler will use caching
	var $cachedir = false;

	// variable that holds all the data we'll be substituting into
	// the compiled templates.
	// ...
	// This will end up being a multi-dimensional array like this:
	// $this->_tpldata[block.][iteration#][child.][iteration#][child2.][iteration#][variablename] == value
	// if it's a root-level variable, it'll be like this:
	// $this->_tpldata[.][0][varname] == value
	var $_tpldata = array();

	// Hash of filenames for each template handle.
	var $files = array();

	// Root template directory.
	var $root = "";

	// this will hash handle names to the compiled code for that handle.
	var $compiled_code = array();

	// This will hold the uncompiled code for that handle.
	var $uncompiled_code = array();

	// This option causes pparse() to be equal to "echo rparse()"
	var $no_pparse = false;

	// Set this to the name of "wrapper" function, which is called by
	// rparse() after compiling and running.
	var $wrapper = false;

	/**
	 * Constructor. Simply sets the root dir.
	 */
	function Template($root = ".")
	{
		$this->set_rootdir($root);
	}

	/**
	 * Destroys this template object. Should be called when you're done with it, in order
	 * to clear out the template data so you can load/parse a new template set.
	 */
	function destroy()
	{
		$this->_tpldata = array();
	}

	/**
	 * Sets the template root directory for this Template object.
	 */
	function set_rootdir($dir)
	{
		if (!is_dir($dir))
			return false;
		$this->root = $dir;
		return true;
	}

	/**
	 * Sets the template filenames for handles. $filename_array
	 * should be a hash of handle => filename pairs.
	 */
	function set_filenames($filename_array)
	{
		if (!is_array($filename_array))
			return false;

		reset($filename_array);
		while(list($handle, $filename) = each($filename_array))
			$this->files[$handle] = $this->make_filename($filename);

		return true;
	}

	/**
	 * Sets the template code for handle directly, without loading it from any files.
	 */
	function set_template_code ($handle, $code)
	{
		$this->files[$handle] = false;
		$this->uncompiled_code[$handle] = $code;
		unset ($this->compiled_code[$handle]);
		return true;
	}

	/**
	 * Load the file for the handle, compile the file,
	 * and run the compiled code. This will print out
	 * the results of executing the template.
	 */
	function pparse($handle)
	{
		if ($this->no_pparse)
		{
			echo $this->rparse ($handle);
			return;
		}

		if (!$this->loadfile($handle))
			die("Template->pparse(): Couldn't load template file for handle $handle");

		// actually compile the template now.
		if (!isset($this->compiled_code[$handle]) || empty($this->compiled_code[$handle]))
			$this->compiled_code[$handle] = $this->compile($this->uncompiled_code[$handle]);
		
		//echo ($this->compiled_code[$handle]);
		
		// Run the compiled code.
		eval($this->compiled_code[$handle]);
		return true;
	}

	/**
	 * Load the file for the handle, compile the file,
	 * and run the compiled code. This will RETURN
	 * the results of executing the template.
	 */
	function rparse ($handle)
	{
		if (!$this->loadfile($handle))
			die("Template->rparse(): Couldn't load template file for handle $handle");

		// Compile it, with the "no echo statements" option on.
		$_str = "";
		$code = $this->compile($this->uncompiled_code[$handle], true, '_str');

		// evaluate the variable assignment.
		eval($code);

		// call wrapper if it's set
		if ($this->wrapper)
		{
			$fn = $this->wrapper;
			$_str = $fn ($_str);
		}

		// return the value of the generated variable.
		return $_str;
	}

	/**
	 * Inserts the uncompiled code for $handle as the
	 * value of $varname in the root-level. This can be used
	 * to effectively include a template in the middle of another
	 * template.
	 * Note that all desired assignments to the variables in $handle should be done
	 * BEFORE calling this function.
	 */
	function assign_var_from_handle($varname, $handle)
	{
		if (!$this->loadfile($handle))
			die("Template->assign_var_from_handle(): Couldn't load template file for handle $handle");

		// Compile it, with the "no echo statements" option on.
		$_str = "";
		$code = $this->compile($this->uncompiled_code[$handle], true, '_str');

		// evaluate the variable assignment.
		eval($code);
		// assign the value of the generated variable to the given varname.
		$this->assign_var($varname, $_str);

		return true;
	}

	/**
	 * Block-level variable assignment. Adds a new block iteration with the given
	 * variable assignments. Note that this should only be called once per block
	 * iteration.
	 */
	function assign_block_vars($blockname, $vararray)
	{
		if (strstr($blockname, '.'))
		{
			// Nested block.
			$blocks = explode('.', $blockname);
			$blockcount = sizeof($blocks) - 1;
			$str = '$this->_tpldata';
			for ($i = 0; $i < $blockcount; $i++)
			{
				$str .= '[\'' . $blocks[$i] . '.\']';
				eval('$lastiteration = sizeof(' . $str . ') - 1;');
				$str .= '[' . $lastiteration . ']';
			}
			// Now we add the block that we're actually assigning to.
			// We're adding a new iteration to this block with the given
			// variable assignments.
			$str .= '[\'' . $blocks[$blockcount] . '.\'][] = $vararray;';

			// Now we evaluate this assignment we've built up.
			eval($str);
		}
		else
		{
			// Top-level block.
			// Add a new iteration to this block with the variable assignments
			// we were given.
			$this->_tpldata[$blockname . '.'][] = $vararray;
		}
		return true;
	}

	/**
	 * Block-level variable assignment. This function does not add any iterations
	 * to block, it only appends $vararray to last existing iteration. [VMX 2006]
	 */
	function append_block_vars($blockname, $vararray)
	{
		if (strstr($blockname, '.'))
		{
			// Nested block.
			$blocks = explode('.', $blockname);
			$blockcount = sizeof($blocks);
			$str = '$this->_tpldata';
			for ($i = 0; $i < $blockcount; $i++)
			{
				$str .= '[\'' . $blocks[$i] . '.\']';
				eval('$lastiteration = sizeof(' . $str . ') - 1;');
				$str .= '[' . $lastiteration . ']';
			}
			eval ($str .= ' = array_merge ('.$str.', $vararray);');
		}
		else
		{
			// Top-level block.
			if (($len = count ($this->_tpldata[$blockname . '.'])) > 0)
				$this->_tpldata[$blockname.'.'][$len-1] = array_merge ($this->_tpldata[$blockname . '.'][$len-1], $vararray);
		}
		return true;
	}

	/**
	 * Root-level variable assignment. Adds to current assignments, overriding
	 * any existing variable assignment with the same name.
	 */
	function assign_vars($vararray)
	{
		reset ($vararray);
		while (list($key, $val) = each($vararray))
			$this->_tpldata['.'][0][$key] = $val;
		return true;
	}

	/**
	 * Root-level variable assignment. Adds to current assignments, overriding
	 * any existing variable assignment with the same name.
	 */
	function assign_var($varname, $varval)
	{
		$this->_tpldata['.'][0][$varname] = $varval;
		return true;
	}


	/**
	 * Generates a full path+filename for the given filename, which can either
	 * be an absolute name, or a name relative to the rootdir for this Template
	 * object.
	 */
	function make_filename($filename)
	{
		// Check if it's an absolute or relative path.
		if (substr($filename, 0, 1) != '/')
       		$filename = $this->root . '/' . $filename;//($rp_filename = phpbb_realpath($this->root . '/' . $filename)) ? $rp_filename : $filename;
		
		if (!file_exists($filename))
			die("Template->make_filename(): Error - file $filename does not exist");
		return $filename;
	}

	/**
	 * If not already done, load the file for the given handle and populate
	 * the uncompiled_code[] hash with its code. Do not compile.
	 */
	function loadfile($handle)
	{
		// If the file for this handle is already loaded and compiled, do nothing.
		if (isset($this->uncompiled_code[$handle]) && !empty($this->uncompiled_code[$handle]))
			return true;

		// If we don't have a file assigned to this handle, die.
		if (!isset($this->files[$handle]))
			die("Template->loadfile(): No file specified for handle $handle");

		// << VMX >> if $this->files[$handle] is false - template contents are specified directly
		if ($this->files[$handle] !== false)
		{
			$filename = $this->files[$handle];
			$filepath = substr ($filename, 0, strrpos ($filename, '/')+1);

			$str = @file_get_contents ($filename);
			if (empty($str))
				die("Template->loadfile(): File $filename for handle $handle is empty");

			// Handle <!-- INCLUDE --> instructions
			while (preg_match ('#<!-- INCLUDE (.*) -->#', $str, $m))
				$str = str_replace ($m[0], @file_get_contents ($filepath . $m[1]), $str);

			$this->uncompiled_code[$handle] = $str;
		}
		return true;
	}

	/**
	 * Compiles the given string of code, and returns
	 * the result in a string.
	 * If "do_not_echo" is true, the returned code will not be directly
	 * executable, but can be used as part of a variable assignment
	 * for use in assign_code_from_handle() or rparse().
	 */
	function compile($code, $do_not_echo = false, $retvar = '')
	{
		if ($this->cachedir)
		{
			$sfile = $this->cachedir . ($do_not_echo ? 'alt_' . $retvar : '') . md5 ($code) . '.tps';
			if (($cached = @file_get_contents ($sfile)) !== false)
				return $cached;
		}
		else
			unset ($sfile);
		$default_addmode = $do_not_echo ? '$' . $retvar . ' .= ' : 'echo ';

		// Сначала <!--# комментарии #-->
		while (preg_match ('%\s*<!--#%', $code, $m, PREG_OFFSET_CAPTURE))
		{
			$p = $m[0][1];
			$l = strlen($m[0][0]);
			if (($p2 = strpos ($code, '#-->', $p+$l)) !== false)
				$code = substr ($code, 0, $p) . substr ($code, $p2+4);
			else
				break;
		}

		// Вытаскиваем <!-- BEGIN --> и <!-- END --> на отдельные "строки"
		$code = str_replace ("\r", "", $code);
		while (preg_match ("#(\n|^)[ \t]*(<!-- (?:BEGIN|END) (?:[^<>]*) -->)[ \t]*(\n|$)#", $code, $m, PREG_OFFSET_CAPTURE))
		{
			$rp = "\x1" . $m[2][0] . "\x1\n";
			$code = substr ($code, 0, $m[0][1]) . $rp . substr ($code, $m[0][1]+strlen($m[0][0]));
		}
		// Собственно говоря, то что выше - чисто для красоты выходного HTML...
		while (preg_match ("#([^\x1])(<!-- (?:BEGIN|END) (?:[^<>]*) -->)#", $code, $m, PREG_OFFSET_CAPTURE))
			$code = preg_replace ("#([^\x1])(<!-- (?:BEGIN|END) (?:[^<>]*) -->)#", "\\1\x1\\2", $code);
		while (preg_match ("#(<!-- (?:BEGIN|END) (?:[^<>]*) -->)([^\x1])#", $code, $m, PREG_OFFSET_CAPTURE))
			$code = preg_replace ("#(<!-- (?:BEGIN|END) (?:[^<>]*) -->)([^\x1])#", "\\1\x1\\2", $code);

		// replace \ with \\ and then ' with \'.
		$code = str_replace('\\', '\\\\', $code);
		$code = str_replace('\'', '\\\'', $code);

		// VMX :: handle iteration numbers
		$code = preg_replace ('/\{([a-z0-9\-_]+)\.#\}/', '\'.(1+(isset($_\1_i)?$_\1_i:0)).\'', $code);

		// change template varrefs into PHP varrefs

		// This one will handle varrefs WITH namespaces
		$varrefs = array();
		preg_match_all('#\{(([a-z0-9\-_]+?\.)+?)([a-z0-9\-_]+?)(\|([a-z0-9\-_]+?))?\}#is', $code, $varrefs);
		$varcount = sizeof($varrefs[1]);
		for ($i = 0; $i < $varcount; $i++)
		{
			$namespace = $varrefs[1][$i];
			$varname = $varrefs[3][$i];
			if (isset ($varrefs[5][$i]))
				$varoption = $varrefs[5][$i];
			else
				$varoption = false;
			$new = $this->generate_block_varref($namespace, $varname, $varoption);
			$code = str_replace($varrefs[0][$i], $new, $code);
		}

		// This will handle the remaining root-level varrefs
		$code = preg_replace('#\{([a-z0-9\-_]*?)\}#is', '\' . ( ( isset($this->_tpldata[\'.\'][0][\'\1\']) ) ? $this->_tpldata[\'.\'][0][\'\1\'] : \'\' ) . \'', $code);

		// replace \n with \n\x1
		$code = str_replace ("\n", "\n\x1", $code);
		//$code = preg_replace ('#(?:\x1\s*)+\x1#', "\x1", $code);

		// Break code up into lines
		$code_lines = explode("\x1", $code);
//		print_r ($code_lines);

		$block_nesting_level = 0;
		$block_names = array();
		$block_names[0] = ".";
		$addmodes[0][0] = $default_addmode;
		$addmodes[0][1] = ';';
		$addmodes[0][2] = 0;

		$line_count = sizeof($code_lines);
		for ($i = 0; $i < $line_count; $i++)
		{
			if (strlen ($code_lines[$i]) == 0)
				continue;
			// Additional part will handle AT and MOD
			if (preg_match('#^<!-- BEGIN ([A-Za-z0-9\-_]+?) ([A-Za-z \t\-_0-9]*)-->$#', $code_lines[$i], $m)) // ((APPEND|PREPEND) (([A-Za-z0-9\-_]+?\.)*)([A-Za-z0-9\-_]+?) )?
			{
				$n[0] = $m[0];
				$n[1] = $m[1];
				
				// We have the start of a block.
				$block_nesting_level++;
				$block_names[$block_nesting_level] = $m[1];
				$addmodes[$block_nesting_level][0] = $default_addmode;
				$addmodes[$block_nesting_level][1] = ';';
				$addmodes[$block_nesting_level][2] = 0;
				$cbstart = 0;
				$cbcount = false;
				$cbplus = '++';
				
				if (preg_match ('#^[ \t]*AT ([0-9]+)[ \t]*(?:([0-9]+)[ \t]*)?$#', $m[2], $nem))
				{
					$cbstart = isset ($nem[1]) ? (0+$nem[1]) : 0;
					$cbcount = (isset ($nem[2]) ? (0+$nem[2]) + $cbstart : false);
				}
				if (preg_match ('#^[ \t]*MOD ([1-9][0-9]*) ([0-9]+)[ \t]*$#', $m[2], $nem))
				{
					$cbstart = $nem[2];
					$cbplus = '+='.$nem[1];
				}
				
				/*if (isset ($m[3]))
				{
					$addmodes[$block_nesting_level][2] = 1;
					if ($m[3] == 'APPEND')
					{
						$addto = substr ($m[4], 0, strlen($m[4]) - 1);
						$addto = $this->generate_block_data_ref($addto, true) . '[\'' . $m[6] . '\']';
						$addmodes[$block_nesting_level][0] = 'if (isset (' . $addto . ')) ' . $addto . ' .= ';
						$addmodes[$block_nesting_level][1] = ';';
					}
					else if ($m[3] == 'PREPEND')
					{
						$addto = substr ($m[4], 0, strlen($m[4]) - 1);
						$addto = $this->generate_block_data_ref($addto, true) . ' [\'' . $m[6] . '\']';
						$addmodes[$block_nesting_level][0] = 'if (isset (' . $addto . ')) ' . $addto . ' = ';
						$addmodes[$block_nesting_level][1] = ' . ' . $addto . ';';
					}
				}*/
				
				if ($block_nesting_level < 2)
				{
					// Block is not nested.
					if (!$cbcount)
						$code_lines[$i] = '$_' . $m[1] . '_count = ( isset($this->_tpldata[\'' . $m[1] . '.\']) ) ? sizeof($this->_tpldata[\'' . $m[1] . '.\']) : ' . $addmodes[$block_nesting_level][2] . ';';
					else $code_lines[$i] = '$_' . $m[1] . '_count = min (@sizeof($this->_tpldata[\'' . $m[1] . '.\']), ' . $cbcount . ');';
					$code_lines[$i] .= "\n" . 'for ($_' . $m[1] . '_i = ' . $cbstart . '; $_' . $m[1] . '_i < $_' . $m[1] . '_count; $_' . $m[1] . '_i' . $cbplus . ')';
					$code_lines[$i] .= "\n" . '{';
				}
				else
				{
					// This block is nested.

					// Generate a namespace string for this block.
					$namespace = implode('.', $block_names);
					// strip leading period from root level..
					$namespace = substr($namespace, 2);
					// Get a reference to the data array for this block that depends on the
					// current indices of all parent blocks.
					$varref = $this->generate_block_data_ref($namespace, false);
					// $this->_tpldata['categories.'][$_categories_i]['modules.']
					// Create the for loop code to iterate over this block.
					if (!$cbcount)
						$code_lines[$i] = '$_' . $m[1] . '_count = ( isset(' . $varref . ') ) ? sizeof(' . $varref . ') : ' . $addmodes[$block_nesting_level][2] . ';';
					else $code_lines[$i] = '$_' . $m[1] . '_count = ' . $cbcount . ';';
					$code_lines[$i] .= "\n" . 'for ($_' . $m[1] . '_i = ' . $cbstart . '; $_' . $m[1] . '_i < $_' . $m[1] . '_count; $_' . $m[1] . '_i' . $cbplus . ')';
					$code_lines[$i] .= "\n" . '{';
				}
			}
			else if (preg_match('#<!-- END (.*?) -->#', $code_lines[$i], $m))
			{
				// We have the end of a block.
				unset($block_names[$block_nesting_level]);
				$block_nesting_level--;
				$code_lines[$i] = '} // END ' . $m[1];
			}
			else if ($code_lines[$i] != '')
			{
				// We have an ordinary line of code [changed: VMX]
				$code_lines[$i] = $addmodes[$block_nesting_level][0] . '\'' . $code_lines[$i] . '\'' . $addmodes[$block_nesting_level][1];
			}
		}
		// Bring it back into a single string of lines of code.
		$code = implode("\n", $code_lines);
		// Cache compiled code if needed
		if (isset ($sfile) && $fd = @fopen ($sfile, 'w'))
		{
			fwrite ($fd, $code);
			fclose ($fd);
		}
		return $code;
	}

	/**
	 * Generates a reference to the given variable inside the given (possibly nested)
	 * block namespace. This is a string of the form:
	 * ' . $this->_tpldata['parent'][$_parent_i]['$child1'][$_child1_i]['$child2'][$_child2_i]...['varname'] . '
	 * It's ready to be inserted into an "echo" line in one of the templates.
	 * NOTE: expects a trailing "." on the namespace.
	 */
	function generate_block_varref($namespace, $varname, $varoption = false)
	{
		// Strip the trailing period.
		$namespace = substr($namespace, 0, strlen($namespace) - 1);
		// Get a reference to the data block for this namespace.
		$varref = $this->generate_block_data_ref($namespace, true);
		// Prepend the necessary code to stick this in an echo line.
		if ($varoption === false)
			$varoption = "''";
		else
			$varoption = '((isset(' . $varref . '[\'' . $varoption . '\']' . ')) ? ' . $varref . '[\'' . $varoption . '\'] : \'\')';
		// Append the variable reference.
		$varref .= '[\'' . $varname . '\']';
		$varref = '\' . ( ( isset(' . $varref . ') ) ? ' . $varref . ' : ' . $varoption . ' ) . \'';
		return $varref;
	}

	/**
	 * Generates a reference to the array of data values for the given
	 * (possibly nested) block namespace. This is a string of the form:
	 * $this->_tpldata['parent'][$_parent_i]['$child1'][$_child1_i]['$child2'][$_child2_i]...['$childN']
	 *
	 * If $include_last_iterator is true, then [$_childN_i] will be appended to the form shown above.
	 * NOTE: does not expect a trailing "." on the blockname.
	 */
	function generate_block_data_ref($blockname, $include_last_iterator)
	{
		// Added - VMX: function now can handle root-level
		if ($blockname == '')
			return '$this->_tpldata[\'.\']' . ($include_last_iterator ? '[0]' : '');
		// Get an array of the blocks involved.
		$blocks = explode(".", $blockname);
		$blockcount = sizeof($blocks) - 1;
		$varref = '$this->_tpldata';
		// Build up the string with everything but the last child.
		for ($i = 0; $i < $blockcount; $i++)
		{
			$varref .= '[\'' . $blocks[$i] . '.\'][$_' . $blocks[$i] . '_i]';
		}
		// Add the block reference for the last child.
		$varref .= '[\'' . $blocks[$blockcount] . '.\']';
		// Add the iterator for the last child if requried.
		if ($include_last_iterator)
		{
			$varref .= '[$_' . $blocks[$blockcount] . '_i]';
		}
		return $varref;
	}

}

?>