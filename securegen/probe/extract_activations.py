"""
Build the probe's training set: (hidden-state activation, vuln-label) pairs.

Teacher signal comes for free from work you already did: the 2,400-contract
corpus in dataset/<llm>/ already has Slither/Semgrep labels in
analysis/results/all_vulnerabilities.json. We re-feed each contract through the
open model, capture the residual-stream activation at the END of each source
LINE (the line's final token), and label that line by whether any tool flagged
a finding on it.

QUICK-CORPUS MODE (this file): we probe the open model's own corpus contracts
(default --llm qwen) that COMPILED, so the Slither line labels are real. This
answers "is vulnerability linearly decodable from layer L?" with a mild
train/inference distribution mismatch (we re-feed finished code rather than the
model's own left-context-only generation state). The self-generation variant
that removes that mismatch is a separate, heavier step.

Output: securegen/probe/activations.pt  (a dict of tensors + contract ids)

Run:
    python -m securegen.probe.extract_activations \
        --model Qwen/Qwen2.5-Coder-7B-Instruct --layer 18 --llm qwen

This is the data-prep half of the S4 contribution. It is deliberately separate
from training so you can cache activations once and sweep probe architectures.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
from pathlib import Path

# torch/transformers imported inside main() so the module is import-safe.

AGG = Path("analysis/results/aggregated_results.csv")
VULNS = Path("analysis/results/all_vulnerabilities.json")

# Line numbers are NOT stored in a `line` field. They live inside dedup_key,
# e.g. "slither:events-access:dataset/qwen/.../171_simplicity.sol#L16-L18".
_LINE_RE = re.compile(r"#L(\d+)(?:-L(\d+))?")


def _build_line_index() -> dict[str, set[int]]:
    """Map filepath -> set of 1-indexed lines flagged by any tool.

    Parses the `#L<start>-L<end>` range out of each finding's dedup_key and
    expands it to the full inclusive line set.
    """
    index: dict[str, set[int]] = {}
    if not VULNS.exists():
        return index
    data = json.loads(VULNS.read_text())
    records = data if isinstance(data, list) else data.get("vulnerabilities", [])
    for v in records:
        fp = v.get("filepath") or v.get("file")
        key = v.get("dedup_key", "")
        m = _LINE_RE.search(key)
        if not fp or not m:
            continue
        start = int(m.group(1))
        end = int(m.group(2)) if m.group(2) else start
        if end < start:
            start, end = end, start
        index.setdefault(fp, set()).update(range(start, end + 1))
    return index


def _line_starts(code: str) -> list[int]:
    """Char offset at which each 1-indexed line begins. starts[1] == 0."""
    starts = [0, 0]  # index 0 unused; line 1 starts at char 0
    for i, ch in enumerate(code):
        if ch == "\n":
            starts.append(i + 1)
    return starts


def _char_to_line(char_idx: int, starts: list[int]) -> int:
    """Binary search: which 1-indexed line does this char offset fall on."""
    lo, hi = 1, len(starts) - 1
    while lo < hi:
        mid = (lo + hi + 1) // 2
        if starts[mid] <= char_idx:
            lo = mid
        else:
            hi = mid - 1
    return lo


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="Qwen/Qwen2.5-Coder-7B-Instruct")
    ap.add_argument("--layer", type=int, default=18,
                    help="residual-stream layer to probe")
    ap.add_argument("--llm", default="qwen",
                    help="restrict to this corpus (its own model = less mismatch)")
    ap.add_argument("--limit", type=int, default=0,
                    help="max contracts (0 = all matching)")
    ap.add_argument("--max-length", type=int, default=4096)
    ap.add_argument("--out", default="securegen/probe/activations.pt")
    args = ap.parse_args()

    import torch
    from transformers import AutoModelForCausalLM, AutoTokenizer

    line_index = _build_line_index()

    tok = AutoTokenizer.from_pretrained(args.model)
    if not tok.is_fast:
        raise SystemExit("Need a fast tokenizer for offset_mapping.")
    model = AutoModelForCausalLM.from_pretrained(
        args.model, torch_dtype=torch.float16, device_map="auto",
        output_hidden_states=True)
    model.eval()

    with open(AGG) as f:
        rows = list(csv.DictReader(f))
    # Only compiled contracts from the target corpus: those have real Slither
    # line labels (uncompiled -> Slither never ran -> labels are unknowable).
    rows = [r for r in rows
            if r["llm"] == args.llm
            and str(r.get("compiled", "")).lower() in ("true", "1")]
    if args.limit:
        rows = rows[: args.limit]
    print(f"{len(rows)} compiled {args.llm} contracts to probe")

    feats, labels, contract_ids = [], [], []
    for cid, row in enumerate(rows):
        fp = row["filepath"]
        if not Path(fp).exists():
            continue
        code = Path(fp).read_text()
        flagged = line_index.get(fp, set())
        starts = _line_starts(code)

        enc = tok(code, return_tensors="pt", return_offsets_mapping=True,
                  truncation=True, max_length=args.max_length)
        offsets = enc.pop("offset_mapping")[0]  # [seq, 2]
        with torch.no_grad():
            out = model(**{k: v.to(model.device) for k, v in enc.items()})
        hs = out.hidden_states[args.layer][0]  # [seq, hidden]

        # Take ONE activation per source line: the last token on that line.
        # (final-token-of-line = left-context-only state, matches inference.)
        last_tok_of_line: dict[int, int] = {}
        for t_idx in range(hs.shape[0]):
            start_char = int(offsets[t_idx][0])
            end_char = int(offsets[t_idx][1])
            if end_char == 0 and start_char == 0:
                continue  # special token, no source span
            line = _char_to_line(start_char, starts)
            last_tok_of_line[line] = t_idx  # later tokens overwrite -> "last"

        for line, t_idx in last_tok_of_line.items():
            feats.append(hs[t_idx].float().cpu())
            labels.append(1 if line in flagged else 0)
            contract_ids.append(cid)

        if (cid + 1) % 25 == 0:
            print(f"  {cid+1}/{len(rows)} contracts, {len(feats)} line-samples")

    X = torch.stack(feats)
    y = torch.tensor(labels, dtype=torch.float32)
    groups = torch.tensor(contract_ids, dtype=torch.long)
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    torch.save({"X": X, "y": y, "groups": groups, "layer": args.layer,
                "model": args.model, "llm": args.llm}, args.out)
    print(f"Saved {X.shape[0]} line-samples ({y.mean():.3f} positive) "
          f"from {int(groups.max())+1} contracts -> {args.out}")


if __name__ == "__main__":
    main()
