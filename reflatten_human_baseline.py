"""
Re-download human baseline contracts from Etherscan and flatten multi-file sources.
Multi-file contracts include all dependencies — we concatenate them into one file
so Slither can compile without external libraries.
"""

import json
import os
import re
import time
import urllib.request
import urllib.parse
from pathlib import Path
from datetime import datetime

from dotenv import load_dotenv

load_dotenv()

API_KEY = os.getenv("ETHERSCAN_API_KEY")
BASE_URL = "https://api.etherscan.io/v2/api"
INPUT_DIR = Path("dataset/human_baseline")
OUTPUT_DIR = Path("dataset/human_baseline_flat")
RATE_LIMIT = 0.25


def etherscan_get_source(address):
    """Fetch contract source from Etherscan V2 API."""
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
            if data.get("status") == "1" and data.get("result"):
                return data["result"][0]
            if "rate limit" in str(data.get("result", "")).lower():
                time.sleep(5)
                continue
            return None
        except Exception as e:
            print(f"  API error: {e}")
            time.sleep(2)
    return None


def flatten_source(source_code, contract_name=""):
    """
    Flatten multi-file source into a single Solidity file.
    Handles both single-file and multi-file JSON formats from Etherscan.
    """
    if not source_code:
        return ""

    # Single file — already flat
    if not source_code.startswith("{"):
        return source_code.strip()

    # Multi-file: double-braced JSON {{ ... }}
    if source_code.startswith("{{"):
        try:
            parsed = json.loads(source_code[1:-1])
            sources = parsed.get("sources", {})
        except json.JSONDecodeError:
            return source_code.strip()
    else:
        # Multi-file: single-braced JSON { ... }
        try:
            sources = json.loads(source_code)
            # Check if it's actually a sources dict
            if not isinstance(sources, dict):
                return source_code.strip()
            # If first value is a string, it's not the format we expect
            first_val = next(iter(sources.values()), None)
            if isinstance(first_val, str):
                return source_code.strip()
        except json.JSONDecodeError:
            return source_code.strip()

    if not sources:
        return source_code.strip()

    # Collect all file contents
    all_contents = []
    seen_pragmas = set()
    seen_imports = set()
    seen_spdx = False

    for filepath, file_data in sources.items():
        content = file_data.get("content", "") if isinstance(file_data, dict) else str(file_data)
        if not content:
            continue

        lines = content.split("\n")
        filtered_lines = []

        for line in lines:
            stripped = line.strip()

            # Skip duplicate SPDX identifiers
            if stripped.startswith("// SPDX"):
                if not seen_spdx:
                    seen_spdx = True
                    filtered_lines.append(line)
                continue

            # Skip duplicate pragmas
            if stripped.startswith("pragma "):
                if stripped not in seen_pragmas:
                    seen_pragmas.add(stripped)
                    filtered_lines.append(line)
                continue

            # Skip import statements (all code is inlined)
            if stripped.startswith("import "):
                continue

            filtered_lines.append(line)

        all_contents.append(f"// ---- File: {filepath} ----")
        all_contents.append("\n".join(filtered_lines))

    return "\n\n".join(all_contents)


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Read metadata to get addresses
    metadata_dir = INPUT_DIR / "metadata"
    if not metadata_dir.exists():
        print("No metadata directory found. Reading addresses from contract files.")
        # Fall back to reading address from file headers
        addresses = {}
        for sol_file in sorted(INPUT_DIR.rglob("*.sol")):
            if "metadata" in str(sol_file) or "raw" in str(sol_file):
                continue
            try:
                with open(sol_file) as f:
                    header = f.read(500)
                match = re.search(r'Address:\s*(0x[a-fA-F0-9]{40})', header)
                if match:
                    addresses[str(sol_file)] = {
                        "address": match.group(1),
                        "file": sol_file,
                    }
            except:
                pass
        print(f"Found {len(addresses)} contracts with addresses")
    else:
        addresses = {}
        for meta_file in sorted(metadata_dir.rglob("*.json")):
            try:
                with open(meta_file) as f:
                    meta = json.load(f)
                cat = meta.get("category", meta_file.parent.name)
                addresses[str(meta_file)] = {
                    "address": meta["address"],
                    "name": meta.get("name", "Unknown"),
                    "category": cat,
                    "meta_file": meta_file,
                }
            except:
                pass
        print(f"Found {len(addresses)} contracts from metadata")

    # Also scan contract files directly for addresses
    for sol_file in sorted(INPUT_DIR.rglob("*.sol")):
        if "metadata" in str(sol_file) or "raw" in str(sol_file):
            continue
        try:
            with open(sol_file) as f:
                header = f.read(500)
            match = re.search(r'Address:\s*(0x[a-fA-F0-9]{40})', header)
            if match:
                key = str(sol_file)
                if key not in addresses:
                    cat = sol_file.parent.name
                    addresses[key] = {
                        "address": match.group(1),
                        "name": sol_file.stem,
                        "category": cat,
                        "file": sol_file,
                    }
        except:
            pass

    print(f"Total contracts to re-download: {len(addresses)}")

    # Re-download and flatten
    success = 0
    failed = 0
    seen_addresses = set()

    for key, info in sorted(addresses.items()):
        address = info["address"]
        if address.lower() in seen_addresses:
            continue
        seen_addresses.add(address.lower())

        category = info.get("category", "unknown")
        name = info.get("name", "Unknown")

        cat_dir = OUTPUT_DIR / category
        cat_dir.mkdir(parents=True, exist_ok=True)

        # Check if already done
        existing = list(cat_dir.glob(f"*_{address[:10]}*.sol"))
        if existing:
            success += 1
            continue

        print(f"[{success+failed+1}/{len(addresses)}] {category}/{name} ({address[:10]}...)")

        time.sleep(RATE_LIMIT)
        result = etherscan_get_source(address)

        if not result:
            print(f"  SKIP: no response")
            failed += 1
            continue

        source = result.get("SourceCode", "")
        contract_name = result.get("ContractName", name)
        compiler = result.get("CompilerVersion", "")

        if not source:
            print(f"  SKIP: empty source")
            failed += 1
            continue

        # Flatten
        flat_source = flatten_source(source, contract_name)

        if not flat_source or len(flat_source) < 50:
            print(f"  SKIP: flattening failed")
            failed += 1
            continue

        # Add header
        header = (
            f"// SPDX-License-Identifier: MIT\n"
            f"// Source: Etherscan Verified Contract (flattened)\n"
            f"// Address: {address}\n"
            f"// Name: {contract_name}\n"
            f"// Compiler: {compiler}\n"
            f"// Collected: {datetime.now().isoformat()}\n\n"
        )

        # Save
        safe_name = re.sub(r'[^a-zA-Z0-9_-]', '', contract_name)[:40]
        filename = f"{success:03d}_{safe_name}_{address[:10]}.sol"
        filepath = cat_dir / filename

        with open(filepath, "w") as f:
            f.write(header + flat_source)

        success += 1
        print(f"  OK: {contract_name} ({len(flat_source)} chars, compiler {compiler})")

    print(f"\n{'='*60}")
    print(f"FLATTENING COMPLETE")
    print(f"{'='*60}")
    print(f"Success: {success}")
    print(f"Failed: {failed}")
    print(f"Output: {OUTPUT_DIR}")

    # Per-category count
    for cat_dir in sorted(OUTPUT_DIR.iterdir()):
        if cat_dir.is_dir():
            count = len(list(cat_dir.glob("*.sol")))
            print(f"  {cat_dir.name}: {count}")


if __name__ == "__main__":
    main()
