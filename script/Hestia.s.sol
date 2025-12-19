// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Script, console} from "forge-std/Script.sol";

import {IRegistry} from "../src/interfaces/IRegistry.sol";
import {MaldoToken} from "../src/mocks/MaldoToken.sol";
import {Registry} from "../src/contracts/Registry.sol";

contract MaldoScript is Script {
    function setUp() public {}

    address public constant SEPOLIA_ESCROW_ADDRESS = 0xA01e6B988aeDae1fD4a748D6bfBcB8A438601DeE;

    function _deployer() internal returns (uint256, address) {
        uint256 deployerPK = vm.envUint("DEPLOYER_PRIVATE_KEY");
        return (deployerPK, vm.addr(deployerPK));
    }

    function run() public {
        console.log("Specify a function to run");
        (uint256 deployerPK, address deployer) = _deployer();
        console.log("DEPLOYER:", deployer);
    }

    function fullDeploy(address _token) public {
        deployRegistry(_token, SEPOLIA_ESCROW_ADDRESS);
    }

    function deployRegistry(address _token, address _escrow) public returns (Registry) {
        (uint256 privateKey, address deployer) = _deployer();
        vm.startBroadcast(privateKey);
        Registry registry = new Registry(_token, _escrow, deployer);
        console.log("Registry deployed at:", address(registry));
        vm.stopBroadcast();
        return registry;
    }

    function deployTokenMaldo() public {
        uint256 privateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        ERC20 token = new MaldoToken();

        vm.stopBroadcast();
    }
}
