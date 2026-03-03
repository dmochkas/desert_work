import itertools
import json
import os
import subprocess
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Any, Dict, List

ITERATIONS_BATCH_SIZE = 10

def normalize_path(path: str) -> Path:
    return Path(os.path.expandvars(os.path.expanduser(path))).resolve()


class SimConfig:
    def __init__(
        self,
        *,
        runner: str | Path = "",
        script: str | Path = "",
        desertEnv: str | Path = "",
        cwd: str | Path | None = None,
        rngStart: int = 1,
        rngRounds: int = 10,
        iterations: List[Dict[str, Any]] | None = None,
        order: List[str] | None = None,
        cfg_file: str | Path | None = None,
    ):
        self.runner = runner
        self.script = script
        self.desertEnv = desertEnv
        self.cwd = cwd
        self._rngStart = rngStart
        self._rngRounds = rngRounds
        self._iterations = list(iterations) if iterations else []
        self._order = list(order) if order else []

        if cfg_file is not None:
            self.__from_file(cfg_file)

    @property
    def runner(self) -> Path | None:
        return self._runner

    @runner.setter
    def runner(self, value: str | Path) -> None:
        self._runner = normalize_path(value)

    @property
    def script(self) -> Path | None:
        return self._script

    @script.setter
    def script(self, value: str | Path) -> None:
        self._script = normalize_path(value)

    @property
    def desertEnv(self) -> Path | None:
        return self._desertEnv

    @desertEnv.setter
    def desertEnv(self, value: str | Path) -> None:
        self._desertEnv = normalize_path(value)

    @property
    def cwd(self) -> Path:
        return self._cwd

    @cwd.setter
    def cwd(self, value: str | Path | None) -> None:
        self._cwd = normalize_path(value) if value is not None else Path.cwd().resolve()


    def __from_file(self, cfg_file: str | Path):
        cfg_json = _read_json_config(cfg_file)

        self.desertEnv = cfg_json.get("desertEnv", self.desertEnv)
        self.cwd = cfg_json.get("cwd", self.cwd)
        self.runner = cfg_json.get("runner", self.runner)
        self._rngStart = int(cfg_json.get("rngStart", self._rngStart))
        self._rngRounds = int(cfg_json.get("rngRounds", self._rngRounds))
        self._order = cfg_json.get("order", self._order)
        self._iterations = _get_iterations_from_config(cfg_json, self._order)


    def _run_task(self, cmd, cancel_event, verbose):
        if cancel_event.is_set():
            if verbose:
                print("Cancel evnt is set. Skipping command: ", cmd)
            return -1

        if verbose:
            print("Executing in a thread:", cmd)

        completed = subprocess.run(["bash", "-c", cmd], cwd=self.cwd)
        return completed.returncode


    def _build_cmd(self, rng: int, it: Dict[str, Any]):
        cmds: List[str] = []
        if self.desertEnv:
            cmds.append(f"source '{self.desertEnv}'")

        params = " ".join(str(it[k]) for k in it)
        cmd = f"{self._runner} {self._script} {params} {rng}".strip()
        cmds.append(cmd)

        return " && ".join(cmds)


    def run(self, parallel: bool = False, dry_run: bool = False, verbose: bool = False):
        if verbose:
            print(
                f"Loaded: rng_rounds={self._rngRounds}, rng_start={self._rngStart}, entries={len(self._iterations)}"
            )

        if self.desertEnv and not self.desertEnv.exists():
            raise FileNotFoundError(f"DESERT env file not found: {self.desertEnv}")

        cancel_event = threading.Event()

        cmds = [self._build_cmd(rng, it) for rng in range(self._rngStart, self._rngStart + self._rngRounds) for it in self._iterations]

        if dry_run:
            return

        if parallel:
            with ThreadPoolExecutor() as executor:
                futures = {executor.submit(self._run_task, cmd, cancel_event, verbose): cmd for cmd in cmds}
                for future in as_completed(futures):
                    rc = future.result()
                    if rc != 0:
                        cancel_event.set()
                        raise RuntimeError(f"Command failed with exit code {rc}")
            return

        for cmd in cmds:
            if verbose:
                print("Executing bash command...")
                print(cmd)

            completed = subprocess.run(["bash", "-c", cmd], cwd=self.cwd)
            if completed.returncode != 0:
                raise RuntimeError(f"Command failed with exit code {completed.returncode}")


def _read_json_config(cfg_file: str | Path) -> Dict[str, Any]:
    cfg_path = Path(cfg_file).resolve()

    if not cfg_path.is_file():
        raise FileNotFoundError(f"Config file not found: {cfg_path}")

    if cfg_path.suffix.lower() != ".json":
        raise ValueError(f"Config file must be a .json file, got: {cfg_path.name}")

    try:
        cfg = json.loads(cfg_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in {cfg_path}: {e}") from e

    return cfg


def _get_iterations_from_config(cfg: Dict[str, Any], order: List[str]) -> List[Dict[str, Any]]:
    """Return the Cartesian product of all values in cfg['combine'],
    concatenated with any explicit entries in cfg['iterations'].

    Each element of the returned list is a flat dict whose keys are the
    combine-key names and whose values are one specific pick from every list.
    """
    comb: Dict[str, List] = cfg.get("combine", {})
    explicit: List[Dict[str, Any]] = cfg.get("iterations", [])

    if not comb:
        return list(explicit)

    keys = [k for k in order if k in comb] + [k for k in comb.keys() if k not in order]
    values = [comb[k] for k in keys]

    iterations: List[Dict[str, Any]] = []
    for combo in itertools.product(*values):
        iterations.append(dict(zip(keys, combo)))

    iterations.extend([{k: d[k] for k in order if k in d} | {k: d[k] for k in d.keys() if k not in order} for d in explicit])
    return iterations
