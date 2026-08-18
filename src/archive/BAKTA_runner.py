from pathlib import Path
from dataclasses import dataclass
import subprocess, sys, argparse, json
import logging


######## FUNCTIONS ########


def arg_parser(arg_vector: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="BAKTA: Bacterial Annotation Tool Kit")
    parser.add_argument("-i", "--input_folder", required=False, help="Input folder/directory")
    parser.add_argument("-f", "--input_file", required=False, help="Single input file")
    parser.add_argument("-o", "--output", required=True, help="Output directory")
    parser.add_argument("-c", "--config", required=False, help="Path to configuration file")
    return parser.parse_args(arg_vector)

def load_config(config_path: Path) -> dict[str,dict]:
    with open(config_path, 'r') as f:
        config = json.load(f)
    return config



######## CLASSES ########

#TODO: very big config class, maybe split into SLURMConfig, LOCALConfig and BAKTAConfig (unnecessary for now, but maybe later)
@dataclass(frozen=True)
class Config:
    #SLURM
    partition: str = "default"
    time: str = "01:00:00"
    nodes: int = 1
    ntasks: int = 1
    cpus_per_task: int = 1
    mem: str = "4G"

    #LOCAL
    threads: int = 4

    #BAKTA
    database: Path = Path("/path/to/bakta/database")

    @classmethod 
    def from_dict(cls, config_dict: dict[str,dict]) -> 'Config':
        return cls(
            partition=config_dict["SLURM"]["partition"],
            time=config_dict["SLURM"]["time"],
            nodes=config_dict["SLURM"]["nodes"],
            ntasks=config_dict["SLURM"]["ntasks"],
            cpus_per_task=config_dict["SLURM"]["cpus_per_task"],
            mem=config_dict["SLURM"]["mem"],
            database=Path(config_dict["BAKTA"]["database"])
        )

class JobSpecifications:
    def __init__(self, input_path: Path, output_path: Path, config: Config):
        self.input_path = input_path
        self.output_path = output_path
        self.config = config

class BaktaCommandBuilder:
    """TODO: add this to inject into SlurmCommandBuilder later
    """
    ...

class SlurmCommandBuilder:
    def __init__(self, job_specifications: JobSpecifications):
        self.job_specifications = job_specifications

    def build_command(self) -> list[str]:
        config = self.job_specifications.config
        input_path = self.job_specifications.input_path
        output_path = self.job_specifications.output_path

        command = [
            "sbatch",
            "--partition",str(config.partition),
            "--time", str(config.time),
            "--nodes", str(config.nodes),
            "--ntasks", str(config.ntasks),
            "--cpus-per-task", str(config.cpus_per_task),
            "--mem", str(config.mem),
            "--wrap", f"BAKTA --db {config.database} --output {output_path} {input_path}"
        ]
        return command

class LocalCommandBuilder:
    def __init__(self, job_specifications: JobSpecifications):
        self.job_specifications = job_specifications
        ...



class CommandExecutor:
    def __init__(self, command: str):
        self.command = command

    def execute(self):
        print(f"Executing command: {self.command}")
        subprocess.run(self.command, check=True, text=True)


######## MAIN ########



def main():
    args = arg_parser(sys.argv[1:])
    print("we ran it!")
    

if __name__ == '__main__':
    main()
