// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Most efficient NFT
contract EfficientNFT {
    mapping(uint256 => address) _o;
    mapping(address => uint256) _b;
    mapping(uint256 => address) _a;
    mapping(address => mapping(address => bool)) _op;
    uint256 _c;

    event Transfer(address indexed, address indexed, uint256 indexed);
    event Approval(address indexed, address indexed, uint256 indexed);
    event ApprovalForAll(address indexed, address indexed, bool);

    function name() external pure returns (string memory) { return "Efficient"; }
    function symbol() external pure returns (string memory) { return "EFF"; }
    function balanceOf(address a) external view returns (uint256) { return _b[a]; }
    function ownerOf(uint256 i) public view returns (address) { return _o[i]; }
    function getApproved(uint256 i) external view returns (address) { return _a[i]; }
    function isApprovedForAll(address o, address op) public view returns (bool) { return _op[o][op]; }

    function approve(address t, uint256 i) external {
        require(msg.sender == _o[i] || _op[_o[i]][msg.sender]);
        _a[i] = t;
        emit Approval(_o[i], t, i);
    }

    function setApprovalForAll(address op, bool ok) external {
        _op[msg.sender][op] = ok;
        emit ApprovalForAll(msg.sender, op, ok);
    }

    function transferFrom(address f, address t, uint256 i) public {
        require(_o[i] == f && (msg.sender == f || _a[i] == msg.sender || _op[f][msg.sender]));
        unchecked { _b[f]--; _b[t]++; }
        _o[i] = t;
        delete _a[i];
        emit Transfer(f, t, i);
    }

    function safeTransferFrom(address f, address t, uint256 i) external { transferFrom(f, t, i); }
    function safeTransferFrom(address f, address t, uint256 i, bytes calldata) external { transferFrom(f, t, i); }

    function mint(address t) external {
        uint256 i = _c++;
        _b[t]++;
        _o[i] = t;
        emit Transfer(address(0), t, i);
    }
}
