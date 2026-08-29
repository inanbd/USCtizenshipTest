#!/usr/bin/env python3
"""Export the Flutter question/state datasets to JSON for the backend seeder.

The Flutter app's Dart data files are the single source of truth for the
official USCIS content. This script parses them so the backend never
hand-transcribes the questions (which is how data drifts).

Usage: python3 export_seed_data.py <repo_root> <output_dir>
"""
import json
import re
import sys
from pathlib import Path


def dart_string(raw: str) -> str:
    """Turn a Dart string literal into its value."""
    raw = raw.strip()
    if raw.startswith("'''") or raw.startswith('"""'):
        quote, body = raw[:3], raw[3:-3]
    else:
        quote, body = raw[0], raw[1:-1]
    # Dart escapes we actually use in the data files.
    body = body.replace("\\'", "'").replace('\\"', '"').replace("\\\\", "\\")
    body = body.replace("\\n", "\n").replace("\\$", "$")
    return body


def join_adjacent(raw: str) -> str:
    """Dart concatenates adjacent string literals across lines."""
    parts = re.findall(r"'(?:[^'\\]|\\.)*'|\"(?:[^\"\\]|\\.)*\"", raw, re.S)
    return "".join(dart_string(p) for p in parts) if parts else ""


def parse_questions(path: Path, version: str):
    text = path.read_text()
    # Drop comment-only lines; the datasets annotate individual revisions with
    # them and they would otherwise break the field-matching below.
    text = "\n".join(
        ln for ln in text.split("\n") if not re.match(r"^\s*//", ln)
    )
    body = text[text.index("= ["):]
    blocks = re.findall(r"Question\((.*?)\n  \),", body, re.S)
    out = []
    for b in blocks:
        qid = int(re.search(r"\bid:\s*(\d+)", b).group(1))
        category = re.search(r"category:\s*QuestionCategory\.(\w+)", b).group(1)
        section = join_adjacent(re.search(r"section:\s*(.*?),\n", b, re.S).group(1))
        prompt = join_adjacent(
            re.search(r"prompt:\s*(.*?),\n\s*(?:answers|kind|senior|requiredCount|note):", b, re.S).group(1)
        )
        answers_raw = re.search(r"answers:\s*\[(.*?)\n\s*\],", b, re.S)
        if answers_raw:
            answers = [dart_string(m) for m in re.findall(
                r"'(?:[^'\\]|\\.)*'|\"(?:[^\"\\]|\\.)*\"", answers_raw.group(1), re.S)]
        else:
            single = re.search(r"answers:\s*\[([^\]]*)\]", b, re.S)
            answers = [dart_string(m) for m in re.findall(
                r"'(?:[^'\\]|\\.)*'|\"(?:[^\"\\]|\\.)*\"", single.group(1), re.S)]
        kind_m = re.search(r"kind:\s*AnswerKind\.(\w+)", b)
        note_m = re.search(
            r"note:\s*((?:'(?:[^'\\\\]|\\\\.)*'|\"(?:[^\"\\\\]|\\\\.)*\"|\s)+)", b, re.S)
        req_m = re.search(r"requiredCount:\s*(\d+)", b)
        out.append({
            "id": qid,
            "version": version,
            "category": category,
            "section": section,
            "prompt": prompt,
            "answers": answers,
            "kind": kind_m.group(1) if kind_m else "fixed",
            "senior": "senior: true" in b,
            "requiredCount": int(req_m.group(1)) if req_m else 1,
            "note": join_adjacent(note_m.group(1)) if note_m else None,
        })
    return out


def parse_states(path: Path):
    text = path.read_text()
    out = []
    for m in re.finditer(
        r"StateInfo\(\s*code:\s*'([A-Z]{2})',\s*name:\s*'([^']*)',\s*capital:\s*'([^']*)'", text
    ):
        out.append({"code": m.group(1), "name": m.group(2), "capital": m.group(3)})
    return out


def main():
    root = Path(sys.argv[1])
    outdir = Path(sys.argv[2])
    outdir.mkdir(parents=True, exist_ok=True)

    q2008 = parse_questions(root / "lib/data/questions_2008.dart", "V2008")
    q2020 = parse_questions(root / "lib/data/questions_2020.dart", "V2020")
    q2025 = parse_questions(root / "lib/data/questions_2025.dart", "V2025")
    states = parse_states(root / "lib/data/state_data.dart")

    assert len(q2008) == 100, f"expected 100 questions for 2008, got {len(q2008)}"
    assert len(q2020) == 128, f"expected 128 questions for 2020, got {len(q2020)}"
    assert len(q2025) == 128, f"expected 128 questions for 2025, got {len(q2025)}"
    assert len(states) == 51, f"expected 51 states, got {len(states)}"
    for qs, name in ((q2008, "2008"), (q2020, "2020"), (q2025, "2025")):
        seniors = [q for q in qs if q["senior"]]
        assert len(seniors) == 20, f"{name}: expected 20 senior questions, got {len(seniors)}"
        for q in qs:
            assert q["prompt"], f"{name} Q{q['id']} has no prompt"
            assert q["answers"], f"{name} Q{q['id']} has no answers"
            if q["kind"] != "fixed":
                assert q["note"], f"{name} Q{q['id']} is dynamic but has no guidance note"

    # Spot-check the 2025 revisions so a bad regeneration cannot pass silently.
    by_number = {q["id"]: q for q in q2025}
    assert "Juneteenth" in by_number[126]["answers"], "2025 Q126 is missing Juneteenth"
    assert any("Secretary of War" in a for a in by_number[48]["answers"]), \
        "2025 Q48 is missing Secretary of War (Defense)"
    assert "born or naturalized" in by_number[97]["prompt"], \
        "2025 Q97 is not the revised wording"

    (outdir / "questions.json").write_text(
        json.dumps(q2008 + q2020 + q2025, indent=2, ensure_ascii=False) + "\n")
    (outdir / "states.json").write_text(
        json.dumps(states, indent=2, ensure_ascii=False) + "\n")
    print(f"wrote {len(q2008) + len(q2020) + len(q2025)} questions "
          f"and {len(states)} states to {outdir}")


if __name__ == "__main__":
    main()
