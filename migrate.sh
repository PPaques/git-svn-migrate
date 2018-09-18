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
  # run ./svn-sync.sh --url-file $file_sync --destination $folder_sync_destination
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
#run ./git-svn-migrate.sh --url-file $file_repositories --destination $folder_base_convertion --authors-file $file_authors

file_actions_before_merge="$pwd/repositories-actions-before-merge.txt"
if [ ! -f $file_actions_before_merge ]; then
  echo "No before-merge-actions, create a dummy file from repositories-list.txt"

  sed -e 's/#.*//; /^[[:space:]]*$/d' $file_repositories | while read line
  do
    # Check for 2-field format:  Name [tab] URL
    url=`echo $line | awk '{print $1}'`;
    name=`echo $line | awk '{print $2}'`;
    printf "$name\tgit status\n" >> $file_actions_before_merge
    # Check for simple 1-field format:  URL
  done
fi

echo "run pre-merge cleaning operation"
folder_pre_merge="$pwd/pre-merge-git"
run ./git-actions.sh --url-file $file_actions_before_merge --from $folder_base_convertion --destination $folder_pre_merge


file_repositories_merge="$pwd/repositories-list-merge.txt"
if [ ! -f $file_repositories_merge ]; then
  echo "No merging rules. Conversion is finished"
  exit 0
fi

echo "Merging repositories into a central repository according to the config"
folder_merge="$pwd/merge-git"
run ./git-merge.sh --url-file $file_repositories_merge --from $folder_pre_merge --destination $folder_merge


file_actions_after_merge="$pwd/repositories-actions-after-merge.txt"
if [ ! -f $file_actions_after_merge ]; then
  echo "No after-merge-actions, create a dummy file from repositories-list.txt"

  sed -e 's/#.*//; /^[[:space:]]*$/d' $file_repositories | while read line
  do
    # Check for 2-field format:  Name [tab] URL
    name=`echo $line | awk '{print $1}'`;
    target=`echo $line | awk '{print $2}'`;

    if [[ target == "/" ]]; then
      #statements
      printf "$name\tgit gc\n" >> $file_actions_after_merge

    fi
    # Check for simple 1-field format:  URL
  done
fi

echo "run after-merge cleaning operation"
folder_after_merge="$pwd/final-git"
run ./git-actions.sh --url-file $file_actions_after_merge --from $folder_merge --destination $folder_after_merge
