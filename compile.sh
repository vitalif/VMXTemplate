#!/bin/sh

if [ "$LIME_DIR" = "" ]; then
    LIME_DIR=./lime/
fi

php -d xdebug.max_nesting_level=200 $LIME_DIR/lime.php template.lime | tail -n +2 > template.class
LINES=`grep -n -h " \*\*\* DON'T EDIT THIS FILE! \*\*\*" VMXTemplateCompiler.php | perl -pe 's/(\d+):.*/$1-2/e'`
if [ "$LINES" != "" ]; then
    head -n $LINES VMXTemplateCompiler.php | cat - template.class > VMXTemplateCompiler.php.new
else
    cat VMXTemplateCompiler.php template.class > VMXTemplateCompiler.php.new
fi
mv VMXTemplateCompiler.php.new VMXTemplateCompiler.php
