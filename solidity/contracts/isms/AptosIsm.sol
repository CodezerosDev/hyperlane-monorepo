// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.8.0;

// ============ Internal Imports ============
import {IInterchainSecurityModule} from "../interfaces/IInterchainSecurityModule.sol";
import {Message} from "../libs/Message.sol";

contract AptosIsm is IInterchainSecurityModule {
    using Message for bytes;

    uint8 public immutable moduleType = uint8(Types.NULL);
    bytes32 public immutable sender;

    constructor(bytes32 _sender) {
        sender = _sender;
    }

    function verify(
        bytes calldata,
        bytes calldata message
    ) external view returns (bool) {
        return Message.sender(message) == sender;
    }
}
