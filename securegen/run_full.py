"""
Full paired-ablation run: S0 baseline -> S2b repair-from-seed on the same
contracts, then the paired comparison.

Usage:
    python -u -m securegen.run_full --backend qwen7b --n 100
    python -u -m securegen.run_full --backend qwen7b --ids 0 16 32 ...

Runs entirely locally (Ollama) by default — free, no rate limits. Resumable:
re-running picks up where it left off via the per-strategy results files.
"""

import argparse
import os

os.environ.setdefault("OLLAMA_HOST", "http://localhost:11434")

from securegen.eval.runner import run, load_prompts
from securegen.eval.compare import compare, print_report


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--backend", default="qwen7b")
    ap.add_argument("--n", type=int, default=100, help="first N prompts")
    ap.add_argument("--ids", type=int, nargs="*", help="explicit prompt ids")
    ap.add_argument("--max-iters", type=int, default=3)
    args = ap.parse_args()

    prompts = load_prompts(ids=args.ids, limit=None if args.ids else args.n)
    bk = args.backend
    print(f"=== Full paired ablation: {len(prompts)} prompts, backend={bk} ===")

    print("\n>>> Phase 1: S0 baseline")
    p0 = run("s0_baseline", bk, prompts)

    print("\n>>> Phase 2: S2b repair-from-seed (paired)")
    p2b = run("s2b_repair_from_seed", bk, prompts, seeds_from=str(p0))

    print("\n" + "=" * 60)
    rep = compare(str(p0), str(p2b))
    print_report(rep)
    print("\nDone. Result files in securegen/results/")


if __name__ == "__main__":
    main()
