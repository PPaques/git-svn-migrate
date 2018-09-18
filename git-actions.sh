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

run()
{
  echo "$ $@"
  "$@"
  return $?
}


# Process each URL in the repository list.
pwd=`pwd`;
destination=`cd $destination; pwd`; #Absolute path.

cd $pwd


# perform action o repositories
sed -e 's/#.*//; /^[[:space:]]*$/d' $url_file | while read line
do
	# Check for 2-field format:  Name [tab] URL
	name=`echo $line | awk '{print $1}'`;
	actions=`echo $line | awk '{ORS=" "; for (y=2; y<=NF; y++) print $y}'`;
	
	
	# Process each Subversion URL.
	echo >&2;
	echo "At $(date)..." >&2;
	echo " \"$name\": Excecuting $actons." >&2;

	destination_repo=$destination/$name
			
	if [[ ! -d $destination_repo ]]; then
		echo "destination does not exist, cloning it"
		mkdir -p $destination_repo;
		git clone "$from/$name.git" $destination_repo ;
	fi
		
	cd $destination_repo
	run eval "$actions" || echo -e "\n\n\n ERROR while executing custom action \n\n\n"
	cd $pwd
	
	echo "- Action of $name completed at $(date)." >&2;

done

echo "Full action list completed at $(date)." >&2;