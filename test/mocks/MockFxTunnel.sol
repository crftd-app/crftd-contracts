// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface FxChild {
    function processMessageFromRoot(
        uint256 stateId,
        address rootMessageSender,
        bytes calldata data
    ) external;
}

contract MockFxTunnel {
    function sendMessageToChild(address child, bytes memory message) public {
        (bool success, ) = child.call(
            abi.encodeWithSelector(FxChild.processMessageFromRoot.selector, 0, msg.sender, message)
        );
        require(success, "MockFxTunnel: sendMessageToChild call failed");
    }
}
