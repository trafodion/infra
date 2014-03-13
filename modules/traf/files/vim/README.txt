#
# The files and diretories located here should be copied to $HOME/.vim
# so VIM can pick up the syntax for puppet files and ruby
#
# vim-addon-manager needs to be installed first
#

apt-get install vim-addon-manager
mkdir $HOME/.vim
cp -r * $HOME/.vim

# run the next command only if you do not already have a $HOME/.vimrc file
mv $HOME/_vimrc $HOME/.vimrc
