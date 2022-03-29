# Stuff that *all* zsh instantiations need

FUNCTION_FILE=${HOME}/.functions

if [ -f $FUNCTION_FILE ] ; then
    . $FUNCTION_FILE
fi

ALIAS_FILE=~/.aliases

if [ -f $ALIAS_FILE ] ; then
    . $ALIAS_FILE
fi

