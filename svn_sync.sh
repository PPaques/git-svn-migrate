#!/bin/bash

# Copyright 2010-2011 John Albin Wilkins and contributors.
# Available under the GPL v2 license. See LICENSE.txt.

script=`basename $0`;
dir=`pwd`/`dirname $0`;
usage=$(cat <<EOF_USAGE
USAGE: $script --url-file=<filename> --destination=<folder>
\n
\nFor more info, see: $script --help
EOF_USAGE
);

help=$(cat <<EOF_HELP
NAME
\n\t$script - Sync svn repositoeirs locally
\n
\nSYNOPSIS
\n\t$script [options] [arguments]
\n
\nDESCRIPTION
\n The script performs a local copy of the remote svn.
\n If the target repository exists, it perform a partial sync.
\n Ensure to not make an url change for the same repository
\n otherwise, the config change will be ignored.
\n Please mind that partial sync is not always wokring. (at
\n least in my case)
\n
\n\tThe following options are available:
\n
\n\t-u=<filename>, -u <filename>,
\n\t--url-file=<filename>, --url-file <filename>
\n\t\tSpecify the file containing the Subversion repository list.
\n
\n\t-d=<folder>, -d <folder>,
\n\t--destination=<folder>, --destination <folder>
\n\t\tThe directory where the new Git repositories should be
\n\t\tsaved. Defaults to the current directory.
\n 
\n
\nBASIC EXAMPLES
\n\t# Use the long parameter names
\n\t$script --url-file=my-repository-list.txt --destination=~/code/my_sync_svn
\n
EOF_HELP
);


# Set defaults for any optional parameters or arguments.
destination='';

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


if [[ $destination == '' ]]; then
	echo "Specify destination." >&2;
	echo -e $usage >&2;
	exit 1;
fi

sync_svn()
{
	# add code to restart
	echo '#!/bin/sh' > "$1/hooks/pre-revprop-change"
	chmod 755 "$1/hooks/pre-revprop-change"
	svnsync sync "file://$1"
}


# Process each URL in the repository list.
pwd=`pwd`;
destination=`cd $destination; pwd`; #Absolute path.

sed -e 's/#.*//; /^[[:space:]]*$/d' $url_file | while read line
do
	# Check for 2-field format:  Name [tab] URL
	url=`echo $line | awk '{print $1}'`;
	name=`echo $line | awk '{print $2}'`;
	repo_old_base_dir=$destination/$name
		
	# Process each Subversion URL.
	echo >&2;
	echo "At $(date)..." >&2;
	echo " \"$name\" syncing..." >&2;

	if [ -d "$repo_old_base_dir" ]; then
		sync_svn $repo_old_base_dir
	else
		mkdir -p $repo_old_base_dir
		svnadmin create $repo_old_base_dir
		echo '#!/bin/sh' > "$repo_old_base_dir/hooks/pre-revprop-change"
		chmod 755 "$repo_old_base_dir/hooks/pre-revprop-change"
		svnsync init "file://$repo_old_base_dir" "$url"
		sync_svn $repo_old_base_dir
	fi

	echo "Sync of $name completed at $(date)." >&2;

done

echo "Full sync completed at $(date)." >&2;