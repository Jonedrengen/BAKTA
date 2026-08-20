#!/bin/bash
#SBATCH -J BAKTA
#SBATCH --partition=project
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --error=BAKTA_%j.err
#SBATCH --output=BAKTA_%j.out

#author: Jon Sztuk Slotved (JOSS@ssi.dk)
#note: edit SBATCH parameters above to fit your needs.

#get script directory (currently not used, only used to get default config file path)
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

#help
help() {
    echo "Usage: $0 -i <input_folder> -o <output_folder> -c <config_file> [-h]"
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
        exit 1
    fi
    if [ ! -f "$config_file" ]; then
        echo "Error: Configuration file does not exist."
        exit 1
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
    local output_folder="$1"
    
    mkdir -p "$output_folder"
    mkdir -p "$output_folder/processing_files"
    mkdir -p "$output_folder/slurm_output"
    mkdir -p "$output_folder/combined_results"
    mkdir -p "$output_folder/combined_results/gff3_symlinks"
    mkdir -p "$output_folder/combined_results/pangolin_ready_files"
}

#run BAKTA func on a single isolate (uses parallel to run multiple isolates in parallel)
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

# aggregate gff3 outputs into a single file, with symlinks to the original
aggregate_gff_files() {
    local processing_files_input_folder="$1"
    local output_folder="$2"
    local gff3_file=""
    local gff3_output_destination="$output_folder/combined_results/gff3_symlinks"
    local counter=0

    for folder in "$processing_files_input_folder"/*; do
        gff3_file=$(find "$folder" -type f -name "*.gff3")
        
        if [ ! -f "$gff3_file" ]; then
            echo "No GFF3 file found in $folder"
            continue
        else
            ln -s "$gff3_file" "$gff3_output_destination/$(basename "$gff3_file")"
        fi  
        ((counter++))
    done
    echo "Processed $counter folders."
    echo "Generated $(find "$gff3_output_destination" -type l -name "*.gff3" | wc -l) symlinks in $gff3_output_destination"
}

#create gff3 annotation file for ppanggolin
generate_gff3_ppanggolin_annotated_file() {
    local input_folder_with_gff3="$1"
    local output_folder="$2"
    local base_name=""
    local path=""

    touch "$output_folder/ppanggolin_anno_ready.tsv"
    
    for file in "$input_folder_with_gff3"/*.gff3; do
        base_name=$(basename "$file" ".gff3")
        path=$file
        printf "%s\t%s\n" "$base_name" "$path" >> "$output_folder/ppanggolin_anno_ready.tsv"
    done
}

#move slurm stdout and stderr to slurm_output folder
move_slurm_stderr_stdout() {
    local slurm_output_folder="$1"
    local slurm_err_file="$2"
    local slurm_out_file="$3"
        mv -f "$slurm_err_file" "$slurm_output_folder/"
        mv -f "$slurm_out_file" "$slurm_output_folder/"
}


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


#######################################
############# run script ##############
#######################################

#export Global func and vars for parallel
export -f run_bakta
export db output_folder

#defines variables from config file
config_values "$config_file"

#activate conda environment
. "$conda_source"
conda activate "$conda_env"

#validate input folder
validate_input

#create output folder structure
create_output_structure "$output_folder"

#run BAKTA with parallel
parallel --jobs "${SLURM_CPUS_PER_TASK:-1}" run_bakta ::: "$input_folder"/*.f*

# symlink results into a single file (loops over folders in processing_files)
aggregate_gff_files "$output_folder/processing_files" "$output_folder"

# save a file with the gff3 files and their paths for ppanggolin
generate_gff3_ppanggolin_annotated_file "$output_folder/combined_results/gff3_symlinks" "$output_folder/combined_results/pangolin_ready_files"

#move slurm stdout and stderr to slurm_output folder
move_slurm_stderr_stdout "$output_folder/slurm_output" "BAKTA_${SLURM_JOB_ID}.err" "BAKTA_${SLURM_JOB_ID}.out"
