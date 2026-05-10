#!/usr/bin/env bash

TASK=$1

git worktree add ../$TASK -b $TASK

cd ../$TASK

code .
