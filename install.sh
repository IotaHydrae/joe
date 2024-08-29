#!/bin/bash
# We assum you're using bash

OMZ_INSTALL_DIR=~/.oh-my-zsh
PL10K_INSTALL_DIR=~/.powerlevel10k

if [ ! -x "/usr/bin/zsh" ]; then
	echo "Installing zsh..."
	yes | sudo apt install zsh || echo "Failed to install zsh."
else
	echo "Zsh has been installed."
fi

if [ -d $OMZ_INSTALL_DIR ]; then
	echo "oh my zsh has been installed."
else
	echo "Installing Oh My Zsh..."
	sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
	sudo chsh $USER -s /usr/bin/zsh
fi


if [ ! -d $PL10K_INSTALL_DIR ]; then
	echo "Installing powerlevel10k theme..."
	git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $PL10K_INSTALL_DIR
	echo "source $PL10K_INSTALL_DIR/powerlevel10k.zsh-theme" >>~/.zshrc
	source ~/.zshrc
else
	echo "powerlevel10k has been installed."
fi

if [ ! -d ~/.fzf ]; then
	echo "Installing fzf..."
	git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
	yes | ~/.fzf/install
else
	echo "fzf has beed installed"
fi

git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh-autosuggestions
echo "source ~/.zsh-autosuggestions/zsh-autosuggestions.zsh" >> ~/.zshrc

git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.zsh-syntax-highlighting
echo "source ~/.zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> ~/.zshrc


exit $?

