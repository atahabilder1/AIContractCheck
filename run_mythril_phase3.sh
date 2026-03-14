#!/bin/bash
# Phase 3: Run Mythril on 499-contract stratified sample
# Estimated: 25-42 hours at 180s timeout
# Logs to /tmp/mythril_phase3.log with periodic status checks

cd /home/anik/code/AIContractCheck

echo "========================================" | tee /tmp/mythril_phase3.log
echo "MYTHRIL PHASE 3 - Started: $(date)" | tee -a /tmp/mythril_phase3.log
echo "Sample: 499 compiled contracts" | tee -a /tmp/mythril_phase3.log
echo "Timeout: 180s per contract" | tee -a /tmp/mythril_phase3.log
echo "========================================" | tee -a /tmp/mythril_phase3.log

python3 -m analysis.run_mythril \
    --timeout 180 \
    --sample analysis/results/mythril_sample.txt \
    --output analysis/results/mythril_results.json \
    2>&1 | tee -a /tmp/mythril_phase3.log

echo "" | tee -a /tmp/mythril_phase3.log
echo "========================================" | tee -a /tmp/mythril_phase3.log
echo "MYTHRIL PHASE 3 - Finished: $(date)" | tee -a /tmp/mythril_phase3.log
echo "========================================" | tee -a /tmp/mythril_phase3.log

# After Mythril finishes, re-aggregate
echo "Re-aggregating results..." | tee -a /tmp/mythril_phase3.log
python3 -m analysis.aggregate_results 2>&1 | tee -a /tmp/mythril_phase3.log
python3 -m analysis.add_compilation_status 2>&1 | tee -a /tmp/mythril_phase3.log
python3 -m analysis.statistical_analysis 2>&1 | tee -a /tmp/mythril_phase3.log
python3 -m visualization.generate_figures 2>&1 | tee -a /tmp/mythril_phase3.log

echo "ALL DONE: $(date)" | tee -a /tmp/mythril_phase3.log
