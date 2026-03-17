// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract BridgeRelayer {
    mapping(uint256 => uint256) private _used;

    error AlreadyRelayed();

    function relay(uint256 id, address target, bytes calldata data) external payable returns (bytes memory result) {
        uint256 word = id >> 8;
        uint256 bit = uint256(1) << (id & 0xff);
        uint256 w = _used[word];
        if (w & bit != 0) revert AlreadyRelayed();
        _used[word] = w | bit;

        (bool ok, bytes memory ret) = target.call{value: msg.value}(data);
        if (!ok) {
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }
        return ret;
    }

    function wasRelayed(uint256 id) external view returns (bool) {
        return (_used[id >> 8] & (uint256(1) << (id & 0xff))) != 0;
    }

    receive() external payable {}
}