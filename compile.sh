#!/bin/sh

if [ "$LIME_DIR" = "" ]; then
    LIME_DIR=~/gits/lime/
fi

php -d xdebug.max_nesting_level=200 $LIME_DIR/lime.php template.lime | tail -n +2 > template.class
LINES=`grep -n -h " \*\*\* DON'T EDIT THIS FILE! \*\*\*" template.parser.php | perl -pe 's/(\d+):.*/$1-2/e'`
if [ "$LINES" != "" ]; then
    head -n $LINES template.parser.php | cat - template.class > template.parser.php.new
else
    cat template.parser.php template.class > template.parser.php.new
fi
mv template.parser.php.new template.parser.php
