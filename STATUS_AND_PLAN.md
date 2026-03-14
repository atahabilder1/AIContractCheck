# AIContractCheck — Status & Plan

## What's Done

### 1. Dataset Generation — COMPLETE
- **1,800 contracts** generated across 6 LLMs (300 each)
- All stored in `dataset/<llm>/<type>/<category>/*.sol`

| LLM | Contracts | Method |
|-----|-----------|--------|
| GPT-4o | 300 | OpenAI API |
| Claude 3.5 Sonnet | 300 | Claude CLI |
| Gemini 2.5 Flash-Lite | 300 | Google AI Studio API (paid tier) |
| DeepSeek Coder V2 | 300 | Ollama (A6000) |
| Qwen 2.5 Coder 32B | 300 | Ollama (A6000) |
| CodeLlama-34B | 300 | Ollama (A6000) |

### 2. Vulnerability Analysis — PARTIALLY COMPLETE

| Tool | Status | Contracts | Successful | Vulns Found |
|------|--------|-----------|-----------|-------------|
| Slither | DONE | 1800/1800 | 1181 (65.6%) | 3,753 |
| Semgrep | DONE | 1800/1800 | 1800 (100%) | 1,626 |
| Mythril | NOT RUN | — | — | — |

**Combined (deduplicated): 4,749 vulnerabilities across 1,029 contracts (57.2%)**

### 3. Aggregation — DONE
- `analysis/results/aggregated_results.csv` — per-contract data
- `analysis/results/all_vulnerabilities.json` — all findings

### 4. Statistical Analysis — DONE
- `analysis/results/statistical_results.json`
- All tests run: Kruskal-Wallis, Mann-Whitney U, Chi-square, Cliff's delta, bootstrap CIs

### 5. Figures — DONE (7 PDFs in `visualization/figures/`)

### 6. Paper — NEEDS UPDATE (still has `\demo{}` placeholder values)

---

## Key Findings So Far

### Compilation Rates (Slither success = compiled with solc)
| LLM | Compiled | Rate |
|-----|----------|------|
| GPT-4o | 270/300 | 90.0% |
| Qwen | 237/300 | 79.0% |
| Claude | 216/300 | 72.0% |
| DeepSeek | 205/300 | 68.3% |
| Gemini | 149/300 | 49.7% |
| CodeLlama | 104/300 | 34.7% |

### Vulnerability Summary
- **57.2%** of all contracts have at least one vulnerability
- **18.1%** have high-severity vulnerabilities
- **4,749 total deduplicated vulnerabilities**
- Mean vulns/contract: 2.64

### Per-LLM Vulnerability Rates
| LLM | Mean Vulns | Median | High-Sev Rate |
|-----|-----------|--------|---------------|
| Claude | 5.71 | 4.0 | 23.3% |
| GPT-4o | 2.73 | 2.0 | 24.7% |
| Gemini | 2.50 | 0.5 | 14.7% |
| Qwen | 2.22 | 1.0 | 21.7% |
| DeepSeek | 2.09 | 1.0 | 21.3% |
| CodeLlama | 0.58 | 0.0 | 3.0% |

### Statistical Significance
- Cross-LLM differences: **Kruskal-Wallis H=229.8, p<0.001** (highly significant)
- Largest effect: Claude vs CodeLlama, Cliff's δ=0.588 (large)
- GPT-4o vs CodeLlama: Cliff's δ=0.512 (large)

### Adversarial vs Standard Prompts
- **No significant overall difference** (Mann-Whitney U, p=0.99, Cliff's δ=-0.064)
- Standard: median=1.0, mean=3.07
- Adversarial: median=1.0, mean=2.42
- This is a **surprising null result** — adversarial prompts did NOT increase vulnerabilities

---

## What Remains

### Option A: Run Mythril (adds ~60-150 hours)
```bash
# In tmux:
cd /home/anik/code/AIContractCheck
nohup python3 -m analysis.run_mythril > /tmp/mythril_run.log 2>&1 &
# Then re-aggregate:
python3 -m analysis.aggregate_results
python3 -m analysis.statistical_analysis
python3 -m visualization.generate_figures
```
**Pros:** 3-tool coverage matches paper claims, catches deep logic bugs
**Cons:** Very slow (5 min/contract × 1800 = 150 hours), may not change findings much

### Option B: Skip Mythril, Update Paper with 2-Tool Results
- Change paper to say "Slither + Semgrep" (2 tools)
- Update all `\demo{}` values with real numbers
- Still a strong paper — most related work uses only Slither

### Option C: Run Mythril on Subset Only
```bash
# Run on high-severity contracts only (~326 contracts, ~27 hours)
python3 -m analysis.run_mythril --dataset dataset --subset high_severity
```

---

## Commands to Run Everything from Scratch (tmux)

```bash
# Terminal 1: Full pipeline (without Mythril)
cd /home/anik/code/AIContractCheck
python3 run_analysis.py --skip-mythril 2>&1 | tee /tmp/full_pipeline.log

# Terminal 2: Mythril only (if desired, very slow)
cd /home/anik/code/AIContractCheck
python3 -m analysis.run_mythril 2>&1 | tee /tmp/mythril_run.log

# After Mythril finishes, re-aggregate:
python3 -m analysis.aggregate_results
python3 -m analysis.statistical_analysis
python3 -m visualization.generate_figures
```

---

## Publishability Assessment

See detailed assessment below in the document.
