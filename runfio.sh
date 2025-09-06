#!/usr/bin/env bash

# HELP
if [[ "$1" == '-h' || "$1" == '--help' ]]; then
    echo "Usage: $0 [iterations] [log_file] [read|write] [file_size:default=1G]"
    exit 0
fi

iterations=${1:-5} # default 5 iterations
log_file=${2:-"fio_output.log"}
read_or_write=${3:-"write"}
file_size=${4:-"1G"}
echo "iterations: $iterations"

echo "fio v$(fio --version | cut -d'-' -f 2)"
echo "cmd: fio $read_or_write"

operation="write"
if [ "$read_or_write" == "read" ]; then
    operation="read"
fi

directory="./fio_dir_${operation}"
mkdir "$directory" || {
    echo "failed to create temp directory"
    exit 1
}


show_progress() {
    current=$1
    total=$2
    progress=$((current * 100 / total))
    echo -ne "Progress: $progress% \r"
}



curr_iter=0
while [ "$curr_iter" -le "$iterations" ]; do
    fio --filename="./"$directory"/file_${curr_iter}.bin" --name="fio_${curr_iter}" --rw="$operation" --size="$file_size" >> "$log_file" || {
        echo "Failed to run fio"
        exit 1
    }
    ((curr_iter++))
    show_progress "$curr_iter" "$iterations"
done
echo "Progress: 100%"
