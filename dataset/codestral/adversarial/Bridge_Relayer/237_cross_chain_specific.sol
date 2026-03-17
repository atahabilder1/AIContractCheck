// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleBridgeRelayer {
    event TokensBridged(address indexed sender, address indexed recipient, uint256 amount);

    function bridgeTokens(address _tokenAddress, address _recipient, uint256 _amount) external {
        IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _amount);
        IERC20(_tokenAddress).transfer(_recipient, _amount);
        emit TokensBridged(msg.sender, _recipient, _amount);
    }

    interface IERC20 {
        function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
        function transfer(address recipient, uint256 amount) external returns (bool);
    }
}