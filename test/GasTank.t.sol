// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {GasTank} from "../src/GasTank.sol";

contract GasTankTest is Test {
    GasTank public gasTank;

    function setUp() public {
        gasTank = new GasTank();
    }

    function testInitialDeployment() public {
        assertEq(gasTank.halvings(), 0);
        assertEq(gasTank.lastHalvingBlock(), block.number);
        assertEq(gasTank.tokensPerMint(), 420 * (10 ** gasTank.decimals()));
    }

    function testMinting() public {
        string memory message = "Test mint";
        uint8 maxBlockMintCount = 1;

        vm.expectEmit(true, true, true, true);
        emit GasTank.Message(message);
        emit GasTank.Minted(address(this), block.number, gasTank.tokensPerMint(), message);

        gasTank.mint(message, maxBlockMintCount);

        uint256 expectedReward = gasTank.tokensPerMint();
        assertEq(gasTank.balanceOf(address(this)), expectedReward);
        assertEq(gasTank.getBlockMintCount(block.number), 1);
    }

    function testHalving() public {
        string memory initialMessage = "Initial mint";
        string memory postHalvingMessage = "First mint after halving";
        uint8 maxBlockMintCount = 1;

        gasTank.mint(initialMessage, maxBlockMintCount);

        uint256 initialBlock = block.number;
        vm.roll(initialBlock + GasTank.HALVING_BLOCKS());

        uint256 halvedReward = gasTank.tokensPerMint() / 2;

        vm.expectEmit(true, true, true, true);
        emit GasTank.Message(postHalvingMessage);
        emit GasTank.Minted(address(this), block.number, halvedReward, postHalvingMessage);

        gasTank.mint(postHalvingMessage, maxBlockMintCount);

        assertEq(gasTank.halvings(), 1);
        uint256 expectedTotalBalance = gasTank.tokensPerMint() + halvedReward;
        assertEq(gasTank.balanceOf(address(this)), expectedTotalBalance);
    }

    function testBlockMintCount() public {
        string memory firstMessage = "Mint 1";
        string memory secondMessage = "Mint 2";
        uint8 maxBlockMintCount = 2;

        gasTank.mint(firstMessage, maxBlockMintCount);

        uint256 secondReward = gasTank.tokensPerMint() / 2;

        vm.expectEmit(true, true, true, true);
        emit GasTank.Message(secondMessage);
        emit GasTank.Minted(address(this), block.number, secondReward, secondMessage);

        gasTank.mint(secondMessage, maxBlockMintCount);

        assertEq(gasTank.getBlockMintCount(block.number), 2);
        uint256 expectedTotalBalance = gasTank.tokensPerMint() + secondReward;
        assertEq(gasTank.balanceOf(address(this)), expectedTotalBalance);
    }

    function testMintingExceedsMaxBlockMintCount() public {
        string memory firstMessage = "Mint 1";
        string memory secondMessage = "Mint 2";
        uint8 maxBlockMintCount = 1;

        gasTank.mint(firstMessage, maxBlockMintCount);

        vm.expectRevert("Block mint count exceeded");
        gasTank.mint(secondMessage, maxBlockMintCount);
    }

    function testGetNextReward() public {
        string memory firstMessage = "Mint 1";
        string memory secondMessage = "Mint 2";
        uint8 maxBlockMintCount = 2;

        gasTank.mint(firstMessage, maxBlockMintCount);

        uint256 expectedNextReward = gasTank.tokensPerMint() / 2;
        assertEq(gasTank.getNextReward(), expectedNextReward);

        gasTank.mint(secondMessage, maxBlockMintCount);

        expectedNextReward = gasTank.tokensPerMint() / 4;
        assertEq(gasTank.getNextReward(), expectedNextReward);
    }
}
