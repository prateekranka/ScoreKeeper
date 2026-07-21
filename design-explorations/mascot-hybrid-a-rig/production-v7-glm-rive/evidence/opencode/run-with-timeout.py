#!/usr/bin/env python3

import os
import signal
import subprocess
import sys


def main() -> int:
    if len(sys.argv) < 4:
        raise SystemExit("usage: run-with-timeout.py <seconds> <stdout> <stderr> <command...>")
    seconds = int(sys.argv[1])
    stdout_path = sys.argv[2]
    stderr_path = sys.argv[3]
    command = sys.argv[4:]
    with open(stdout_path, "wb") as stdout_file, open(stderr_path, "wb") as stderr_file:
        process = subprocess.Popen(
            command,
            stdout=stdout_file,
            stderr=stderr_file,
            start_new_session=True,
        )

        def terminate_group() -> None:
            if process.poll() is not None:
                return
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()

        try:
            return process.wait(timeout=seconds)
        except subprocess.TimeoutExpired:
            terminate_group()
            return 124
        except KeyboardInterrupt:
            terminate_group()
            return 130


if __name__ == "__main__":
    raise SystemExit(main())
