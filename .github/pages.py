#!/usr/bin/env python3
import json
import sys
import os
import os.path
import subprocess
import shutil
import hashlib
from typing import (
    Dict,
    List,
)


def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    b = bytearray(128 * 1024)
    mv = memoryview(b)
    with open(path, "rb", buffering=0) as f:
        while n := f.readinto(mv):
            h.update(mv[:n])
    return h.hexdigest()


def main(
    input_path: str, installers: Dict[str, Dict[str, Dict[str, str]]], output: str
) -> None:
    os.mkdir(output)

    with open(input_path) as readme_f:
        lines: List[str] = readme_f.read().split("\n")

    md: List[str] = []
    rewriting = False
    found = False
    for l in lines:
        if rewriting and l.startswith("###"):
            rewriting = False

        if rewriting:
            continue

        md.append(l)

        if l == "### Prebuilt installers":
            if found:
                raise ValueError("Found duplicate segment in readme")
            rewriting = True
            found = True

            for fmt, arches in installers.items():
                md.append(f"- {fmt.capitalize()}")

                for arch, pkg in arches.items():
                    store_path = pkg["store_path"]

                    f = os.path.basename(store_path.split("-", 1)[-1])

                    output_dir = os.path.join(output, arch)
                    try:
                        os.mkdir(output_dir)
                    except FileExistsError:
                        pass

                    output_file = os.path.join(output_dir, f)
                    shutil.copy(store_path, output_file)

                    os.symlink(
                        f,
                        os.path.join(output_dir, f.replace(pkg["version"], "latest")),
                    )

                    sha = sha256_file(output_file)

                    md.append(f"    - {arch}:\n [{f}](./{arch}/{f}) `({sha})`")

            md.append("")

    if not found:
        raise ValueError("Did not find expected segment in readme")

    with open(os.path.join(output, "index.html"), "w") as index_f:
        subprocess.run(["pandoc"], input="\n".join(md).encode(), stdout=index_f)


if __name__ == "__main__":
    md_path = sys.argv[1]
    attrs_path = sys.argv[2]
    output = sys.argv[3]

    with open(attrs_path) as f:
        installers = json.load(f)["installers"]

    main(md_path, installers, output)
