"""
Use Claude as a security auditor on human baseline contracts.
Sends each contract to Claude with a professional audit prompt and collects
structured vulnerability findings.
"""

import json
import os
import time
from pathlib import Path

from dotenv import load_dotenv
load_dotenv()

import anthropic


AUDIT_PROMPT_TEMPLATE = """You are a senior smart contract security auditor performing a professional audit.
Analyze the following Solidity contract for security vulnerabilities.

For each vulnerability you find, report it in this exact JSON format:
{{"vulnerabilities": [{{"severity": "High|Medium|Low", "type": "short name (e.g., Reentrancy, Access Control, Unchecked Return)", "cwe": "CWE-XXX", "line": 0, "description": "1-2 sentence explanation of the issue and how it could be exploited"}}], "summary": "1-2 sentence overall assessment", "total_issues": 0}}

Rules:
- Only report REAL security issues that could lead to fund loss, unauthorized access, or denial of service
- Do NOT flag gas optimizations, code style, or informational findings
- Do NOT flag standard patterns from OpenZeppelin or well-known libraries as vulnerable
- Be conservative: if you are not sure, do not flag it
- Return ONLY valid JSON, no markdown, no explanation outside the JSON

Contract:
```solidity
{code}
```"""


def audit_contract(client, code: str, model: str = "claude-sonnet-4-20250514") -> dict:
    """Send a contract to Claude for security audit."""
    prompt = AUDIT_PROMPT_TEMPLATE.replace("{code}", code)
    message = client.messages.create(
        model=model,
        max_tokens=4096,
        messages=[
            {"role": "user", "content": prompt}
        ],
    )
    response_text = message.content[0].text.strip()

    # Try to parse JSON from response
    try:
        # Handle case where Claude wraps in markdown
        if response_text.startswith("```"):
            lines = response_text.split("\n")
            lines = [l for l in lines if not l.startswith("```")]
            response_text = "\n".join(lines)
        return json.loads(response_text)
    except json.JSONDecodeError:
        # Try to find JSON in the response
        start = response_text.find("{")
        end = response_text.rfind("}") + 1
        if start != -1 and end > start:
            try:
                return json.loads(response_text[start:end])
            except json.JSONDecodeError:
                pass
        return {"error": "Failed to parse response", "raw": response_text[:500]}


def run_claude_audit(
    baseline_dir: str = "dataset/human_baseline_forge",
    output_file: str = "analysis/human_baseline_results/claude_audit_results.json",
    model: str = "claude-sonnet-4-20250514",
    max_lines: int = 8000,
):
    """Run Claude audit on all human baseline contracts."""
    api_key = os.getenv("ANTHROPIC_API_KEY")
    if not api_key:
        raise ValueError(
            "ANTHROPIC_API_KEY not set. Run: export ANTHROPIC_API_KEY='your-key'"
        )

    client = anthropic.Anthropic(api_key=api_key)
    baseline_path = Path(baseline_dir)
    output_path = Path(output_file)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Load existing results to allow resuming
    existing = {}
    if output_path.exists():
        with open(output_path) as f:
            for entry in json.load(f):
                existing[entry["file"]] = entry
        print(f"Loaded {len(existing)} existing results (will skip)")

    sol_files = sorted(baseline_path.rglob("*.sol"))
    print(f"Found {len(sol_files)} contracts")

    results = list(existing.values())
    processed = 0
    skipped = 0
    errors = 0

    for i, sol_file in enumerate(sol_files):
        filepath = str(sol_file)

        # Skip if already done
        if filepath in existing:
            continue

        # Read contract
        code = sol_file.read_text()
        lines = len(code.split("\n"))

        # Skip very large contracts
        if lines > max_lines:
            print(f"  [{i+1}/{len(sol_files)}] SKIP (too large: {lines} lines): {sol_file.name}")
            results.append({
                "file": filepath,
                "category": sol_file.parent.name,
                "filename": sol_file.name,
                "lines": lines,
                "skipped": True,
                "reason": f"Too large ({lines} lines)",
                "audit": None,
            })
            skipped += 1
            continue

        print(f"  [{i+1}/{len(sol_files)}] Auditing ({lines} lines): {sol_file.name}")

        try:
            audit = audit_contract(client, code, model=model)
            vuln_count = audit.get("total_issues", len(audit.get("vulnerabilities", [])))
            print(f"    → {vuln_count} issues found")
            processed += 1
        except Exception as e:
            print(f"    → ERROR: {e}")
            audit = {"error": str(e)}
            errors += 1

        results.append({
            "file": filepath,
            "category": sol_file.parent.name,
            "filename": sol_file.name,
            "lines": lines,
            "skipped": False,
            "audit": audit,
        })

        # Save after each contract (resume-friendly)
        with open(output_path, "w") as f:
            json.dump(results, f, indent=2)

        # Rate limiting
        time.sleep(1.0)

    # Final summary
    print(f"\n{'='*60}")
    print("CLAUDE AUDIT SUMMARY")
    print(f"{'='*60}")
    print(f"Total contracts: {len(sol_files)}")
    print(f"Audited: {processed}")
    print(f"Skipped (too large): {skipped}")
    print(f"Errors: {errors}")
    print(f"Previously done: {len(existing)}")

    # Count total vulnerabilities found
    total_vulns = 0
    contracts_with_vulns = 0
    severity_counts = {"High": 0, "Medium": 0, "Low": 0}
    for r in results:
        if r.get("skipped") or not r.get("audit"):
            continue
        audit = r["audit"]
        if "error" in audit:
            continue
        vulns = audit.get("vulnerabilities", [])
        if vulns:
            contracts_with_vulns += 1
            total_vulns += len(vulns)
            for v in vulns:
                sev = v.get("severity", "Low")
                if sev in severity_counts:
                    severity_counts[sev] += 1

    audited_total = processed + len(existing)
    print(f"\nAudited contracts with vulns: {contracts_with_vulns}/{audited_total} "
          f"({contracts_with_vulns/max(audited_total,1)*100:.1f}%)")
    print(f"Total vulnerabilities: {total_vulns}")
    print(f"  High: {severity_counts['High']}")
    print(f"  Medium: {severity_counts['Medium']}")
    print(f"  Low: {severity_counts['Low']}")
    print(f"\nResults saved to: {output_path}")

    return results


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Run Claude security audit on human baseline")
    parser.add_argument("--model", default="claude-sonnet-4-20250514",
                        help="Claude model to use")
    parser.add_argument("--max-lines", type=int, default=8000,
                        help="Skip contracts larger than this")
    args = parser.parse_args()

    run_claude_audit(model=args.model, max_lines=args.max_lines)
