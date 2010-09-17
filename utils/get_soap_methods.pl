#!/bin/bash

grep -r METHOD_ . | grep -v "~" | grep -v Base | grep -v svn | sed 's/\.\///' | sed 's/\.pm:sub METHOD_/->/' | sed 's/ {//' | sed 's/(.)/\le$1/' | perl -p  -e 's/(.)/\L$1/'
