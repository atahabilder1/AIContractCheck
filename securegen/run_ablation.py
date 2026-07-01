"""Paired repair ablation: repair the exact S0 baseline contracts."""
import os
os.environ["OLLAMA_HOST"] = "http://localhost:11434"
from securegen.eval.runner import run, load_prompts
from securegen.eval.compare import compare, print_report

IDS = [0, 16, 32, 48, 75, 91, 123, 139]
BK = "gemini"
prompts = load_prompts(ids=IDS)
seed_path = f"securegen/results/s0_baseline__{BK}.json"
print(f"=== Paired ablation: S0 vs S2b (repair-from-seed), backend={BK} ===")
p2b = run("s2b_repair_from_seed", BK, prompts, seeds_from=seed_path)
print("\n" + "="*60)
rep = compare(f"securegen/results/s0_baseline__{BK}.json", str(p2b))
print_report(rep)
