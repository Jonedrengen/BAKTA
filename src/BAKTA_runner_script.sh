#!/bin/bash
#SBATCH -j=BAKTA
#SBATCH --partition=project
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --error=BAKTA_%j.err
#SBATCH --output=BAKTA_%j.out


#get script directory
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

#
help() {
    echo "Usage: $0 -i <input_folder> -o <output_folder> [-c <config_file>] [-h]"
    echo "  -i <input_folder>   : Path to the input folder containing FASTA files."
    echo "  -o <output_folder>  : Path to the output folder where results will be saved."
    echo "  -c <config_file>    : Path to the configuration file (default: $script_dir/config_bash.yml)."
    echo "  -h                  : Display this help message."
}

# validate input
validate_input() {
    if [ ! -d "$input_folder" ]; then
        echo "Error: Input folder does not exist."
        return 1
    fi
    if [[ ! -f "$config_file" ]]; then
        echo "Error: Configuration file does not exist."
        return 1
    fi
}

# read configuration values from config_bash.yml
config_values() {
    config=$1

    # Load configuration values from config_bash.yml
    db=$(grep '^db:' "$config" | awk '{print $2}')

    if [ -z "$db" ]; then
        echo "Error: Database path not specified in the configuration file."
        return 1
    fi
    return 0
}

# create folder structure for output
create_output_structure() {
    output_folder="$1"
    mkdir -p "$output_folder"
    mkdir -p "$output_folder/processing_files"
}

#run BAKTA, using GNU parallel to run multiple samples in parallel
run_bakta() {
    input_folder="$1"
    output_folder="$2"

    parallel -j "$cores" --bar \
    bakta \
        --db "$db" \
        --output "$output_folder/${/.}" \
        --prefix "${/.}" \
        --threads 1 \
        {} \
        ::: "$input_folder"/*.f*
}
export -f help validate_input config_values create_output_structure run_bakta

#default values
input_folder=""
output_folder=""
config_file_default=$script_dir/config_bash.yml

while getopts ":c:o:i:h" opt; do
    case "$opt" in
        h) help; exit 0 ;;
        i) input_folder="$OPTARG";;
        o) output_folder="$OPTARG";;
        c) config_file="${OPTARG:-$config_file_default}";;
        \?) echo "Not an option" "-$OPTARG;" exit 1 ;;
        :) help; exit 1;;
    esac
done
if [ "$#" -eq 0 ]; then
    help
    exit 1
fi

############# run script #############

#defines config values
config_values "$config_file"

#validate input folder
validate_input

#create output folder structure
create_output_structure "$output_folder"

#run BAKTA
run_bakta "$input_folder" "$output_folder"

