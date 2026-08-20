this is a wrapper of the BAKTA tool

## Setup

This wrapper submits a Slurm job and annotates every FASTA file in an input
directory. It requires a Slurm installation, Conda, BAKTA, a downloaded BAKTA
database, and GNU Parallel.

Create and activate a Conda environment, then install the required tools:

```bash
conda create -n BAKTA_JOSS -y
conda activate BAKTA_JOSS
conda install -c conda-forge -c bioconda bakta parallel -y
```

Download a BAKTA database to a persistent location. Replace the example path
with a location that has sufficient storage:

```bash
cd BAKTA
bakta_db download --type full
```

Create a local configuration file from the template, then edit it for your
system:

```bash
cp src/config/config_bash_template.yml bakta_config.yml
```

Set all three paths in `bakta_config.yml`:

```yaml
db: /path/to/bakta_database
conda_env: BAKTA_JOSS
conda_source: /path/to/miniconda3/etc/profile.d/conda.sh
```

`conda_source` must point to the `conda.sh` file supplied by your Conda
installation. No special characters!

Before submitting, review the `#SBATCH` settings at the top of
`src/BAKTA_runner_script.sh` and adjust the partition, CPU count, memory, and
other limits for your cluster.

## Run

Put input assemblies with `.fa`, `.fasta`, or `.fna` extensions in one input
directory, then submit the job:

```bash
sbatch src/BAKTA_runner_script.sh \
  -i /path/to/input_fastas \
  -o /path/to/bakta_results \
  -c bakta_config.yml
```

The output directory contains per-sample BAKTA output in `processing_files/`,
Slurm logs in `slurm_output/`, and GFF3 symlinks plus a PPanGGOLiN-ready TSV in
`combined_results/`.
