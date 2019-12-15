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


# helper function to convert a character to its
# ascii representation
ord() {
	LC_CTYPE=C printf '%d' "'$1"
}


mkdir -p $data_dir

for i in $(seq $n_servers); do

	# key must start with this char to be assigned to this
	# server based on the range-based partitioning scheme
	# that is used to partition data across storage nodes
	start_char=''

	# since we are using range-based partitioning, we need
	# to populate the servers with appropriate values that
	# start with a proper symbol, to find such a symbol we
	# iterate over the alphabet until out first match
	for letter in {{a..z},{A..Z}}; do

		node_no=$(($(ord ${letter}) % ${n_servers}))

		if (( $node_no == $i-1 )); then
			start_char=$letter
			break
		fi

	done


	file_name="${data_dir}/server${i}.txt"

	for j in $(seq $n_values); do
		echo "${start_char}_${j}=s${i}_val${j}" >> $file_name
	done

done
