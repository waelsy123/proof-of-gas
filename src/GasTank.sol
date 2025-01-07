// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/*
 * Dear Ethereum Community,
 *
 * This contract is not just code; it is an experiment, a mirror held up to the Ethereum network.
 * It challenges the boundaries of decentralized systems, exposing both their strengths and vulnerabilities.
 *
 * By leveraging network dynamics and gamifying gas consumption, this token derives its value from gas on-chain.
 * It behaves as a store of value for underutilized block space, introducing Proof of Gas — a concept akin to a battery for the EVM world.
 *
 * The minting mechanism is designed to incentivize early action within each block. The first caller to mint within a block receives the highest reward of 420 tokens. 
 * Subsequent calls within the same block see the reward halved successively (i.e., 210, 105, 52.5, etc.).
 *
 * Supply:
 * Initially, each block allows for a maximum of 420 tokens to be minted by the first participant. Subsequent participants receive progressively smaller rewards according to the halving logic.
 * Given approximately 7200 blocks per day, and the 2-year halving mechanism, the total maximum supply over the contract's lifetime will be capped at less than 8,830,080,000 tokens.
 *
 * github: https://github.com/waelsy123/gas-tank
*/

contract GasTank is ERC20, ERC20Permit {
    /**
     * @dev Every 5,256,000 blocks (~2 years), the minting power is further reduced 
     *      due to incremental halvings. This figure is slightly reduced (5,256,000 
     *      vs. the original 5,256,000 from the text) for approximate 2-year intervals.
     */
    uint256 public constant HALVING_BLOCKS = 5256000; // approximately 2 years in blocks

    /**
     * @dev The base token reward for the very first minter in any block.
     *      Denominated with decimals() multiplication for proper ERC20 precision.
     */
    uint256 public immutable tokensPerMint = 420 * (10 ** decimals());

    /**
     * @dev Tracks how many times the reward has halved overall since contract creation.
     *      This increments once block.number exceeds lastHalvingBlock + HALVING_BLOCKS.
     */
    uint256 public halvings;
    /**
     * @dev The block number at which the most recent halving was recorded.
     */
    uint256 public lastHalvingBlock;

    /**
     * @dev Tracks the number of mints per block. Used to determine how much reward 
     *      to give each subsequent minter in the same block (halved successively).
     */
    mapping(uint256 => uint256) public blockMintCount;

    /**
     * @notice Emitted with every mint call, capturing the user’s provided message.
     */
    event Message(string message);

    /**
     * @notice (Additional) Emitted whenever tokens are successfully minted,
     *         logging the minter, minted amount, and the associated block.
     */
    event Minted(address indexed minter, uint256 indexed blockNumber, uint256 reward, string message);

    /**
     * @dev Constructor sets the token name, symbol, and permit domain, 
     *      initializing halving-related state.
     */
    constructor() ERC20("GasTank", "TANK") ERC20Permit("GasTank") {
        halvings = 0;
        lastHalvingBlock = block.number;
    }

    /**
     * @dev Modifier preventing contract calls. This simplistic check examines extcodesize,
     *      but could still be circumvented by sophisticated proxies or `delegatecall`.
     *      Primarily serves as a deterrent.
     */
    modifier noContract(address _addr) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        require(size == 0, "No contract calls allowed");
        _;
    }

    /**
     * @notice Allows users to mint tokens by proof-of-gas
     * The goal to allow only one mint per tx, we should not worry about being called by newly deployed contract
     * constructor taking into consideration amount of gas needed to deploy new contract.
     * @param message Custom message to be emitted in the `Message` event.
     * @param maxBlockMintCount User-defined maximum block mint count to protect from miner front-running.
     */
    function mint(string calldata message, uint8 maxBlockMintCount)
        external
        noContract(msg.sender)
    {
        require(blockMintCount[block.number] <= maxBlockMintCount, "Block mint count exceeded"); // to protect miner from being front-run

        // Check if a halving interval has passed since lastHalvingBlock
        if (block.number >= lastHalvingBlock + HALVING_BLOCKS) {
            lastHalvingBlock = block.number;
            halvings++;
        }

        // Bump the block’s mint count and determine the exponent for halving.
        uint256 currentCount = ++blockMintCount[block.number];

        // reward will be more than zero as long as exponent is < 69
        uint256 exponent = currentCount + halvings - 1;
        uint256 reward = tokensPerMint / (2 ** exponent);

        // Mint to the caller
        _mint(msg.sender, reward);

        // Emit custom message and an extended mint event
        emit Message(message);
        emit Minted(msg.sender, block.number, reward, message);
    }

    /**
     * @notice Returns how many times mint has been called in a specified block.
     * @param blockNumber The block number whose mint count you want to check.
     */
    function getBlockMintCount(uint256 blockNumber) external view returns (uint256) {
        return blockMintCount[blockNumber];
    }

    /**
     * @notice (Additional) Returns the current halving count for reference.
     */
    function getHalvings() external view returns (uint256) {
        return halvings;
    }

    /**
     * @notice (Additional) Estimates the next reward for the very next minter in the current block.
     *         This does not account for a potential halving if the block changes, but 
     *         provides an approximate idea if no new halving is triggered before you mint.
     * @return nextReward The computed reward for the next mint caller.
     */
    function getNextReward() external view returns (uint256 nextReward) {
        uint256 countSoFar = blockMintCount[block.number];
        uint256 exponent = (countSoFar + halvings);
        nextReward = tokensPerMint / (2 ** exponent);
    }
}
