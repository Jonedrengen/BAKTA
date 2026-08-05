from pathlib import Path
from dataclasses import dataclass
import multiprocessing, sys, argparse, json
from typing import Protocol


######## FUNCTIONS ########


def arg_parser(arg_vector: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="BAKTA: Bacterial Annotation Tool Kit")
    parser.add_argument("-i", "--input", required=True, help="Input file or directory")
    parser.add_argument("-o", "--output", required=True, help="Output directory")
    parser.add_argument("-c", "--config", required=False, help="Path to configuration file")
    return parser.parse_args(arg_vector)

def load_config(config_path: Path) -> dict[str,str | int]:
    with open(config_path, 'r') as f:
        config = json.load(f)
    return config



######## CLASSES ########

class Executur(Protocol):
    def run(self, job_specifications: "JobSpecifications") -> None:
        ...

@dataclass(frozen=True)
class Config:
    partition: str = "default"
    time: str = "01:00:00"
    nodes: int = 1
    ntasks: int = 1
    cpus_per_task: int = 1
    mem: str = "4G"

    @classmethod
    def from_dict(cls, config_dict: dict) -> "Config":
        return cls(
            partition=config_dict.get("partition", cls.partition),
            time=config_dict.get("time", cls.time),
            nodes=config_dict.get("nodes", cls.nodes),
            ntasks=config_dict.get("ntasks", cls.ntasks),
            cpus_per_task=config_dict.get("cpus-per-task", cls.cpus_per_task),
            mem=config_dict.get("mem", cls.mem),
        )
        

@dataclass(frozen=True)
class JobSpecifications:
    input_path: Path
    output_path: Path
    config: Config
    ...
        



######## MAIN ########



def main():
    args = arg_parser(sys.argv[1:])
    print("we ran it!")

if __name__ == '__main__':
    main()
