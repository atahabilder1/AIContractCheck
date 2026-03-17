"""
Collect and categorize OpenZeppelin contracts for human baseline.
Maps OZ contracts to our 20 categories based on directory structure and content.
"""

import os
import re
import shutil
from pathlib import Path
from datetime import datetime

OZ_DIR = Path("/tmp/openzeppelin/contracts")
OUTPUT_DIR = Path("dataset/human_baseline_oz")

# Map OpenZeppelin directories/files to our 20 categories
OZ_CATEGORY_MAP = {
    "ERC20_Token": {
        "paths": ["token/ERC20"],
        "keywords": ["ERC20"],
        "exclude": ["ERC721", "ERC1155"],
    },
    "ERC721_NFT": {
        "paths": ["token/ERC721"],
        "keywords": ["ERC721", "NFT"],
        "exclude": ["ERC20", "ERC1155"],
    },
    "ERC1155_Multi-Token": {
        "paths": ["token/ERC1155"],
        "keywords": ["ERC1155"],
        "exclude": ["ERC20", "ERC721"],
    },
    "Access_Control_RBAC": {
        "paths": ["access"],
        "keywords": ["AccessControl", "Ownable", "AccessManager"],
        "exclude": [],
    },
    "Proxy_Upgradeable_UUPS": {
        "paths": ["proxy"],
        "keywords": ["Proxy", "UUPS", "Upgradeable", "ERC1967", "Beacon", "Clones"],
        "exclude": [],
    },
    "Governance_DAO": {
        "paths": ["governance"],
        "keywords": ["Governor", "Votes", "TimelockController"],
        "exclude": [],
    },
    "Timelock": {
        "paths": ["governance/extensions"],
        "keywords": ["Timelock"],
        "exclude": [],
    },
    "DeFi_Staking": {
        "paths": [],
        "keywords": ["stake", "reward", "staking"],
        "exclude": [],
    },
    "Flash_Loan_Provider": {
        "paths": [],
        "keywords": ["flashLoan", "FlashLoan", "IERC3156"],
        "exclude": [],
    },
    "Escrow": {
        "paths": ["finance"],
        "keywords": ["Escrow", "PaymentSplitter", "VestingWallet"],
        "exclude": [],
    },
    "Cross-Chain_Messaging": {
        "paths": ["crosschain"],
        "keywords": ["CrossChain", "crosschain"],
        "exclude": [],
    },
    "Multisig_Wallet": {
        "paths": [],
        "keywords": ["Multicall", "multisig"],
        "exclude": [],
    },
    "Wrapped_Token": {
        "paths": [],
        "keywords": ["Wrapper", "wrap", "ERC20Wrapper"],
        "exclude": [],
    },
}


def categorize_oz_file(filepath):
    """Determine which category an OZ contract belongs to."""
    rel_path = str(filepath.relative_to(OZ_DIR))

    try:
        content = filepath.read_text()
    except Exception:
        return None

    # Skip interfaces-only and test files
    if "/mocks/" in rel_path or "/vendor/" in rel_path:
        return None

    # Skip pure interface files (we want implementations)
    if filepath.name.startswith("I") and filepath.name[1].isupper():
        # Check if it's actually just an interface
        if "interface " in content and "contract " not in content:
            return None

    matches = []
    for category, rules in OZ_CATEGORY_MAP.items():
        score = 0

        # Check path match
        for path_prefix in rules["paths"]:
            if rel_path.startswith(path_prefix):
                score += 3
                break

        # Check keyword match
        for kw in rules["keywords"]:
            if kw.lower() in content.lower():
                score += 1

        # Check exclusions
        excluded = False
        for ex in rules["exclude"]:
            if ex.lower() in content.lower() and ex.lower() not in [k.lower() for k in rules["keywords"]]:
                excluded = True
                break

        if not excluded and score > 0:
            matches.append((category, score))

    if matches:
        matches.sort(key=lambda x: -x[1])
        return matches[0][0]

    return None


def sanitize_filename(name):
    name = re.sub(r'[/\\()\s]+', '_', name)
    name = re.sub(r'[^a-zA-Z0-9_-]', '', name)
    return name[:50]


def collect():
    if not OZ_DIR.exists():
        print("ERROR: Clone OpenZeppelin first:")
        print("  git clone --depth 1 https://github.com/OpenZeppelin/openzeppelin-contracts.git /tmp/openzeppelin")
        return

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Find all .sol files
    sol_files = list(OZ_DIR.rglob("*.sol"))
    print(f"Found {len(sol_files)} .sol files in OpenZeppelin")

    categorized = {}
    uncategorized = []

    for f in sol_files:
        cat = categorize_oz_file(f)
        if cat:
            categorized.setdefault(cat, []).append(f)
        else:
            uncategorized.append(f)

    print(f"\nCategorized: {sum(len(v) for v in categorized.values())}")
    print(f"Uncategorized: {len(uncategorized)}")

    # Save categorized contracts
    total = 0
    for category, files in sorted(categorized.items()):
        safe_cat = sanitize_filename(category)
        cat_dir = OUTPUT_DIR / safe_cat
        cat_dir.mkdir(parents=True, exist_ok=True)

        print(f"\n{category}: {len(files)} contracts")
        for i, f in enumerate(files):
            safe_name = sanitize_filename(f.stem)
            dest = cat_dir / f"{i:03d}_{safe_name}.sol"

            content = f.read_text()
            header = (
                f"// Source: OpenZeppelin Contracts (GitHub)\n"
                f"// Original Path: {f.relative_to(OZ_DIR)}\n"
                f"// License: MIT\n"
                f"// Collected: {datetime.now().isoformat()}\n\n"
            )
            dest.write_text(header + content)
            print(f"  {dest.name}")
            total += 1

    print(f"\n{'='*60}")
    print(f"Total saved: {total} contracts")
    print(f"Output: {OUTPUT_DIR}")

    # Also save uncategorized for manual review
    uncat_dir = OUTPUT_DIR / "_uncategorized"
    uncat_dir.mkdir(exist_ok=True)
    for i, f in enumerate(uncategorized):
        safe_name = sanitize_filename(f.stem)
        dest = uncat_dir / f"{i:03d}_{safe_name}.sol"
        content = f.read_text()
        dest.write_text(content)
    print(f"Uncategorized saved to: {uncat_dir} ({len(uncategorized)} files)")


if __name__ == "__main__":
    collect()
