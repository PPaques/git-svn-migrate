#!/bin/bash

# Copyright 2010 John Albin Wilkins.
# Available under the GPL v2 license. See LICENSE.txt.

script=`basename $0`;
usage=$(cat <<EOF_USAGE
USAGE: $script
\n
\nFor more info, see: $script --help
EOF_USAGE
);

help=$(cat <<EOF_HELP
NAME
\n\t$script - Perform the full migration of svn.\
\n
\nSYNOPSIS
\n\t$script
\n
\nDESCRIPTION
\n\tThe $script utility will perform the following actions:
\n\t\t TODO
\nSEE ALSO
\n\tgit-svn-migrate.sh
EOF_HELP
);

run()
{
  echo "$ $@"
  "$@"
  return $?
}

pwd=`pwd`

echo "Starting $script..."
file_sync="$pwd/repositories-to-sync.txt"
folder_sync_destination="$pwd/svn-sync"

if [ -f $file_fetcher ]; then
  echo "svn repositories list to fetch locally detected. Running it"
  run ./svn-sync.sh --url-file $file_sync --destination $folder_sync_destination
fi


file_repositories="$pwd/repositories-list.txt"
if [ ! -f $file_repositories ]; then
  echo "File with repositories does not exits. please create a repositories_list.txt according to the documentation..."
  exit 1
fi


file_authors="$pwd/authors-transform.txt"
echo $file_authors
if [ -f $file_authors ]; then
  echo "Authors File Already completed, continue..."
else
  echo "In order to perform the migration you need a complete list of authors."
  echo "This script will generate it following the repository configuration that you have done"

  run ./fetch-svn-authors.sh --url-file $file_repositories --destination $file_authors

  echo "Please edit authors file in order to clean names and emails addresses."
  echo "The file is located: $file_authors"
  read -n 1 -s -r -p "Press any key to continue"
fi


folder_base_convertion="$pwd/bare-git"
run ./git-svn-migrate.sh --url-file $file_repositories --destination $folder_base_convertion --authors-file $file_authors

