#!/usr/bin/env python3
import json
import sys
import os
import os.path
import subprocess
import shutil


def main(input_path, installers, output):
    os.mkdir(output)

    with open(input_path) as f:
        lines = f.read().split("\n")

    md = [ ]
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

            for fmt, store_path in installers.items():
                f = os.path.basename(store_path.split("-", 1)[-1])
                shutil.copy(store_path, os.path.join(output, f))
                md.append(f"- {fmt.capitalize()}: [{f}](./{f})")

            md.append("")

    if not found:
        raise ValueError("Did not find expected segment in readme")

    with open(os.path.join(output, "index.html"), "w") as f:
        subprocess.run(["pandoc"], input="\n".join(md).encode(), stdout=f)


if __name__ == "__main__":
    md_path = sys.argv[1]
    attrs_path = sys.argv[2]
    output = sys.argv[3]

    with open(attrs_path) as f:
        installers = json.load(f)["installers"]

    main(md_path, installers, output)
