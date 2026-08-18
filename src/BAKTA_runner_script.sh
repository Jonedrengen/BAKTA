#!/bin/bash
#SBATCH -J BAKTA
#SBATCH --partition=project
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --error=BAKTA_%j.err
#SBATCH --output=BAKTA_%j.out

#author: Jon Sztuk Slotved

#get script directory
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

#help
help() {
    echo "Usage: $0 -i <input_folder> -o <output_folder> -c <config_file> [-s <sample_list>] [-h]"
    echo "Options:"
    echo "  -i <input_folder>   Path to the input folder containing FASTA files."
    echo "  -o <output_folder>  Path to the output folder where results will be saved."
    echo "  -c <config_file>    Path to the configuration file (default: config_bash.yml)."
    echo "  -h                  Display this help message."
    echo    
    echo "Note: only takes fasta,fna,fa"

}

# validate input
validate_input() {
    if [ ! -d "$input_folder" ]; then
        echo "Error: Input folder does not exist."
        return 1
    fi
    if [ ! -f "$config_file" ]; then
        echo "Error: Configuration file does not exist."
        return 1
    fi
}

# read configuration values from config_bash.yml
config_values() {
    config=$1

    # Load configuration values from config_bash.yml
    db=$(grep '^db:' "$config" | awk '{print $2}')
    conda_source=$(grep '^conda_source:' "$config" | awk '{print $2}')
    conda_env=$(grep '^conda_env:' "$config" | awk '{print $2}')

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
    local sequence="$1"
    local file_name=""
    local sample_name=""
    file_name=$(basename "$sequence")
    sample_name="${file_name%%.*}"
    output_dest="$output_folder/processing_files/$sample_name"

    bakta --db "$db" \
    --output "$output_dest" \
    --prefix "$sample_name" \
    --threads 1 \
    "$sequence"
}
export -f run_bakta
export db output_folder

#default values
input_folder=""
output_folder=""
config_file="$script_dir/config_bash.yml"

while getopts ":c:o:i:h" opt; do
    case "$opt" in
        h) help; exit 0 ;;
        i) input_folder="$OPTARG";;
        o) output_folder="$OPTARG";;
        c) config_file="$OPTARG";;
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

#activate conda environment
. "$conda_source"
conda activate "$conda_env"

#validate input folder
validate_input

#create output folder structure
create_output_structure "$output_folder"

#run BAKTA
parallel --jobs "${SLURM_CPUS_PER_TASK:-1}" run_bakta ::: "$input_folder"/*.f*
