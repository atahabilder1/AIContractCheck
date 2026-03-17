"""
Collect human-written verified contracts from Etherscan for baseline comparison.
300 contracts: 15 per category × 20 categories (matching our LLM prompt structure).

Uses Etherscan API to find verified contracts by searching for category-relevant
keywords, then downloads and saves the source code.

Usage:
    python collect_human_baseline.py
    python collect_human_baseline.py --category "ERC20 Token"
    python collect_human_baseline.py --resume
"""

import json
import os
import re
import time
import urllib.request
import urllib.parse
import urllib.error
from pathlib import Path
from datetime import datetime

from dotenv import load_dotenv
from seed_contracts import SEED_CONTRACTS
from extra_seeds import EXTRA_SEEDS

load_dotenv()

API_KEY = os.getenv("ETHERSCAN_API_KEY")
BASE_URL = "https://api.etherscan.io/v2/api"
OUTPUT_DIR = Path("dataset/human_baseline")
PROGRESS_FILE = OUTPUT_DIR / "progress.json"
PER_CATEGORY = 15
RATE_LIMIT_DELAY = 0.25  # 5 calls/sec max on free tier

# ── Category → search keywords mapping ────────────────────────────────────
# We search Etherscan for verified contracts whose source contains these keywords.
# Multiple keyword sets per category increase coverage.

CATEGORY_KEYWORDS = {
    "ERC20_Token": [
        ["ERC20", "totalSupply", "transfer", "balanceOf"],
    ],
    "ERC721_NFT": [
        ["ERC721", "tokenURI", "ownerOf", "mint"],
    ],
    "ERC1155_Multi-Token": [
        ["ERC1155", "balanceOfBatch", "safeTransferFrom"],
    ],
    "DeFi_Staking": [
        ["stake", "unstake", "rewardPerToken", "earned"],
        ["staking", "deposit", "withdraw", "rewardRate"],
    ],
    "DeFi_Lending": [
        ["borrow", "repay", "liquidate", "collateral"],
        ["lend", "deposit", "interestRate", "healthFactor"],
    ],
    "DeFi_DEX_AMM": [
        ["swap", "addLiquidity", "removeLiquidity", "getAmountOut"],
        ["pair", "reserve0", "reserve1", "mint"],
    ],
    "Governance_DAO": [
        ["propose", "castVote", "execute", "quorum"],
        ["Governor", "proposal", "votingDelay", "votingPeriod"],
    ],
    "Multisig_Wallet": [
        ["submitTransaction", "confirmTransaction", "owners", "required"],
        ["multisig", "threshold", "signers"],
    ],
    "Timelock": [
        ["TimelockController", "schedule", "execute", "minDelay"],
        ["timelock", "delay", "queue", "eta"],
    ],
    "Proxy_Upgradeable_UUPS": [
        ["upgradeTo", "proxiableUUID", "implementation", "ERC1967"],
        ["UUPSUpgradeable", "initializable", "proxy"],
    ],
    "Access_Control_RBAC": [
        ["AccessControl", "grantRole", "revokeRole", "hasRole"],
        ["Ownable", "onlyOwner", "renounceOwnership"],
    ],
    "Auction": [
        ["bid", "highestBidder", "auctionEnd", "withdraw"],
        ["auction", "startingPrice", "bidIncrement"],
    ],
    "Crowdfunding_ICO": [
        ["contribute", "goal", "deadline", "refund"],
        ["crowdsale", "rate", "weiRaised", "buyTokens"],
    ],
    "Escrow": [
        ["escrow", "deposit", "release", "refund", "arbiter"],
    ],
    "Flash_Loan_Provider": [
        ["flashLoan", "executeOperation", "FLASHLOAN_PREMIUM"],
        ["flashMint", "maxFlashLoan", "flashFee"],
    ],
    "Yield_Aggregator": [
        ["vault", "strategy", "harvest", "earn"],
        ["deposit", "withdraw", "pricePerShare", "totalAssets"],
    ],
    "Wrapped_Token": [
        ["WETH", "deposit", "withdraw", "wrap", "unwrap"],
        ["wrapped", "underlying", "exchangeRate"],
    ],
    "Bridge_Relayer": [
        ["bridge", "relay", "messageHash", "processMessage"],
        ["crossChain", "destinationChain", "sendMessage"],
    ],
    "Cross-Chain_Bridge": [
        ["bridge", "lock", "unlock", "deposit", "chainId"],
        ["crossChain", "bridgeToken", "nonce"],
    ],
    "Cross-Chain_Messaging": [
        ["sendMessage", "receiveMessage", "trustedRemote", "lzReceive"],
        ["crossChain", "endpoint", "payload", "srcChainId"],
    ],
}

