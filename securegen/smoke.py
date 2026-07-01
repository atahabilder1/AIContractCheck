"""Smoke test: run S0 baseline vs S2 repair loop on a diverse prompt set,
then print the paired comparison.

Usage: python -u -m securegen.smoke [backend]   (default codestral, local+free)
"""

import os
import sys
os.environ["OLLAMA_HOST"] = "http://localhost:11434"

from securegen.eval.runner import run, load_prompts
from securegen.eval.compare import compare, print_report

IDS = [0, 16, 32, 48, 75, 91, 123, 139]  # ERC20, NFT, 1155, staking, DEX, yield, gov, multisig
BACKEND = sys.argv[1] if len(sys.argv) > 1 else "codestral"

prompts = load_prompts(ids=IDS)
print(f"=== Smoke: {len(prompts)} prompts, backend={BACKEND} ===\n")

print(">>> S0 baseline")
p0 = run("s0_baseline", BACKEND, prompts)

print("\n>>> S2 repair loop")
p2 = run("s2_repair_loop", BACKEND, prompts)

print("\n" + "=" * 60)
rep = compare(str(p0), str(p2))
print_report(rep)
