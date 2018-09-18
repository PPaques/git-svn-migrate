#!/bin/bash

# Copyright 2010-2011 John Albin Wilkins and contributors.
# Available under the GPL v2 license. See LICENSE.txt.

script=`basename $0`;
dir=`pwd`/`dirname $0`;
usage=$(cat <<EOF_USAGE
USAGE: $script --url-file=<filename> --from=<folder> --destination=<folder>
\n
\nFor more info, see: $script --help
EOF_USAGE
);

help=$(cat <<EOF_HELP
NAME
\n\t$script - Merge repositories to mono-repo Git
\n
\nSYNOPSIS
\n\t$script [options] [arguments]
\n
\nDESCRIPTION
\n The script perform a deep copy of all repositories that ares inside the a list and
\n then merge all repositories toghether in a way that each repository keep his own 
\n history without the need to make a git log --follow. 
\n This ensure a compatibility with tools like gitlab or github.
\n
\n\tThe following options are available:
\n
\n\t-u=<filename>, -u <filename>,
\n\t--url-file=<filename>, --url-file <filename>
\n\t\tSpecify the file containing the Subversion repository list.
\n
\n\t-a=<filename>, -a <filename>,
\n\t--authors-file=[filename], --authors-file [filename]
\n\t\tSpecify the file containing the authors transformation data.
\n
\n\t-d=<folder>, -d <folder>,
\n\t--destination=<folder>, --destination <folder>
\n\t\tThe directory where the new Git repositories should be
\n\t\tsaved. Defaults to the current directory.
\n 
\n\t-f=<folder>, -f <folder>,
\n\t--from=<folder>, --from <folder>
\n\t\tThe directory where the all sources repositories are located.
\n\t\tAll repositories should be in the from/repository_name.git in
\n\t\tin bare format. We assume that you used git-svn-migrate.sh)
\n
\nBASIC EXAMPLES
\n\t# Use the long parameter names
\n\t$script --url-file=my-repository-list.txt --destination=~/code/my_merged_git
\n
EOF_HELP
);


# Set defaults for any optional parameters or arguments.
destination='';
from='';
gitinit_params='';
gitsvn_params='';

# Process parameters.
until [[ -z "$1" ]]; do
	option=$1;
	# Strip off leading '--' or '-'.
	if [[ ${option:0:1} == '-' ]]; then
		flag_delimiter='-';
		if [[ ${option:0:2} == '--' ]]; then
			tmp=${option:2};
			flag_delimiter='--';
		else
			tmp=${option:1};
		fi
	fi
	parameter=${tmp%%=*}; # Extract option's name.
	value=${tmp##*=};     # Extract option's value.
	# If a value is expected, but not specified inside the parameter, grab the next param.
	if [[ $value == $tmp ]]; then
		if [[ ${2:0:1} == '-' ]]; then
			# The next parameter is a new option, so unset the value.
			value='';
		else
			value=$2;
			shift;
		fi
	fi

	case $parameter in
		u )               url_file=$value;;
		url-file )        url_file=$value;;
		d )               destination=$value;;
		destination )     destination=$value;;
		from)             from=$value;;
		f)                from=$value;;
		i )               ignore_file=$value;;
		ignore-file )     ignore_file=$value;;

		h )               echo -e $help | less >&2; exit;;
		help )            echo -e $help | less >&2; exit;;
	esac

	# Remove the processed parameter.
	shift;
done

# Check for required parameters.
if [[ $url_file == '' ]]; then
	echo -e $usage >&2;
	exit 1;
fi
# Check for valid files.
if [[ ! -f $url_file ]]; then
	echo "Specified URL file \"$url_file\" does not exist or is not a file." >&2;
	echo -e $usage >&2;
	exit 1;
fi

if [[ ! -d $from ]]; then
	echo "Specified from_folder \"$from\" does not exits." >&2;
	echo -e $usage >&2;
	exit 1;
fi


if [[ $destination == '' ]]; then
	echo "Specify destination." >&2;
	echo -e $usage >&2;
	exit 1;
