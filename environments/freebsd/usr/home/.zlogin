# zsh login stuff

# Only need the environment file in a login shell,
# since the information will be propagated via exec.

ENV_FILE=${HOME}/.environment

if [ -f $ENV_FILE ] ; then
    . $ENV_FILE
fi

# Only do host specific stuff at login
# since it is assumed that this will also propagate
# and/or set env variables that other things can use.

THIS_BOX=`hostname | sed 's/\..*$//'`

if [ -f $HOME/.$THIS_BOX ] ; then
    . $HOME/.$THIS_BOX
fi

