# ssh agent management with one key per agent
#
# lookup key in ~/.ssh/config
# get list of potential agent sockets
# is key in list of sockets? use it, return
# create new agent, add id
TMPDIR=${TMPDIR:-/tmp}
SSH_DEBUG=${SSH_DEBUG:-0}
ssh_debug() { [[ ${SSH_DEBUG} == "0" ]] || echo "$@"; }

ssh_config_get_key_by_host() {
	local host="$1" host_re="unmatchable" id=""
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
ssh_find_sock() {
	local key="$1"
	ssh_agent_list | while read sock; do
		SSH_AUTH_SOCK=$sock ssh-add -l 2>&1 | grep -qs "$key" && { echo $sock; break; }
	done
}
ssh_agent_check() {
	local file=$(ssh_config_get_key_by_host $1 | sed -e "s#~#${HOME}#" )
	local key="."
	ssh_debug "agent check got file $file"
	[[ -f "$file"  ]] && key=$( ssh-keygen -l -f $file | awk '{print $2}' )
	ssh_debug "looking for id $key"
	local sock=$( ssh_find_sock $key  )
	ssh_debug "for this $key got auth sock $sock"
	if [[ -e $sock ]]; then
		export SSH_AUTH_SOCK=$sock
		return 0
	fi
	ssh_debug "no agent found, creating new "
	eval `ssh-agent` &>/dev/null
	ssh-add $file &>/dev/null
}
ssh_agent_clean() {
	local a,p,s,pids
	for a in /tmp/ssh*/agent*; do
		SSH_AUTH_SOCK=$a ssh-add -l && continue
		for pid in $( lsof -t $a ); do
			echo "SSH_AUTH_pid=${pid} ssh-agent -k"
			SSH_AUTH_pid=$pid ssh-agent -k
		done
		[[ -e $a ]] && mv -v $( dirname $a ) /tmp/foo-$( dirname $a )
	done
	pids=$( ps h -C ssh-agent -o pid )
	for p in $pids; do
		s=$( expr $p - 1)
		for a in /tmp/ssh*/agent.${s}; do
			test -e "$a" && continue
			echo "bad sock $a, killing $p"
			kill -TERM $p
		done
	done
}

scp_host() { local i; for i in "$@"; do [[ $i = *:/* ]] && echo "$i" | sed -e 's/:.*//'; done; }
ssh_host() { local i; for i in "$@"; do [[ $i = *.* ]]  && echo "$i"; done; }
ssh() {
    ssh_agent_check $(ssh_host "$@")
    if [[ "$TERM" == "dvtm" ]]; then
        TERM=rxvt command ssh "$@"
    else
        command ssh "$@"
    fi
    local ret=$?
    ssh_agent_check "DEFAULT"
    return $ret
}
scp() { ssh_agent_check $(scp_host "$@"); command scp "$@"; local ret=$?; ssh_agent_check "DEFAULT"; return $ret; }
sshfs() { ssh_agent_check $(scp_host "$@"); command sshfs "$@";  ssh_agent_check "DEFAULT"; }

ssh-add -l &>/dev/null || ssh_agent_check "DEFAULT"

export RSYNC_RSH="${HOME}/.git-ssh.sh"
export GIT_SSH="${HOME}/.git-ssh.sh"
[[ ! -x $GIT_SSH ]] && {
cat<<EOF >  $GIT_SSH
#!/bin/bash
source \${HOME}/.bashrc
ssh \$*
EOF
chmod +x $GIT_SSH
}
