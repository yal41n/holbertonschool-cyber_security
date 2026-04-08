#!/bin/bash
cat logs.txt | cut -d' ' -f1 | cut -d' ' -f5 | sort | uniq -c | tail -1 | grep '[.]' 
