#!/usr/bin/env bash

log_banner() {
    local msg="$1"
    echo "*************************************** ${msg} *************************************************"
}

# Default values
iterations=5
log_file="fio_output.log"
read_or_write="write"
file_size="1G"
cleanup=false
fio_binary="fio"

usage() {
    log_banner "HELP=START"
    echo
    echo "Usage: $0 [-i iterations] [-l log_file] [-o operation] [-s size] [-f fio_path] [-c] [-h]"
    echo "Options:"
    echo "  -i <iterations>      Number of iterations (default: ${iterations})"
    echo "  -l <log_file>        File to write the FIO output log (default: ${log_file})"
    echo "  -o <operation>       Operation: read, write, rwrite (random-write), rread (random-read) (default: ${read_or_write})"
    echo "  -s <size>            Size of the file to test, with unit (default: ${file_size})"
    echo "  -f <fio_path>        Path to a custom fio binary (default: ${fio_binary})"
    echo "  -c                   Cleanup generated fio directory/files after the test."
    echo "  -h                   Display this help message."
    echo
    log_banner "HELP=END"
    exit 0
}

while getopts "i:l:o:s:f:ch" opt; do
    case ${opt} in
        i) iterations=$OPTARG ;;
        l) log_file=$OPTARG ;;
        o) read_or_write=$OPTARG ;;
        s) file_size=$OPTARG ;;
        f) fio_binary=$OPTARG ;;
        c) cleanup=true ;;
        h) usage ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            usage
            ;;
    esac
done
shift $((OPTIND -1))

operation="write"
if [ "$read_or_write" == "read" ]; then
    operation="read"
elif [ "$read_or_write" == "rwrite" ]; then
    operation="randwrite"
elif [ "$read_or_write" == "rread" ]; then
    operation="randread"
fi


log_banner "INFO=START"
echo "iterations: $iterations"
echo "fio-used: $($fio_binary --version)"
echo "operation: $operation"
echo "file_size: $file_size"
echo "log will be saved to: $log_file"
log_banner "INFO=END"


directory="./fio_dir_${operation}_$(date +%Y%m%d_%H%M%S)_${file_size}"
mkdir "$directory" || {
    echo "failed to create temp directory"
    exit 1
}


show_progress() {
    current=$1
    total=$2
    progress=$((current * 100 / total))
    echo -ne "Progress: ($current/$total) [$progress%] \r"
}

curr_iter=1
while [ "$curr_iter" -le "$iterations" ]; do
    "$fio_binary" --filename="./"$directory"/file_${curr_iter}.bin" --name="fio_${curr_iter}" --rw="$operation" --size="$file_size" >> "$log_file" || {
        echo "Failed to run fio"
        exit 1
    }
    show_progress "$curr_iter" "$iterations"
    ((curr_iter++))
done
echo "Progress: (${iterations}/${iterations}) [100%] Done"


# search args for --cleanup
if [ "$cleanup" = true ]; then
    echo "Cleaning up..."
    rm -rf "$directory"
fi

#