# Map between seed_contracts.py names and our category names
SEED_CATEGORY_MAP = {
    "ERC1155_Multi_Token": "ERC1155_Multi-Token",
    "Cross_Chain_Bridge": "Cross-Chain_Bridge",
    "Cross_Chain_Messaging": "Cross-Chain_Messaging",
}

def get_seeds_for_category(category):
    """Get seed addresses from both seed files, handling name mismatches."""
    addresses = []
    seen = set()

    # Check main seeds
    for source in [SEED_CONTRACTS, EXTRA_SEEDS]:
        if category in source:
            for addr in source[category]:
                if addr.lower() not in seen:
                    addresses.append(addr)
                    seen.add(addr.lower())
        # Try reverse mapping for name mismatches
        for seed_name, our_name in SEED_CATEGORY_MAP.items():
            if our_name == category and seed_name in source:
                for addr in source[seed_name]:
                    if addr.lower() not in seen:
                        addresses.append(addr)
                        seen.add(addr.lower())

    return addresses

# SEED_CONTRACTS imported from seed_contracts.py (306 addresses across 20 categories)


def etherscan_api(module, action, **params):
    """Make an Etherscan API call."""
    params["chainid"] = 1  # Ethereum mainnet
    params["module"] = module
    params["action"] = action
    params["apikey"] = API_KEY
    url = f"{BASE_URL}?{urllib.parse.urlencode(params)}"

    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=30) as resp:
                data = json.loads(resp.read().decode())
            if data.get("status") == "1" or data.get("message") == "OK":
                return data.get("result")
            elif "rate limit" in str(data.get("result", "")).lower():
                print(f"  Rate limited, waiting 5s...")
                time.sleep(5)
                continue
            else:
                return None
        except Exception as e:
            print(f"  API error (attempt {attempt+1}): {e}")
            time.sleep(2)
    return None


def get_contract_source(address):
    """Fetch verified contract source code from Etherscan."""
    time.sleep(RATE_LIMIT_DELAY)
    result = etherscan_api("contract", "getsourcecode", address=address)
    if not result or not isinstance(result, list) or len(result) == 0:
        return None

    contract = result[0]
    source = contract.get("SourceCode", "")
    name = contract.get("ContractName", "Unknown")
    compiler = contract.get("CompilerVersion", "")

    if not source or source == "":
        return None

    # Handle multi-file JSON format
    if source.startswith("{{"):
        try:
            # Double-braced JSON format
            parsed = json.loads(source[1:-1])
            sources = parsed.get("sources", {})
            # Concatenate all source files
            all_source = []
            for path, content in sources.items():
                all_source.append(f"// File: {path}")
                all_source.append(content.get("content", ""))
            source = "\n\n".join(all_source)
        except json.JSONDecodeError:
            pass
    elif source.startswith("{"):
        try:
            parsed = json.loads(source)
            all_source = []
            for path, content in parsed.items():
                all_source.append(f"// File: {path}")
                all_source.append(content.get("content", ""))
            source = "\n\n".join(all_source)
        except json.JSONDecodeError:
            pass

    return {
        "address": address,
        "name": name,
        "compiler": compiler,
        "source": source,
        "optimization": contract.get("OptimizationUsed", ""),
        "runs": contract.get("Runs", ""),
        "license": contract.get("LicenseType", ""),
    }


def get_contract_tx_count(address):
    """Get transaction count for a contract to filter for active contracts."""
    time.sleep(RATE_LIMIT_DELAY)
    result = etherscan_api(
        "proxy", "eth_getTransactionCount",
        address=address, tag="latest"
    )
    if result:
        try:
            return int(result, 16)
        except (ValueError, TypeError):
            return 0
    return 0


def search_contracts_by_token_list(category):
    """Search for contracts via Etherscan token list and verified contracts."""
    addresses = set()

    # Use seed contracts if available
    if category in SEED_CONTRACTS:
        for addr in SEED_CONTRACTS[category]:
            addresses.add(addr)

    return list(addresses)


def get_recent_verified_contracts():
    """Get recently verified contracts from Etherscan."""
    # Use the verified source code search
    time.sleep(RATE_LIMIT_DELAY)

    # Get recent blocks and look for contract creations
    result = etherscan_api(
        "account", "txlist",
        address="0x0000000000000000000000000000000000000000",
        startblock=0, endblock=99999999,
        page=1, offset=10, sort="desc"
    )
    return result


