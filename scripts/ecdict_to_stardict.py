#!/usr/bin/env python3
"""Convert ECDICT's sorted stardict.csv export to a KOReader StarDict."""

from __future__ import annotations

import argparse
import csv
import struct
import sys
from pathlib import Path

BOOK_NAME = "ECDICT 英汉词典（增强词形）"
REQUIRED_COLUMNS = {"word", "phonetic", "definition", "translation", "exchange"}
EXCHANGE_LABELS = {
    "p": "过去式",
    "d": "过去分词",
    "i": "现在分词",
    "3": "第三人称单数",
    "r": "比较级",
    "t": "最高级",
    "s": "复数",
    "0": "原形",
    "1": "词形类型",
}
UINT32_MAX = (1 << 32) - 1


def clean_field(value: str | None) -> str:
    """Normalize ECDICT's escaped line breaks for plain-text StarDict output."""
    return (value or "").replace("\\r", "").replace("\\n", "\n").strip()


def render_entry(row: dict[str, str]) -> bytes:
    parts: list[str] = []
    phonetic = clean_field(row.get("phonetic"))
    translation = clean_field(row.get("translation"))
    definition = clean_field(row.get("definition"))
    exchange = clean_field(row.get("exchange"))

    if phonetic:
        parts.append(f"音标：/{phonetic}/")
    if translation:
        parts.append(f"中文释义：\n{translation}")
    if definition:
        parts.append(f"英文释义：\n{definition}")
    if exchange:
        forms: list[str] = []
        for item in exchange.split("/"):
            code, separator, value = item.partition(":")
            if separator and value:
                forms.append(f"{EXCHANGE_LABELS.get(code, code)}：{value}")
        if forms:
            parts.append("词形变化：\n" + "；".join(forms))

    return ("\n\n".join(parts) or row["word"]).encode("utf-8")


def convert(source: Path, output_dir: Path, expected_count: int | None = None) -> int:
    """Stream a pre-sorted ECDICT CSV into StarDict files and return its row count."""
    output_dir.mkdir(parents=True, exist_ok=False)
    base = output_dir / "ecdict-en-zh"
    idx_path = base.with_suffix(".idx")
    dict_path = base.with_suffix(".dict")

    count = 0
    position = 0
    previous_sort_key: tuple[str, str] | None = None

    with source.open(encoding="utf-8", newline="") as source_file, \
            idx_path.open("wb") as idx_file, dict_path.open("wb") as dict_file:
        reader = csv.DictReader(source_file)
        columns = set(reader.fieldnames or ())
        missing = REQUIRED_COLUMNS - columns
        if missing:
            raise ValueError(f"missing CSV columns: {', '.join(sorted(missing))}")

        for record_number, row in enumerate(reader, start=2):
            word = row["word"].strip()
            if not word:
                raise ValueError(f"empty word at CSV record {record_number}")
            if "\0" in word:
                raise ValueError(f"word contains NUL at CSV record {record_number}")

            sort_key = (word.lower(), word)
            if previous_sort_key is not None and sort_key <= previous_sort_key:
                raise ValueError(
                    f"CSV words must be unique and sorted case-insensitively: {word!r} "
                    f"at record {record_number}"
                )
            previous_sort_key = sort_key

            payload = render_entry(row)
            if position + len(payload) > UINT32_MAX:
                raise ValueError("dictionary exceeds StarDict 32-bit offset limits")

            idx_file.write(word.encode("utf-8"))
            idx_file.write(b"\0")
            idx_file.write(struct.pack(">II", position, len(payload)))
            dict_file.write(payload)
            position += len(payload)
            count += 1

            if count % 250_000 == 0:
                print(f"converted {count:,} entries", file=sys.stderr)

        idx_size = idx_file.tell()

    if expected_count is not None and count != expected_count:
        raise ValueError(f"expected {expected_count} entries, converted {count}")

    ifo = "\n".join(
        (
            "StarDict's dict ifo file",
            "version=2.4.2",
            f"wordcount={count}",
            f"idxfilesize={idx_size}",
            f"bookname={BOOK_NAME}",
            "author=Linwei / ECDICT contributors",
            "website=https://github.com/skywind3000/ECDICT",
            "description=ECDICT English-Chinese dictionary with inflections and derived forms; MIT License",
            "date=2025.01.02",
            "sametypesequence=m",
            "lang=en-zh",
            "",
        )
    )
    base.with_suffix(".ifo").write_text(ifo, encoding="utf-8")
    print(f"generated {count:,} entries in {output_dir}")
    return count


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="extracted ECDICT stardict.csv")
    parser.add_argument("output_dir", type=Path, help="new dictionary directory")
    parser.add_argument("--expected-count", type=int, default=None)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        convert(args.source, args.output_dir, args.expected_count)
    except (OSError, UnicodeError, csv.Error, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
