<?php

require 'template.php';

system('mkdir -p ./cache');
system('rm ./cache/tpl*.php');

$template = new VMXTemplate([
    'cache_dir' => './cache',
    'root' => '.',
    'auto_escape' => 's',
]);

$template->parse('test.tpl');
