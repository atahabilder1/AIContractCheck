"""
Re-download human baseline contracts and properly flatten using forge flatten.
This handles multi-file contracts by writing each source file to its proper path,
then using Foundry's forge flatten to produce a single compilable file.
"""

import json
import os
import re
import subprocess
import tempfile
import time
import urllib.request
import urllib.parse
import shutil
from pathlib import Path
from datetime import datetime

from dotenv import load_dotenv

load_dotenv()

API_KEY = os.getenv("ETHERSCAN_API_KEY")
BASE_URL = "https://api.etherscan.io/v2/api"
INPUT_DIR = Path("dataset/human_baseline")
OUTPUT_DIR = Path("dataset/human_baseline_forge")
FORGE_BIN = os.path.expanduser("~/.foundry/bin/forge")
RATE_LIMIT = 0.25


def etherscan_get_source(address):
    """Fetch contract source from Etherscan."""
    params = {
        "chainid": 1,
        "module": "contract",
        "action": "getsourcecode",
        "address": address,
        "apikey": API_KEY,
    }
    url = f"{BASE_URL}?{urllib.parse.urlencode(params)}"

    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=30) as resp:
                data = json.loads(resp.read().decode())
            if data.get("status") == "1":
                return data["result"][0]
            if "rate limit" in str(data.get("result", "")).lower():
                time.sleep(5)
                continue
        except Exception as e:
            print(f"  API error: {e}")
            time.sleep(2)
    return None


def flatten_with_forge(source_code, contract_name, compiler_version):
    """
    Properly flatten a contract using forge flatten.
    For multi-file contracts, writes each file to correct path then flattens.
    For single-file contracts, returns as-is.
    """
    # Single file — already flat
    if not source_code.startswith("{"):
        return source_code.strip()

    # Parse multi-file source
    if source_code.startswith("{{"):
        try:
            parsed = json.loads(source_code[1:-1])
            sources = parsed.get("sources", {})
        except json.JSONDecodeError:
            return source_code.strip()
    else:
        try:
            sources = json.loads(source_code)
            first_val = next(iter(sources.values()), None)
            if isinstance(first_val, str):
                return source_code.strip()
        except json.JSONDecodeError:
            return source_code.strip()

    if not sources:
        return source_code.strip()

    # Create temp directory and write all source files
    tmpdir = tempfile.mkdtemp()
    main_file = None

    try:
        for filepath, file_data in sources.items():
            content = file_data.get("content", "") if isinstance(file_data, dict) else str(file_data)
            full_path = os.path.join(tmpdir, filepath)
            os.makedirs(os.path.dirname(full_path), exist_ok=True)
            with open(full_path, "w") as f:
                f.write(content)

            # Find the main contract file
            if contract_name and contract_name in filepath:
                main_file = full_path

        # If no main file found by name, use the last file (usually the main contract)
        if not main_file:
            main_file = full_path

        # Run forge flatten
        result = subprocess.run(
            [FORGE_BIN, "flatten", main_file],
            capture_output=True, text=True, timeout=30, cwd=tmpdir,
        )

        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
        else:
            # Fallback: try concatenation
            return _naive_flatten(sources)

    except Exception as e:
        return _naive_flatten(sources)
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def _naive_flatten(sources):
    """Fallback: naive concatenation."""
    parts = []
    seen_pragma = False
    seen_spdx = False

    for filepath, file_data in sources.items():
        content = file_data.get("content", "") if isinstance(file_data, dict) else str(file_data)
        lines = []
        for line in content.split("\n"):
            s = line.strip()
            if s.startswith("import "):
                continue
            if s.startswith("pragma ") and seen_pragma:
                continue
            if s.startswith("// SPDX") and seen_spdx:
                continue
            if s.startswith("pragma "):
                seen_pragma = True
            if s.startswith("// SPDX"):
                seen_spdx = True
            lines.append(line)
        parts.append("\n".join(lines))

    return "\n\n".join(parts)


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Collect all addresses from contract file headers
    contracts = []
    for sol_file in sorted(INPUT_DIR.rglob("*.sol")):
        if "metadata" in str(sol_file) or "raw" in str(sol_file):
            continue
        try:
            with open(sol_file) as f:
                header = f.read(500)
            match = re.search(r'Address:\s*(0x[a-fA-F0-9]{40})', header)
            if match:
                category = sol_file.parent.name
                contracts.append({
                    "address": match.group(1),
                    "category": category,
                    "original_file": sol_file,
                })
        except:
            pass

    # Deduplicate by address
    seen = set()
    unique = []
    for c in contracts:
        addr = c["address"].lower()
        if addr not in seen:
            seen.add(addr)
            unique.append(c)
    contracts = unique

    print(f"Total contracts to process: {len(contracts)}")

    success = 0
    failed = 0

    for i, info in enumerate(contracts):
        address = info["address"]
        category = info["category"]

        cat_dir = OUTPUT_DIR / category
        cat_dir.mkdir(parents=True, exist_ok=True)

        # Skip if already done
        existing = list(cat_dir.glob(f"*{address[:10]}*"))
        if existing:
            success += 1
            continue

        print(f"[{i+1}/{len(contracts)}] {category} ({address[:10]}...)")

        time.sleep(RATE_LIMIT)
        result = etherscan_get_source(address)

        if not result:
            failed += 1
            print(f"  SKIP: no response")
            continue

        source = result.get("SourceCode", "")
        name = result.get("ContractName", "Unknown")
        compiler = result.get("CompilerVersion", "")

        if not source:
            failed += 1
            print(f"  SKIP: empty source")
            continue

        # Flatten
        flat = flatten_with_forge(source, name, compiler)

        if not flat or len(flat) < 50:
            failed += 1
            print(f"  SKIP: flatten failed")
            continue

        # Detect pragma for header
        pragma_match = re.search(r'pragma\s+solidity\s+([^;]+);', flat)
        pragma = pragma_match.group(0) if pragma_match else ""

        # Save
        header = (
            f"// Source: Etherscan Verified (forge-flattened)\n"
            f"// Address: {address}\n"
            f"// Name: {name}\n"
            f"// Compiler: {compiler}\n\n"
        )

        safe_name = re.sub(r'[^a-zA-Z0-9_-]', '', name)[:40]
        filename = f"{success:03d}_{safe_name}_{address[:10]}.sol"
        filepath = cat_dir / filename

        with open(filepath, "w") as f:
            f.write(header + flat)

        success += 1
        is_multi = source.startswith("{")
        print(f"  OK: {name} ({len(flat)} chars, {'multi-file' if is_multi else 'single'}, {compiler})")

    print(f"\n{'='*60}")
    print(f"FORGE FLATTEN COMPLETE")
    print(f"{'='*60}")
    print(f"Success: {success}")
    print(f"Failed: {failed}")
    print(f"Output: {OUTPUT_DIR}")

    for cat_dir in sorted(OUTPUT_DIR.iterdir()):
        if cat_dir.is_dir():
            count = len(list(cat_dir.glob("*.sol")))
            print(f"  {cat_dir.name}: {count}")


if __name__ == "__main__":
    main()
