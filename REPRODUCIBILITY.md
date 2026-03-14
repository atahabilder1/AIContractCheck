# Reproducibility Guide

## Environment

| Component | Version |
|-----------|---------|
| Python | 3.10.12 |
| Node.js | 20.20.1 |
| solc | 0.8.20 |
| OS | Ubuntu 22.04 (Linux 5.15.0) |
| GPU | NVIDIA RTX 3090 (24GB) — used for local LLMs |
| GPU (remote) | NVIDIA A6000 (48GB) — Ollama for CodeLlama/DeepSeek/Qwen |

## Security Analysis Tools

| Tool | Version | Purpose |
|------|---------|---------|
| Slither | 0.11.5 | Static analysis (90+ detectors) |
| Mythril | 0.24.8 | Symbolic execution (deep logic bugs) |
| Semgrep | 1.154.0 | Pattern matching (custom Solidity rules) |

## LLM Configurations

| Model | Provider | Access Method | Temperature | Max Tokens |
|-------|----------|---------------|-------------|------------|
| GPT-4o | OpenAI | API (`openai==2.24.0`) | 0.7 | 4,000 |
| Claude 3.5 Sonnet | Anthropic | CLI (`anthropic==0.84.0`) | 0.7 | 4,000 |
| Gemini 2.5 Flash-Lite | Google | API (`google-generativeai==0.8.6`) | 0.7 | 4,000 |
| DeepSeek Coder V2 | DeepSeek | Ollama (local) | 0.7 | 4,000 |
| Qwen 2.5 Coder 32B | Alibaba | Ollama (local) | 0.7 | 4,000 |
| CodeLlama-34B | Meta | Ollama (local) | 0.7 | 4,000 |

## Setup

```bash
# 1. Clone repository
git clone https://github.com/[repo-url]
cd AIContractCheck

# 2. Install Python dependencies
pip install -r requirements.txt

# 3. Install Solidity compiler
solc-select install 0.8.20
solc-select use 0.8.20

# 4. Install OpenZeppelin contracts (needed for some contracts)
npm install

# 5. Install Semgrep rules
# Custom rules are in analysis/semgrep_rules/

# 6. Set up API keys (for dataset generation only)
cp .env.example .env
# Edit .env with your API keys
```

## Reproducing Results

### Step 1: Dataset Generation (requires API keys)
```bash
python3 generate_dataset.py
# Generates 1,800 contracts in dataset/<llm>/<type>/<category>/
```

### Step 2: Run Analysis Pipeline
```bash
# Run Slither + Semgrep (fast, ~30 min)
python3 run_analysis.py --skip-mythril

# Run Mythril on stratified sample (~3-6 hours)
python3 -m analysis.mythril_sample
python3 -m analysis.run_mythril --timeout 180 --sample analysis/results/mythril_sample.txt
```

### Step 3: Aggregate and Analyze
```bash
# Aggregate results from all tools
python3 -m analysis.aggregate_results

# Add compilation status and LOC metrics
python3 -m analysis.add_compilation_status

# Run statistical tests
python3 -m analysis.statistical_analysis

# Generate figures
python3 -m visualization.generate_figures
```

### Step 4: Deep Analysis
```bash
# Adversarial prompt analysis
python3 -m analysis.adversarial_deep_analysis

# LLM-specific pattern verification
python3 -m analysis.verify_patterns
```

## Output Files

| File | Description |
|------|-------------|
| `analysis/results/aggregated_results.csv` | Per-contract data (1,800 rows) with vulns, LOC, compilation status |
| `analysis/results/statistical_results.json` | All statistical test results |
| `analysis/results/adversarial_deep_analysis.json` | Adversarial prompt deep-dive |
| `analysis/results/pattern_verification.json` | LLM-specific pattern detection |
| `analysis/results/slither_results.json` | Raw Slither output |
| `analysis/results/mythril_results.json` | Raw Mythril output (499 sample) |
| `analysis/results/semgrep_results.json` | Raw Semgrep output |
| `visualization/figures/*.pdf` | Publication-ready figures |

## Dataset Structure

```
dataset/
├── claude/           # 300 contracts
├── codellama/        # 300 contracts
├── deepseek/         # 300 contracts
├── gemini/           # 300 contracts
├── gpt4o/            # 300 contracts
└── qwen/             # 300 contracts
    ├── standard/     # 100 standard prompts
    │   └── <category>/
    │       └── *.sol
    └── adversarial/  # 200 adversarial prompts
        └── <category>/
            └── *.sol
```

## Key Statistics (for verification)

- Total contracts: 1,800
- Compiled: 1,181 (65.6%)
- Total vulnerabilities (deduped): 5,007 (all), 4,496 (compiled-only)
- Contracts with vulns (compiled): 858 (72.7%)
- Contracts with high-severity (compiled): 337 (28.5%)
- Kruskal-Wallis (compiled): H=138.8, p<10^-28
- Adversarial effect (compiled): standard mean=5.02 > adversarial mean=3.39, p<0.001
