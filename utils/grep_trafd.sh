#!/bin/bash

for i in $*; do traflog -a -n -i ./$i 2>/dev/null; done