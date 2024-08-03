// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract AccesMultisig is AccessControl {
    GnosisSafeProxyFactory public proxyFactory;
    address public masterCopy;
    address public initialOwner = 0x91fBf58305d28032c26503898Ef7C4e4997B1daa;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    constructor(address _proxyFactory, address _masterCopy) {
        proxyFactory = GnosisSafeProxyFactory(_proxyFactory);
        masterCopy = _masterCopy;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, initialOwner);
    }

    function createMultisigWallet(address[] memory owners, uint256 threshold) external onlyRole(ADMIN_ROLE) returns (address) {
        uint256 saltNonce = generateUniqueNonce();
        bytes memory data = abi.encodeWithSignature(
            "setup(address[],uint256,address,bytes,address,address,uint256,address)",
            owners,
            threshold,
            address(0),
            "",
            address(0xf48f2B2d2a534e402487b3ee7C18c33Aec0Fe5e4), // fallbackHandler
            address(0),
            0,
            payable(0)
        );

        GnosisSafeProxy proxy = proxyFactory.createProxyWithNonce(masterCopy, data, saltNonce);
        return address(proxy);
    }

    function generateUniqueNonce() internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao,
            msg.sender,
            blockhash(block.number - 1),
            uint256(keccak256(abi.encodePacked(block.timestamp, block.number))) // Adding more entropy
        )));
    }
}