def categorize_contract(source, category):
    """Check if a contract source matches a category based on keywords."""
    source_lower = source.lower()
    keyword_sets = CATEGORY_KEYWORDS.get(category, [])

    for keywords in keyword_sets:
        matches = sum(1 for kw in keywords if kw.lower() in source_lower)
        if matches >= len(keywords) * 0.6:  # 60% keyword match
            return True
    return False


def is_valid_solidity(source):
    """Check if source looks like valid single Solidity contract."""
    if not source or len(source) < 100:
        return False
    if "pragma solidity" not in source.lower() and "// SPDX" not in source:
        return False
    return True


def collect_from_seeds(category, progress, needed):
    """Collect contracts from seed addresses."""
    collected = []
    seeds = get_seeds_for_category(category)

    for address in seeds:
        if len(collected) >= needed:
            break
        if address.lower() in progress.get("seen_addresses", set()):
            continue

        print(f"  Fetching seed {address[:10]}...")
        contract = get_contract_source(address)
        if contract and is_valid_solidity(contract["source"]):
            collected.append(contract)
            print(f"    OK: {contract['name']} ({len(contract['source'])} chars)")
        else:
            print(f"    Skip: no valid source")

    return collected


def collect_via_etherscan_search(category, progress, needed):
    """
    Search Etherscan for contracts matching category keywords.
    Uses the contract list endpoint and filters by source content.
    """
    collected = []
    seen = progress.get("seen_addresses", set())

    # Strategy: search for well-known contract names and types
    search_terms = {
        "ERC20_Token": ["token", "coin", "ERC20"],
        "ERC721_NFT": ["NFT", "ERC721", "collectible"],
        "ERC1155_Multi-Token": ["ERC1155", "multitoken"],
        "DeFi_Staking": ["staking", "stake", "farm"],
        "DeFi_Lending": ["lending", "lend", "borrow"],
        "DeFi_DEX_AMM": ["swap", "exchange", "AMM", "DEX", "pool"],
        "Governance_DAO": ["governor", "DAO", "governance", "voting"],
        "Multisig_Wallet": ["multisig", "gnosis", "safe", "wallet"],
        "Timelock": ["timelock", "TimelockController"],
        "Proxy_Upgradeable_UUPS": ["proxy", "UUPS", "upgradeable"],
        "Access_Control_RBAC": ["access", "role", "admin", "ownable"],
        "Auction": ["auction", "bid", "dutch"],
        "Crowdfunding_ICO": ["crowdsale", "ICO", "crowdfund", "presale"],
        "Escrow": ["escrow", "arbitration"],
        "Flash_Loan_Provider": ["flashloan", "flash", "aave"],
        "Yield_Aggregator": ["vault", "yield", "strategy", "harvest"],
        "Wrapped_Token": ["wrapped", "WETH", "bridge"],
        "Bridge_Relayer": ["bridge", "relay", "cross-chain"],
        "Cross-Chain_Bridge": ["bridge", "lock", "crosschain"],
        "Cross-Chain_Messaging": ["messaging", "layerzero", "endpoint"],
    }

    # Try to find contracts by checking known DeFi protocol addresses
    # Since Etherscan doesn't have a "search by keyword in source" API,
    # we use a curated list approach with the verified source code endpoint
    terms = search_terms.get(category, [category.split("_")[0].lower()])

    # Try fetching top token holders / contract lists
    for term in terms:
        if len(collected) >= needed:
            break

        # Search via internal transactions to find contract addresses
        time.sleep(RATE_LIMIT_DELAY)
        # Use token search to find relevant contracts
        result = etherscan_api(
            "contract", "listcontracts",
            page=1, offset=50, filter="verified"
        )

        if not result or not isinstance(result, list):
            continue

        for item in result:
            if len(collected) >= needed:
                break

            address = item.get("Address", item.get("address", ""))
            if not address or address.lower() in seen:
                continue

            contract = get_contract_source(address)
            if not contract or not is_valid_solidity(contract["source"]):
                seen.add(address.lower())
                continue

            if categorize_contract(contract["source"], category):
                collected.append(contract)
                seen.add(address.lower())
                print(f"    Found: {contract['name']} ({address[:10]}...)")

    return collected


def sanitize_filename(name):
    """Convert a name to a safe filename."""
    name = re.sub(r'[/\\()\s]+', '_', name)
    name = re.sub(r'[^a-zA-Z0-9_-]', '', name)
    return name[:50]