fi


# Process each URL in the repository list.
pwd=`pwd`;
tmp_destination="$pwd/tmp-merge-repo";
destination=`cd $destination; pwd`; #Absolute path.

# now create a new repository and import all changes
echo "Creating destination repository"
if [[ -e $destination ]]; then
	echo "Final repository location \"$destination\" already exists. Cleaning it." >&2;
	rm -rf $destination
fi

mkdir -p $destination;
echo "init the new final repository"
cd $destination
git init
cd $pwd

# Ensure temporary repository location is empty.
if [[ -e $tmp_destination ]]; then
	echo "Temporary repository location \"$tmp_destination\" already exists. Cleaning it." >&2;
	rm -rf $tmp_destination
fi

mkdir $tmp_destination

# first pass : walk through the url file and make 
#     - the deep clone to temporary folder
#     - rewrite history to target folder
echo "First Pass: copy bare repositories inside the temp folder then rewrite history to target folder"
sed -e 's/#.*//; /^[[:space:]]*$/d' $url_file | while read line
do
	# Check for 2-field format:  Name [tab] URL
	url=`echo $line | awk '{print $1}'`;
	name=`echo $line | awk '{print $2}'`;
	target=`echo $line | awk '{print $3}'`;
	extra_args=`echo $line | awk '{ORS=" "; for (y=4; y<=NF; y++) print $y}'`;
	
	# Check for simple 1-field format:  URL
	if [[ $name == '' ]]; then
		name=`basename $url`;
	fi
	
	# Process each Subversion URL.
	echo >&2;
	echo "At $(date)..." >&2;
	echo " \"$name\" repository at $target..." >&2;


	if [[ $target = '-' ]]; then
		echo "$name is marked as skipped (-) Skip it"
		continue;
	fi
	cd $pwd;

	echo "Copying \"$name\" to temp folder"
	repo_temp_copy="$tmp_destination/$name"
	
	# Clone the original Subversion repository to a temp repository.
	git clone "$from/$name.git" $repo_temp_copy ;
	cd $repo_temp_copy

	for branch in `git branch -a | grep remotes | grep -v HEAD | grep -v master`; do
	    git branch --track ${branch##*/} $branch
	done
	git remote rm origin	
	
	# rewrite full history to a repo
	if [[ $target = '/' ]]; then
		echo "$name is marked as root (/) do not rewrite history"
	else 
		echo "$name must be placed at \"$target\" rewrite history"
		cd $tmp_destination/$name 

		git filter-branch --index-filter \
			"git ls-files -s | sed \"s-\t\\\"*-&$target/-\" |
			GIT_INDEX_FILE=\$GIT_INDEX_FILE.new \
			git update-index --index-info &&
			if [ -f \"\$GIT_INDEX_FILE.new\" ]; then mv \"\$GIT_INDEX_FILE.new\" \"\$GIT_INDEX_FILE\"; fi
		" --tag-name-filter cat -f -- --all
	fi

	echo "Merge master branch"
	cd $destination;
	git remote add -f $name $repo_temp_copy
	git fetch -t $name
	git fetch -n $name 
	git merge --allow-unrelated-histories -m "Merge to the combined repository." $name/master
	
	# Merge branch: Not needed in my case, not validated, sorry
	echo "Merge all branches"

	for branch in `cd $repo_temp_copy; git branch | grep -v HEAD | grep -v master | grep -v trunk` ; do 
		echo "Mergin $branch";
		git checkout $branch
		# git branch --set-upstream-to $branch $name/$branch
		# git merge --no-edit $branch
	done
	git checkout master

	git remote rm $name

	cd $pwd


	# echo "Merge all tags"
	# cd $destination;
	# git remote add -f $name $repo_temp_copy
	# git fetch -t $name
	# git checkout -b <tag> tags/<tag>
	# git merge --no-edit tags/<tag>
	# git remote rm $name

	echo "- Conversion of $name completed at $(date)." >&2;

done

echo "Full Conversion completed at $(date)." >&2;