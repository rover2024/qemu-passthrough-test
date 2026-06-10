#!/usr/bin/env python3

import argparse
import os
import re
import sys
from pathlib import Path


SIZE_RE = re.compile(r"^\s*(\d+)\s*([kKmMgG]?)\s*$")
UNIT_SCALE = {
    "": 1,
    "K": 1024,
    "M": 1024 * 1024,
    "G": 1024 * 1024 * 1024,
}


def parse_size(text: str) -> int:
    match = SIZE_RE.fullmatch(text)
    if match is None:
        raise argparse.ArgumentTypeError(
            f"invalid size {text!r}; expected forms like 4096, 4K, 128M, 1G"
        )

    value = int(match.group(1))
    suffix = match.group(2).upper()
    size = value * UNIT_SCALE[suffix]
    if size <= 0:
        raise argparse.ArgumentTypeError("size must be greater than 0")
    return size


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Generate a synthetic input file for minizip benchmarking. "
            "The file is made of a small random seed repeated to the requested size, "
            "which makes compression time more stable than archiving /usr/bin."
        )
    )
    parser.add_argument(
        "output",
        type=Path,
        help="output file path, for example archive.tar or bench-160M.bin",
    )
    parser.add_argument(
        "size",
        type=parse_size,
        help="target size, supports plain bytes or suffixes K, M, G, for example 192M",
    )
    parser.add_argument(
        "--seed-size",
        type=parse_size,
        default=parse_size("8K"),
        help=(
            "size of the repeated random seed block; defaults to 8K. "
            "Keep this at or below 32K if you want data that stays highly compressible."
        ),
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="overwrite the output file if it already exists",
    )
    return parser


def write_archive(output: Path, total_size: int, seed_size: int) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)

    seed = os.urandom(seed_size)
    remaining = total_size

    with output.open("wb") as fp:
        while remaining > 0:
            chunk = seed if remaining >= seed_size else seed[:remaining]
            fp.write(chunk)
            remaining -= len(chunk)


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    if args.seed_size <= 0:
        parser.error("--seed-size must be greater than 0")

    if args.output.exists() and not args.force:
        parser.error(
            f"{args.output} already exists; pass --force to overwrite it"
        )

    write_archive(args.output, args.size, args.seed_size)
    print(f"wrote {args.output} ({args.size} bytes, seed {args.seed_size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
