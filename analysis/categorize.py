"""
CWE mapping and vulnerability categorization for Slither findings.
"""

# Slither detector to CWE mapping
CWE_MAPPING = {
    # Reentrancy
    "reentrancy-eth": "CWE-841",
    "reentrancy-no-eth": "CWE-841",
    "reentrancy-benign": "CWE-841",
    "reentrancy-events": "CWE-841",
    "reentrancy-unlimited-gas": "CWE-841",

    # Access Control
    "unprotected-upgrade": "CWE-284",
    "arbitrary-send-eth": "CWE-284",
    "arbitrary-send-erc20": "CWE-284",
    "arbitrary-send-erc20-permit": "CWE-284",
    "suicidal": "CWE-284",
    "protected-vars": "CWE-284",

    # Dangerous Calls
    "controlled-delegatecall": "CWE-829",
    "delegatecall-loop": "CWE-829",
    "low-level-calls": "CWE-676",
    "unchecked-lowlevel": "CWE-252",
    "unchecked-send": "CWE-252",
    "unchecked-transfer": "CWE-252",

    # Initialization Issues
    "uninitialized-state": "CWE-909",
    "uninitialized-storage": "CWE-909",
    "uninitialized-local": "CWE-909",

    # Authentication Issues
    "tx-origin": "CWE-477",

    # Denial of Service
    "locked-ether": "CWE-710",
    "calls-loop": "CWE-400",
    "msg-value-loop": "CWE-400",

    # Logic Issues
    "incorrect-equality": "CWE-697",
    "tautology": "CWE-571",
    "boolean-cst": "CWE-571",
    "divide-before-multiply": "CWE-682",

    # Randomness
    "weak-prng": "CWE-330",

    # Timestamp
    "timestamp": "CWE-829",
    "block-timestamp": "CWE-829",

    # Assembly
    "assembly": "CWE-710",
    "incorrect-return": "CWE-252",
    "return-bomb": "CWE-400",

    # Token Issues
    "erc20-interface": "CWE-573",
    "erc721-interface": "CWE-573",
    "erc1155-interface": "CWE-573",

    # Shadowing
    "shadowing-state": "CWE-710",
    "shadowing-local": "CWE-710",
    "shadowing-abstract": "CWE-710",
    "shadowing-builtin": "CWE-710",

    # Dead Code
    "dead-code": "CWE-561",
    "unused-state": "CWE-561",
    "unused-return": "CWE-252",

    # Storage Issues
    "storage-array": "CWE-119",
    "array-by-reference": "CWE-119",
}

# Severity weights for scoring
SEVERITY_WEIGHTS = {
    "High": 3,
    "Medium": 2,
    "Low": 1,
    "Informational": 0,
    "Optimization": 0
}

# CWE Categories
CWE_CATEGORIES = {
    "CWE-841": "Improper Enforcement of Message Integrity",
    "CWE-284": "Improper Access Control",
    "CWE-829": "Inclusion of Functionality from Untrusted Control Sphere",
    "CWE-909": "Missing Initialization of Resource",
    "CWE-477": "Use of Obsolete Function",
    "CWE-710": "Improper Adherence to Coding Standards",
    "CWE-697": "Incorrect Comparison",
    "CWE-330": "Use of Insufficiently Random Values",
    "CWE-252": "Unchecked Return Value",
    "CWE-676": "Use of Potentially Dangerous Function",
    "CWE-400": "Uncontrolled Resource Consumption",
    "CWE-571": "Expression is Always True",
    "CWE-682": "Incorrect Calculation",
    "CWE-573": "Improper Following of Specification",
    "CWE-561": "Dead Code",
    "CWE-119": "Improper Restriction of Operations within Bounds",
}


def get_cwe(detector: str) -> str:
    """Get CWE ID for a Slither detector."""
    return CWE_MAPPING.get(detector, "CWE-Unknown")


def get_cwe_description(cwe_id: str) -> str:
    """Get description for a CWE ID."""
    return CWE_CATEGORIES.get(cwe_id, "Unknown vulnerability type")


def calculate_vulnerability_score(findings: list) -> dict:
    """
    Calculate weighted vulnerability score for a set of findings.

    Args:
        findings: List of Slither detector findings

    Returns:
        Dictionary with score breakdown
    """
    score = 0
    by_severity = {"High": 0, "Medium": 0, "Low": 0, "Informational": 0}
    by_cwe = {}

    for finding in findings:
        severity = finding.get("impact", "Low")
        detector = finding.get("check", "unknown")

        # Add to score
        score += SEVERITY_WEIGHTS.get(severity, 0)

        # Count by severity
        if severity in by_severity:
            by_severity[severity] += 1

        # Count by CWE
        cwe = get_cwe(detector)
        by_cwe[cwe] = by_cwe.get(cwe, 0) + 1

    return {
        "total_score": score,
        "by_severity": by_severity,
        "by_cwe": by_cwe,
        "total_findings": len(findings),
        "has_critical": by_severity["High"] > 0
    }


def categorize_findings(slither_output: dict) -> list:
    """
    Categorize and enrich Slither findings with CWE mappings.

    Args:
        slither_output: Raw Slither JSON output

    Returns:
        List of categorized findings
    """
    detectors = slither_output.get("results", {}).get("detectors", [])
    categorized = []

    for detector in detectors:
        check = detector.get("check", "unknown")
        cwe = get_cwe(check)

        categorized.append({
            "detector": check,
            "severity": detector.get("impact", "Unknown"),
            "confidence": detector.get("confidence", "Unknown"),
            "cwe": cwe,
            "cwe_description": get_cwe_description(cwe),
            "description": detector.get("description", ""),
            "elements": detector.get("elements", [])
        })

    return categorized


if __name__ == "__main__":
    # Print CWE mapping summary
    print("Slither Detector to CWE Mapping")
    print("=" * 60)

    for detector, cwe in sorted(CWE_MAPPING.items()):
        desc = get_cwe_description(cwe)
        print(f"{detector:40s} -> {cwe} ({desc})")