def save_contract(contract, category, index, output_dir):
    """Save a contract to the output directory."""
    safe_cat = sanitize_filename(category)
    cat_dir = output_dir / safe_cat
    cat_dir.mkdir(parents=True, exist_ok=True)

    safe_name = sanitize_filename(contract["name"])
    filename = f"{index:03d}_{safe_name}.sol"
    filepath = cat_dir / filename

    # Add header comment
    header = (
        f"// Source: Etherscan Verified Contract\n"
        f"// Address: {contract['address']}\n"
        f"// Name: {contract['name']}\n"
        f"// Compiler: {contract['compiler']}\n"
        f"// License: {contract.get('license', 'Unknown')}\n"
        f"// Collected: {datetime.now().isoformat()}\n\n"
    )

    with open(filepath, "w") as f:
        f.write(header + contract["source"])

    # Save metadata
    meta_dir = output_dir / "metadata" / safe_cat
    meta_dir.mkdir(parents=True, exist_ok=True)
    meta_file = meta_dir / filename.replace(".sol", ".json")
    with open(meta_file, "w") as f:
        json.dump({
            "address": contract["address"],
            "name": contract["name"],
            "compiler": contract["compiler"],
            "license": contract.get("license", ""),
            "optimization": contract.get("optimization", ""),
            "runs": contract.get("runs", ""),
            "source_length": len(contract["source"]),
            "category": category,
            "collected_at": datetime.now().isoformat(),
        }, f, indent=2)

    return filepath


def load_progress():
    """Load collection progress."""
    if PROGRESS_FILE.exists():
        with open(PROGRESS_FILE) as f:
            p = json.load(f)
        p["seen_addresses"] = set(p.get("seen_addresses", []))
        return p
    return {
        "completed_categories": {},
        "seen_addresses": set(),
        "total_collected": 0,
    }


def save_progress(progress):
    """Save collection progress."""
    p = dict(progress)
    p["seen_addresses"] = list(p["seen_addresses"])
    PROGRESS_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(PROGRESS_FILE, "w") as f:
        json.dump(p, f, indent=2)


def collect_all(target_category=None):
    """Main collection loop."""
    if not API_KEY or API_KEY == "your_api_key_here":
        print("ERROR: Set ETHERSCAN_API_KEY in .env file")
        return

    progress = load_progress()
    categories = list(CATEGORY_KEYWORDS.keys())

    if target_category:
        safe = sanitize_filename(target_category)
        matches = [c for c in categories if sanitize_filename(c) == safe or c == target_category]
        if matches:
            categories = matches
        else:
            print(f"Unknown category: {target_category}")
            print(f"Available: {categories}")
            return

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    print(f"{'='*60}")
    print(f" Human Baseline Collection")
    print(f" Target: {PER_CATEGORY} contracts × {len(categories)} categories = {PER_CATEGORY * len(categories)}")
    print(f" Already collected: {progress['total_collected']}")
    print(f"{'='*60}\n")

    for category in categories:
        existing = progress["completed_categories"].get(category, 0)
        needed = PER_CATEGORY - existing

        if needed <= 0:
            print(f"[{category}] Already complete ({existing}/{PER_CATEGORY})")
            continue

        print(f"\n[{category}] Need {needed} more contracts (have {existing}/{PER_CATEGORY})")

        # Phase 1: Collect from seed addresses
        contracts = collect_from_seeds(category, progress, needed)

        # Phase 2: Search Etherscan for more if needed
        if len(contracts) < needed:
            remaining = needed - len(contracts)
            print(f"  Searching Etherscan for {remaining} more...")
            more = collect_via_etherscan_search(category, progress, remaining)
            contracts.extend(more)

        # Save collected contracts
        start_idx = existing
        for i, contract in enumerate(contracts):
            filepath = save_contract(contract, category, start_idx + i, OUTPUT_DIR)
            progress["seen_addresses"].add(contract["address"].lower())
            progress["total_collected"] += 1
            print(f"  Saved: {filepath}")

        progress["completed_categories"][category] = existing + len(contracts)
        save_progress(progress)

        if len(contracts) < needed:
            print(f"  WARNING: Only found {len(contracts)}/{needed} for {category}")

    # Summary
    print(f"\n{'='*60}")
    print(f" COLLECTION COMPLETE")
    print(f" Total collected: {progress['total_collected']}")
    print(f"{'='*60}")
    for cat, count in sorted(progress["completed_categories"].items()):
        status = "✓" if count >= PER_CATEGORY else "⚠"
        print(f"  {status} {cat}: {count}/{PER_CATEGORY}")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Collect human baseline contracts from Etherscan")
    parser.add_argument("--category", type=str, help="Collect for a single category only")
    parser.add_argument("--resume", action="store_true", help="Resume from progress file")
    args = parser.parse_args()

    collect_all(target_category=args.category)
