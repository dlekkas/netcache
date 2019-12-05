#!/bin/sh

#
# This scripts servers the purpose of creating well typed p4app.json documents
# with the specified number of servers and number of clients given as options
# This functionality allows fast iterations between multiple experiments with
# different number of running servers/clients
#
# Usage: ./p4app_gen.sh [-s <n_servers>] [-c <n_clients>]
#

n_servers=1
n_clients=1

usage="${0} [-s <n_servers>] [-c <n_clients>]"
while getopts 's:c:' opt
do
	case $opt in
		s) n_servers=$OPTARG;;
		c) n_clients=$OPTARG;;
	   \?) echo "Error: invalid input: ${usage}"
		   exit 1
   esac
done


tmp_file='tmp_x'
if [ -f "$tmp_file" ]; then
	echo "Error: Temporary file ${tmp_file} already exists."
	exit 1
fi

# populate all the server entries in "links" field
for i in $(seq $n_servers); do
	echo "\t\t[\"server${i}\", \"s1\"]," >> ${tmp_file}
done

# populate all the client entires in "links" field
for i in $(seq $(($n_clients-1))); do
	echo "\t\t[\"client${i}\", \"s1\"]," >> ${tmp_file}
done

# last entry should omit a trailing comma
echo "\t\t[\"client${n_clients}\", \"s1\"]" >> ${tmp_file}


tmp_file_2='tmp_x2'
if [ -f "$tmp_file_2" ]; then
	echo "Error: Temporary file ${tmp_file_2} already exists."
	exit 1
fi

# populate all the server entires in "hosts" field
for i in $(seq $n_servers); do
	echo "\t\t\"server${i}\": { }," >> ${tmp_file_2}
done

# populate all the client entires in "links" field
for i in $(seq $(($n_clients-1))); do
	echo "\t\t\"client${i}\": { }," >> ${tmp_file_2}
done

# last entry should omit a trailing comma
echo "\t\t\"client${n_clients}\": { }" >> ${tmp_file_2}


prototype='p4app.json'
if ! [ -f "$prototype" ]; then
	echo "Error: File ${prototype} does not exist."
	exit 1
fi


generated_p4app="p4app_${n_servers}_${n_clients}.json"

sed '/"links":/{n;N;d}' ${prototype} > ${generated_p4app}
sed -i "/\"links\":/r ${tmp_file}" ${generated_p4app}
sed -i '/"hosts":/{n;N;d}' ${generated_p4app}
sed -i "/\"hosts\":/r ${tmp_file_2}" ${generated_p4app}


# clean up temp files
rm -f ${tmp_file} ${tmp_file_2}

