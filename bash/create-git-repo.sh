#!/bin/bash

# DO NOT CHANGE: strips everything up to, and including,
# the last '\', if exists, for the running user
defusername=$(whoami)
defusername=${defusername##*\\}
defdomainname=$(hostname)
[[ $(command -v dnsdomainname) ]] && defdomainname="${defdomainname}.$(dnsdomainname)"

# ---------------------------------------------------------------
# CONFIGURATION SECTION
#
# either change defaults (listed after ":-")
# or provide them to the cli, e.g.:
#	GITSRCDIR=~/src GITUSERNAME=user create-git-repo {repo_name}
#
# NOTE: please leave trailing / off of paths
#
# ---------------------------------------------------------------

# the following two are used for git commit user delineation
# Example commented out
#GITUSERNAME="My Name"
#GITUSEREMAIL="my.email@devnull"
GITUSERNAME=${GITUSERNAME:-"${defusername}"}
GITUSEREMAIL=${GITUSEREMAIL:-"${GITUSERNAME}@${defdomainname}"}

# where, locally, the repo will be created
GITSRCDIR=${GITSRCDIR:-~/_src}

# the local path to the gitolite-admin repo
GITADMINDIR=${GITADMINDIR:-${GITSRCDIR}/gitolite-admin}

# the uri to the remote gitolite server
GITCONNECT=${GITCONNECT:-"git@github.com:${GITUSERNAME}"}

# comma-delimited list of users to give RW+ to for the repo
GITREPOUSERS=${GITREPOUSERS:-"${GITUSERNAME}"}

# ---------------------------------------------------------------
# DO NOT EDIT BELOW THIS LINE, UNLESS YOU KNOW WHAT YOU ARE DOING
# ---------------------------------------------------------------

# function defintions
function cleanup () {
	if [[ $ISWIN && $autocrlf && ${autocrlf-_} ]]; then
		echo -e "\033[1;33mAttempting to reset git var core.autocrlf to original value with \"git config core.autocrlf ${autocrlf}\"\033[0m"
		if [ -d $GITADMINDIR ]; then
			cd $GITADMINDIR
			git config core.autocrlf ${autocrlf}
		fi
	fi	
}

function error_message () {
	local msg=${1:-"An error has occurred"}
	echo -e "\033[1;31m${msg}\033[0m"
	exit 1
}

function exit_message () {
	echo -e "Exiting program..."
	exit 1
}

function usage () {
	echo -e "\033[1;32mUsage: \033[0m"
	echo -e "\t\033[37m$(basename ${0}) [repo_name]\033[0m"
	exit 1
}

function set_git_user_info () {
	gitusername=$(git config --global user.name)
	gituseremail=$(git config --global user.email)
	
	[ "${gitusername}" == "" ] && git config --global user.name "${GITUSERNAME}"
	[ "${gituseremail}" == "" ] && git config --global user.email $GITUSEREMAIL
}
# end function defintions


# this script cannot be run if git nor grep can be found
[ "$(command -v git)" == "" ] && error_message "Cannot locate git! Please install git and run again!"

[ "$(command -v grep)" == "" ] && error_message "Cannot locate grep! Please install grep and run again!"

# make sure a repo name is provided
[ $# -ne 1 ] && usage

# determine if this is being run from cygwin or git bash
[[ $TERM == "cygwin" ]] && ISWIN=true || ISWIN=false

# update git user info for the committer
set_git_user_info

# store the reponame
reponame=$1

# parse the repo users list into an array
IFS="," read -ra REPOUSERS <<< "${GITREPOUSERS}"

GITOLITECONF=${GITADMINDIR}/conf/gitolite.conf

# create the directories if they do not exist
if [ ! -d $GITSRCDIR ]; then
	echo -e "\033[1;31m${GITSRCDIR} does not exist!\033[0m"
	echo -ne "\033[33mWould you like to create it [Y/n]? \033[0m"
	read in_csrc

	[[ $in_csrc != "y" && $in_csrc != "Y" && "${in_csrc}" != "" ]] && exit_message

	mkdir -p $GITSRCDIR
fi

# create the gitolite-admin dir and get the latest from source, if it doesn't exist
if [[ ! -d $GITADMINDIR || ! -f $GITOLITECONF ]]; then
	echo -e "\033[1;31mEither ${GITADMINDIR} or ${GITOLITECONF} does not exist!\033[0m"
	echo -ne "\033[33mWould you like to create it [Y/n]? \033[0m"
	read in_cadm

	[[ $in_cadm != "y" && $in_cadm != "Y" && "${in_cadm}" != "" ]] && exit_message

	curdir=$(pwd)
	mkdir -p $GITADMINDIR
	cd $GITSRCDIR

	# get the admin repository
	echo -e "\033[32mCloning ${GITCONNECT}:gitolite-admin to ${GITADMINDIR}\033[0m"
	git clone ${GITCONNECT}:gitolite-admin $GITADMINDIR
fi

if ! grep -q "repo[[:space:]]*${reponame}$" $GITOLITECONF; then
	[ ! -w $GITOLITECONF ] && error_message "${GITOLITECONF} is not writable, exiting the program..."

	# get the latest from the remote origin
	echo -e "\033[32mUpdating ${GITADMINDIR} repo...\033[0m"
	cd $GITADMINDIR
	git pull

	# store the autocrlf setting to reset to at the end of the script
	autocrlf=$(git config core.autocrlf)

	# run the cleanup function whenever the script exits
	trap cleanup EXIT

	# set the autocrlf conversion to off for editing GITOLITECONF
	[[ $ISWIN && $autocrlf ]] && git config core.autocrlf false

	# add repo to gitolite conf
	repotxt="\nrepo    ${reponame}"

	for user in "${REPOUSERS[@]}"
	do
		repotxt="${repotxt}\n        RW+     =   ${user}"
	done

	echo -e "\033[1;33mThe following information will be appended to ${GITOLITECONF}:\033[0m"
	echo -e "${repotxt}"
	echo -e ""
	echo -ne "\033[1;33mDo you want to proceed [Y/n]? \033[0m"
	read in_append

	[[ $in_append != "y" && $in_append != "Y" && "${in_append}" != "" ]] && exit_message

	echo -e "${repotxt}" >> $GITOLITECONF

	echo -e "\033[37m]Updated ${GITOLITECONF}, now persisting changes to git server...\0333[0m"

	cd $GITADMINDIR
	git stage .
	git commit -a -m "Updated repo list to include: ${reponame}"
	git push
fi

repodir=${GITSRCDIR}/${reponame}

[ -d ${repodir}/.git ] && error_message "The repo ${repodir} already exists locally, exiting the program..."

echo -e "\033[1;33mThe following repo ${reponame} will be added to {$GITSRCDIR} and the master branch will be created\033[0m"
echo -ne "\033[1;33mDo you want to continue [Y/n]? \033[0m"
read in_continue

[[ $in_continue != "y" && $in_continue != "Y" && "${in_continue}" != "" ]] && exit_message

# create the folder and git init|commit it
echo -e "\033[32mCreated ${repodir}...\033[0m"

mkdir -p $repodir
cd $repodir
git init
git remote add origin ${GITCONNECT}:${reponame}.git
git commit -a -m "Initial repository commit" --allow-empty
git push origin master:refs/heads/master

echo -e ""
echo -e "\033[32m${GITCONNECT}:${reponame}.git created...\033[0m"

exit 0
