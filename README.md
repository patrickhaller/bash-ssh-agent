### SSH agent manager for bash

SSH agent forwarding exposes all your keys to your remote host. 

To avoid this, this bash plugin sets up an agent for each of your ssh keys and switches them automatically for you.

#### Installation

Setup ~/.ssh/config with per-destination keys:

	Host *.work.com
		IdentityFile ~/.ssh/work.pub
		ForwardAgent yes
	
	Host *.personal-domain.tld
		IdentityFile ~/.ssh/personal.pub
		ForwardAgent yes
	
	Host github.com
		IdentityFile ~/.ssh/github.pub

Download and source [ssh.sh](https://github.com/patrickhaller/bash-ssh-agent/raw/master/ssh.sh)
