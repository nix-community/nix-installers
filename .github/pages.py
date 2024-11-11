#!/usr/bin/env python3
import json
import sys
import os
import os.path
import subprocess
import shutil
import hashlib
from pathlib import Path


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    b = bytearray(128 * 1024)
    mv = memoryview(b)
    with open(path, "rb", buffering=0) as f:
        while n := f.readinto(mv):
            h.update(mv[:n])
    return h.hexdigest()


def main(
    input_path: str, attrs: dict[str, dict[str, dict]], output: str
) -> None:
    installers = attrs["installers"]
    impl_links = attrs["impls"]

    os.mkdir(output)

    with open(input_path) as readme_f:
        lines: List[str] = readme_f.read().split("\n")

    md: List[str] = []
    rewriting = False
    found = False
    for line in lines:
        if rewriting and line.startswith("###"):
            rewriting = False

        if rewriting:
            continue

        md.append(line)

        if line == "### Prebuilt installers":
            if found:
                raise ValueError("Found duplicate segment in readme")
            rewriting = True
            found = True

            for impl, impls in installers.items():
                md.append(f"#### [{impl.capitalize()}]({impl_links[impl]})\n")

                for fmt, arches in impls.items():
                    md.append(f"- {fmt.capitalize()}\n")

                    for arch, pkg in arches.items():
                        store_path = pkg["store_path"]

                        f = os.path.basename(store_path.split("-", 1)[-1])

                        output_dir = Path(output).joinpath(impl).joinpath(arch)
                        output_dir.mkdir(parents=True, exist_ok=True)

                        output_file = output_dir.joinpath(f)
                        shutil.copy(store_path, output_file)

                        os.symlink(
                            f,
                            os.path.join(
                                output_dir, f.replace(pkg["version"], "latest")
                            ),
                        )

                        sha = sha256_file(output_file)

                        md.append(f"    - {arch}:\n [{f}](./{impl}/{arch}/{f}) `({sha})`\n")

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
        attrs = json.load(f)

    main(md_path, attrs, output)
