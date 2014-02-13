#!/bin/bash

# This script expects that the user running it is able to pull and push to the
# two repositories used here. For the logs_processor user on transition-logs-1,
# this will be done using separate deploy keys added to those repos and ssh
# config to use the right key for each repo, by hostname aliases.

set -e

# Set up rbenv for the logs_processor user, which is necessary because it
# doesn't have a proper login shell
if [ -f /etc/profile.d/rbenv.sh ]; then
    source /etc/profile.d/rbenv.sh
else
    echo "Can't setup rbenv, so processing will fail"
    exit 1
fi

# clone repos
for REPO in transition-stats pre-transition-stats
do
    if [ -d "./$REPO" ]; then
        cd "$REPO"
        if [ -n "$(git status --porcelain)" ]; then
            echo "git status in $REPO was unclean"
            exit 1
        fi
        git checkout master
        git pull origin master
        cd ..
    else
        git clone "git@github.com-$REPO:alphagov/$REPO.git"
    fi
done

# checkout the right branch for transition-stats
cd transition-stats
BRANCH_NAME='redirector_fastly_hits'
if git rev-parse --verify "$BRANCH_NAME"; then
    git checkout "$BRANCH_NAME"
else
    git checkout -b "$BRANCH_NAME"
fi
cd ..

# process logs
LOGS_DIR='/srv/logs/log-1/cdn'

(cd pre-transition-stats &&
    bundle install &&
    bundle exec bin/hits update "$LOGS_DIR" --output-dir '../transition-stats/hits')

# move into transition-stats, which should already be on the right branch, to
# commit and push
cd transition-stats

# we will probably have untracked files as well as changes in tracked files if
# anything has been processed, so git add first before checking cached diff
git add hits/

# check the exit code from `git diff --cached`: 0 if no changes, 1 if there is a diff
# --quiet implies --exit-code as well as suppressing output
if ! git diff --cached --quiet; then
    TIMESTAMP=$(date +"%F %T")
    git commit -m 'Redirector Fastly hits processed on '"$TIMESTAMP"
fi

git push origin "$BRANCH_NAME"

git checkout master
