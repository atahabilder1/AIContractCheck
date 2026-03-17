// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SocialRecoveryWallet {
    address payable[] private guardians;
    uint requiredSignatures;
    mapping(address => bool) public approvedGuardians;

    constructor(address payable[] memory _guardians, uint _requiredSignatures) {
        require(_guardians.length > 0, "At least one guardian is required");
        require(_requiredSignatures <= _guardians.length, "Required signatures exceeds the number of guardians");

        for (uint i = 0; i < _guardians.length; i++) {
            guardians.push(_guardians[i]);
            approvedGuardians[_guardians[i]] = true;
        }
        requiredSignatures = _requiredSignatures;
    }

    modifier onlyApprovedGuardian() {
        require(approvedGuardians[msg.sender], "Sender is not an approved guardian");
        _;
    }

    function recoverFunds(bytes memory data, bytes memory signatures) external {
        uint signatureCount = 0;
        for (uint i = 0; i < guardians.length; i++) {
            if (ecrecover(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", keccak256(data))), signatures[i * 64 + 32:]) == address(guardians[i])) {
                signatureCount++;
            }
        }
        require(signatureCount >= requiredSignatures, "Not enough valid signatures");

        assembly {
            success := call(gas(), guardians[0], add(data, 32), mload(data), 0, 0)
            if iszero(success) {
                revert(0, 0)
            }
        }
    }
}