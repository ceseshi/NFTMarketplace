// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {NFTMarketplace} from "../src/NFTMarketplace.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract NFTMarketplaceDeploy is Script {
    function setUp() public {}

    function run() public {
        vm.broadcast();

        address implementation = address(new NFTMarketplace());

        bytes memory initializerData = abi.encodeCall(NFTMarketplace.initialize, ("NFTMarketplace"));
        address proxy = address(new ERC1967Proxy(implementation, initializerData));

        console2.log("NFTMarketplace implementation deployed at:", implementation);
        console2.log("NFTMarketplace proxy deployed at:", proxy);
    }
}
