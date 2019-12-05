#!/bin/bash

# This script servers the purpose of generating data files containing
# key value pairs which will subsequently be used to populate the key-value
# store of each server. The key-value pairs generated follow a specific
# format in order to make crystal clear which key and which value is
# assigned to which server. This will significantly help the evaluation
# of our netcache implementation.

data_dir=data

n_values=100
n_servers=1

usage="${0} [-n <n_values>] [-s <n_servers>]"
while getopts 'n:s:' opt
do

	case $opt in
		n ) n_values=$OPTARG ;;
		s ) n_servers=$OPTARG ;;
	   \? ) echo "Error: Invalid Option: ${usage}"
		   exit 1;
	esac

done


mkdir -p $data_dir

for i in $(seq $n_servers); do

	file_name="${data_dir}/server${i}.txt"

	if [ -e $file_name ]; then
		echo "Error: File $file_name already exists."
	else
		for j in $(seq $n_values); do
			echo "s${i}_key${j} = s${i}_val${j}" >> $file_name
		done
	fi

done
