# ssh agent management with one key per agent
#
# lookup key in ~/.ssh/config
# get list of potential agent sockets
# is key in list of sockets? use it, return
# create new agent, add id

ssh_config_get_key_by_host() {
	local host="$1" host_re="unmatchable" id
	local default_id=$(find ${HOME}/.ssh/id_{rsa,dsa} 2>/dev/null | sed 1q)
	[[ "$host" = "DEFAULT" ]] && { echo $default_id; return 0; }
	cat ${HOME}/.ssh/config | while read key value; do
		[[ "$key" == "Host" ]] && { host_re="$value"; id="$default_id"; }
		[[ "$key" == "IdentityFile" ]] && id="$value"
		[[ "$key" == "" && $host = $host_re ]] && { echo $id; break; }
	done
}
ssh_agent_list() {
	find ${HOME}/.ssh/agent ${HOME}/.ssh-agent* {$TMPDIR,/tmp}/ssh-*/agent* -user $USER -type s 2>/dev/null
}
ssh_key_in_list() {
	local key="$1"
	export SSH_AUTH_SOCK=$(
		ssh_agent_list | while read sock; do
			SSH_AUTH_SOCK=$sock ssh-add -l 2>&1 | grep -qs "$key" && { echo $sock; break; }
		done
	)
	[[ $SSH_AUTH_SOCK != "" ]] && return 0 || return 1
}
ssh_agent_check() {
	local key=$(ssh_config_get_key_by_host $1 | sed -e "s#~#${HOME}#" )
	ssh_key_in_list $key && { return 0; }
	eval `ssh-agent` &>/dev/null
	ssh-add $key &>/dev/null
}
ssh_agent_clean() {
	local a
	for a in /tmp/ssh*/agent*; do
		SSH_AUTH_SOCK=$a ssh-add -l && continue
		mv -v $( dirname $a ) /tmp/foo-$( basename $a )
	done
}

scp_host() { local i; for i in "$@"; do [[ $i = *:/* ]] && echo "$i" | sed -e 's/:.*//'; done; }
ssh_host() { local i; for i in "$@"; do [[ $i = *.* ]]  && echo "$i"; done; }
ssh() { ssh_agent_check $(ssh_host "$@"); command ssh "$@" ; ssh_agent_check "DEFAULT"; }
scp() { ssh_agent_check $(scp_host "$@"); command scp "$@"; ssh_agent_check "DEFAULT"; }
sshfs() { ssh_agent_check $(scp_host "$@"); command sshfs "$@";  ssh_agent_check "DEFAULT"; }

ssh-add -l &>/dev/null || ssh_agent_check "DEFAULT"

export GIT_SSH="${HOME}/.git-ssh.sh"
[[ ! -x $GIT_SSH ]] && {
cat<<EOF >  $GIT_SSH
#!/bin/bash
source \${HOME}/.bashrc
ssh \$*
EOF
chmod +x $GIT_SSH
}
