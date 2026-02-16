# NOTE: just do `odin run /path_to_src -debug -collection:sokol=sokol-odin/sokol`
# use this script if you have weaponized autism like Aoi Todo

#!/usr/bin/env python3

import argparse
import platform
import subprocess
import shutil
import sys
from pathlib import Path

IS_LINUX   = platform.system() == "Linux"
IS_WINDOWS = platform.system() == "Windows"

# ----------------------------------------------------------------
program_name  = "cartoon"
source        = "src/1_6_multiple_textures"

collections   = ["-collection:sokol=sokol-odin/sokol"]
extra_flags   = ["-strict-style", "-microarch:native"]
debug_flags   = ["-debug", "-o:minimal"]
release_flags = ["-o:speed", "-vet", "-no-bounds-check"]

if IS_LINUX:
    extra_flags.append("-linker:mold")

if IS_WINDOWS:
    extra_flags.append("-subsystem:windows")

# ----------------------------------------------------------------
parser = argparse.ArgumentParser(
    prog='make_exe',
    description='build script for odin projects',
    epilog='made by cartoon'
)

parser.add_argument("-release", action="store_true", help="release build")
parser.add_argument("-debug",   action="store_true", help="debug build")
parser.add_argument("-clean",   action="store_true", help="clean build folder")
parser.add_argument("-run",     action="store_true", help="run after compiling")
parser.add_argument("-hold",    action="store_true", help="hold on error when using -run")
parser.add_argument("-check",   action="store_true", help="check all programs")

args = parser.parse_args()

# ----------------------------------------------------------------
def main():
    root_build_dir = Path("build")

    if args.clean:
        clean(root_build_dir)
        sys.exit(0)

    if not (args.debug or args.release):
        print("pass one argument: -release | -debug | -clean | --help")
        sys.exit(1)

    build_dir = root_build_dir / ("release" if args.release else "debug")
    flags = (release_flags if args.release else debug_flags) + collections + extra_flags

    if args.release:
        clean(build_dir)

    build_dir.mkdir(parents=True, exist_ok=True)

    if args.check:
        check_programs(build_dir, flags)
        sys.exit(0)

    binary = build_dir / program_name
    build(source, binary, flags)

# ----------------------------------------------------------------
def build(source, binary: Path, flags):
    if IS_WINDOWS:
        binary = binary.with_suffix(".exe")

    # options = "run" if args.run else "build"
    command = ["odin", "build", source, f"-out:{str(binary)}"] + flags

    print(" ".join(command))

    try:
        subprocess.run(command, check=True)
    except subprocess.CalledProcessError:
        if args.hold:
            input("\nPress 'Enter' to exit...")
        sys.exit(1)
    except KeyboardInterrupt:
        print(f"\nforce quit: {str(binary)}")
        sys.exit(0)

    if args.run:
        run(binary)

# ----------------------------------------------------------------
def run(binary: Path):
    if not binary.exists():
        print("Cannot run: binary not found")
        return

    print(f"Running: {binary}\n")
    try:
        subprocess.run([str(binary)], check=True)
    except subprocess.CalledProcessError:
        if args.hold:
            input("\nPress Enter to exit...")
        sys.exit(1)
    except KeyboardInterrupt:
        print(f"\nForce quit: {binary}")
        sys.exit(0)

# ----------------------------------------------------------------
def clean(path: Path):
    if path.exists():
        shutil.rmtree(path)
        print(f"Removed directory: {path}")
    else:
        print(f"No directory to clean at: {path}")


# ----------------------------------------------------------------
# stupid way to test things
def check_programs(build_dir: Path, flags):
    for p in Path("src").iterdir():
        if not p.is_dir():
            continue

        print("----------------------------------------------------------------")
        print(f"Building: {p.name}")
        binary = build_dir / program_name
        build(str(p), binary, flags)
        print()

if __name__ == "__main__":
    main()
