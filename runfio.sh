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
blocksize="4k"
direct_io=0
numjobs=1
nrfiles=1
iodepth=1
runtime="0"

usage() {
    log_banner "HELP=START"
    echo
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -i <iterations>      Number of iterations (default: ${iterations})"
    echo "  -l <log_file>        File to write the FIO output log (default: ${log_file})"
    echo "  -o <operation>       Operation: read, write, rwrite (random-write), rread (random-read) (default: ${read_or_write})"
    echo "  -s <size>            Size of the file to test, with unit (default: ${file_size})"
    echo "  -f <fio_path>        Path to a custom fio binary (default: ${fio_binary})"
    echo "  -b <blocksize>       Block size for the fio test (default: ${blocksize})"
    echo "  -j <numjobs>         Number of parallel jobs to run (default: ${numjobs})"
    echo "  -N <nrfiles>         Number of files to use per job (default: ${nrfiles})"
    echo "  -D <iodepth>         Number of I/O units to keep in flight (default: ${iodepth})"
    echo "  -t <runtime>         Stop after this amount of seconds (e.g., 60). If set, enables time_based mode."
    echo "  -d                   Enable direct I/O for the fio test. (default: ${direct_io})"
    echo "  -c                   Cleanup generated fio directory/files after the test. (default: ${cleanup})"
    echo "  -h                   Display help."
    echo
    log_banner "HELP=END"
    exit 0
}

while getopts "i:l:o:s:f:b:j:N:D:t:dch" opt; do
    case ${opt} in
        i) iterations=$OPTARG ;;
        l) log_file=$OPTARG ;;
        o) read_or_write=$OPTARG ;;
        s) file_size=$OPTARG ;;
        f) fio_binary=$OPTARG ;;
        b) blocksize=$OPTARG ;;
        j) numjobs=$OPTARG ;;
        N) nrfiles=$OPTARG ;;
        D) iodepth=$OPTARG ;;
        t) runtime=$OPTARG ;;
        d) direct_io=1 ;;
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
echo "direct_io: $direct_io"
echo "blocksize: $blocksize"
echo "numjobs: $numjobs"
echo "nrfiles: $nrfiles"
echo "iodepth: $iodepth"
[ "$runtime" != "0" ] && echo "runtime: ${runtime}s"
log_banner "INFO=END"


directory="./fio_dir_${operation}_$(date +%Y%m%d_%H%M%S)_${file_size}"
mkdir "$directory" || {
    echo "failed to create temp directory"
    exit 1
}

fio_opts=(
    --name="fio_test"
    --filename_format="file.\$jobnum.\$filenum"
    --directory="$directory"
    --rw="$operation"
    --size="$file_size"
    --blocksize="$blocksize"
    --direct="$direct_io"
    --numjobs="$numjobs"
    --nrfiles="$nrfiles"
    --iodepth="$iodepth"
    --group_reporting
)

if [ "$runtime" != "0" ]; then
    fio_opts+=(--time_based --runtime="$runtime")
fi

show_progress() {
    current=$1
    total=$2
    progress=$((current * 100 / total))
    echo -ne "Progress: ($current/$total) [$progress%] \r"
}

curr_iter=1
while [ "$curr_iter" -le "$iterations" ]; do
    # log_banner "Running iteration $curr_iter of $iterations"
    "$fio_binary" "${fio_opts[@]}" >> "$log_file" || {
        echo "Failed to run fio"
        exit 1
    }
    show_progress "$curr_iter" "$iterations"
    ((curr_iter++))
done

echo -e "Progress: ($iterations/$iterations) [100%] Done"


if [ "$cleanup" = true ]; then
    echo "Cleaning up..."
    rm -rf "$directory"
fi

#