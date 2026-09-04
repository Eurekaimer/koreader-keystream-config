from __future__ import annotations

import csv
import importlib.util
import struct
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = REPO_ROOT / "scripts/ecdict_to_stardict.py"
SPEC = importlib.util.spec_from_file_location("ecdict_to_stardict", MODULE_PATH)
assert SPEC and SPEC.loader
converter = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(converter)

FIELDNAMES = (
    "word",
    "phonetic",
    "definition",
    "translation",
    "pos",
    "collins",
    "oxford",
    "tag",
    "bnc",
    "frq",
    "exchange",
    "detail",
    "audio",
)


def write_fixture(path: Path, rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=FIELDNAMES)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def read_index(path: Path) -> list[tuple[str, int, int]]:
    entries: list[tuple[str, int, int]] = []
    data = path.read_bytes()
    position = 0
    while position < len(data):
        terminator = data.index(b"\0", position)
        word = data[position:terminator].decode("utf-8")
        offset, size = struct.unpack(">II", data[terminator + 1:terminator + 9])
        entries.append((word, offset, size))
        position = terminator + 9
    return entries


class ECDICTConversionTests(unittest.TestCase):
    def test_conversion_preserves_lookup_payload_and_word_order(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "stardict.csv"
            output = root / "dictionary"
            write_fixture(
                source,
                [
                    {
                        "word": "computational",
                        "phonetic": "kɒmpjʊˈteɪʃənəl",
                        "definition": "of or involving computation",
                        "translation": "a. 计算的",
                    },
                    {
                        "word": "running",
                        "translation": "v. 跑；运行",
                        "exchange": "0:run/1:i",
                    },
                ],
            )

            self.assertEqual(converter.convert(source, output, expected_count=2), 2)
            entries = read_index(output / "ecdict-en-zh.idx")
            self.assertEqual([entry[0] for entry in entries], ["computational", "running"])

            dictionary = (output / "ecdict-en-zh.dict").read_bytes()
            first_word, first_offset, first_size = entries[0]
            self.assertEqual(first_word, "computational")
            first_definition = dictionary[first_offset:first_offset + first_size].decode("utf-8")
            self.assertIn("中文释义：\na. 计算的", first_definition)
            self.assertIn("英文释义：\nof or involving computation", first_definition)

            _, second_offset, second_size = entries[1]
            second_definition = dictionary[second_offset:second_offset + second_size].decode("utf-8")
            self.assertIn("原形：run", second_definition)
            self.assertIn("词形类型：i", second_definition)
            self.assertIn("wordcount=2", (output / "ecdict-en-zh.ifo").read_text(encoding="utf-8"))

    def test_unsorted_source_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "stardict.csv"
            write_fixture(source, [{"word": "running"}, {"word": "computational"}])

            with self.assertRaisesRegex(ValueError, "sorted case-insensitively"):
                converter.convert(source, root / "dictionary")


if __name__ == "__main__":
    unittest.main()
