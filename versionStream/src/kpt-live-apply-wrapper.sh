#!/usr/bin/env sh

DIR=$1;shift
TAG=$1;shift
MESSAGE=$1;shift
NEW_CLUSTER=$1;shift
KPT_LIVE_APPLY_FLAGS=$*


if [ $NEW_CLUSTER != true ]
then
    GIT_PREV_TAG=$(git for-each-ref --sort=-taggerdate --count=1  refs/tags/$TAG\* --format '%(refname)' 2> /dev/null)

    if [ -n "$GIT_PREV_TAG" ] && git diff --exit-code $GIT_PREV_TAG $DIR
    then
        echo "No changes in $DIR to apply"
        exit 0
    fi
fi

if kpt live apply $KPT_LIVE_APPLY_FLAGS $DIR
then
    git tag  -m "$MESSAGE" $(date "+${TAG}-%Y%m%d-%H%M%S")
    git push --tags
else
    exit 1
fi
