#!/bin/bash

# Checks that there are no uncommitted files in the repo.
if [[ -z $(git status -s) ]]
then
    exit 0
else
    echo "There are uncommitted file changes!"
    echo "The committed build artifacts likely do not match the source code."
    exit 1
fi
