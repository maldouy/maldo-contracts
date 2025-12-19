// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {Registry} from "contracts/Registry.sol";
import {MaldoToken} from "../src/mocks/MaldoToken.sol";
import {Test, console} from "forge-std/Test.sol";
import {IRegistry} from "interfaces/IRegistry.sol";

// Mock Escrow contract for testing
contract MockEscrow {
    uint256 private nextId = 1;

    function createERC20Transaction(
        uint256,
        address,
        uint256,
        string memory,
        address payable,
        address payable
    ) external returns (uint256) {
        return nextId++;
    }
}

contract RegistryTest is Test {
    address deployer = makeAddr("deployer");
    address tasker = makeAddr("tasker");
    address user = makeAddr("user");
    address anotherUser = makeAddr("anotherUser");

    Registry registry;
    MaldoToken token;
    MockEscrow escrow;

    function setUp() public {
        vm.startPrank(deployer);

        token = new MaldoToken();
        escrow = new MockEscrow();
        registry = new Registry(address(token), address(escrow), deployer);

        vm.stopPrank();
    }

    function test_integration() public {
        // set profile
        vm.prank(tasker);
        registry.setProfile("profile");
        // check emitted event

        // add service
        vm.prank(tasker);
        registry.addService("service");
        // check emitted event

        // update service
        vm.prank(tasker);
        registry.updateService(0, "service, updated");
        // check emitted event

        // only the tasker can update its service
        vm.startPrank(anotherUser);
        vm.expectRevert(abi.encodeWithSelector(IRegistry.Unauthorized.selector));
        registry.updateService(0, "service, updated again");
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(IRegistry.Unauthorized.selector));
        registry.createDeal(0, 100, user, 1 days, "test-agreement-uri");
        vm.stopPrank();

        vm.startPrank(tasker);
        vm.expectRevert(abi.encodeWithSelector(IRegistry.InvalidBeneficiary.selector));
        registry.createDeal(0, 100, address(0), 1 days, "test-agreement-uri");
        vm.stopPrank();

        vm.startPrank(tasker);
        registry.createDeal(0, 100, user, 1 days, "test-agreement-uri");
        vm.stopPrank();

        // rate a deal - customer reviews tasker
        vm.prank(user);
        registry.rate(0, 5, "good review");
        // check emitted event

        // tasker can also rate the customer
        vm.prank(tasker);
        registry.rate(0, 4, "reliable customer");

        // dispute reverts because the address is not set
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IRegistry.DisputeResolverNotSet.selector));
        registry.dispute(0);
    }
}
