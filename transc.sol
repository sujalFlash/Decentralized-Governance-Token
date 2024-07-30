// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DecentralizedToken is ERC20, Ownable {
    struct Proposal {
        address proposer;
        address target;
        uint256 amount;
        bool executed;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 creationBlock;
        uint256 executionBlock;  // New field for execution time
        bool isMinting;
        mapping(address => bool) voters;
    }

    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    uint256 public votingPeriodInBlocks = 45000;  // Approx. 1 week worth of blocks
    uint256 public executionDelayInBlocks = 300;   // Approx. 5 minutes worth of blocks
    uint256 public requiredVotes = 1; // Required votes to create a proposal

    event ProposalCreated(uint256 proposalId, address proposer, address target, uint256 amount, bool isMinting);
    event Voted(uint256 proposalId, address voter, bool support);
    event ProposalExecuted(uint256 proposalId);

    constructor(uint256 initialSupply) ERC20("sujalflash", "SI") Ownable(address(this)) {
        _mint(msg.sender, initialSupply);
    }

    function createProposal(address target, uint256 amount, bool isMinting) public {
        require(balanceOf(msg.sender) >= requiredVotes, "Not enough tokens to create proposal");
        require(target != address(0), "Invalid target address");

        proposalCount++;
        Proposal storage proposal = proposals[proposalCount];
        proposal.proposer = msg.sender;
        proposal.target = target;
        proposal.amount = amount;
        proposal.creationBlock = block.number;
        proposal.isMinting = isMinting;
        proposal.executionBlock = block.number + executionDelayInBlocks; // Set execution delay

        emit ProposalCreated(proposalCount, msg.sender, target, amount, isMinting);
    }

    function vote(uint256 proposalId, bool support) public {
        Proposal storage proposal = proposals[proposalId];
        require(block.number < proposal.creationBlock + votingPeriodInBlocks, "Voting period has ended");
        require(balanceOf(msg.sender) > 0, "No tokens to vote");
        require(!proposal.voters[msg.sender], "Already voted");

        uint256 voterBalance = balanceOf(msg.sender);
        uint256 votePower = voterBalance;

        if (support) {
            proposal.votesFor += votePower;
        } else {
            proposal.votesAgainst += votePower;
        }
        proposal.voters[msg.sender] = true;

        emit Voted(proposalId, msg.sender, support);
    }

    function executeProposal(uint256 proposalId) public {
        Proposal storage proposal = proposals[proposalId];
        require(block.number >= proposal.executionBlock, "Execution period has not started");
        require(!proposal.executed, "Proposal already executed");

        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;
        uint256 majorityThreshold = (totalVotes * 51) / 100; // 51% of total votes

        if (proposal.votesFor >= majorityThreshold) {
            if (proposal.isMinting) {
                // Ensure the contract has enough tokens to mint
                require(address(this).balance >= proposal.amount, "Not enough balance to mint");
                _mint(proposal.proposer, proposal.amount);
            } else {
                // Ensure the proposer has enough tokens to burn
                require(balanceOf(proposal.proposer) >= proposal.amount, "Not enough balance to burn");
                _burn(proposal.proposer, proposal.amount);
            }
        } else {
            // Reject the proposal if majority threshold is not met
            revert("Proposal did not meet majority threshold");
        }

        proposal.executed = true;

        emit ProposalExecuted(proposalId);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        require(!isVoting(), "Cannot transfer during voting");
        return super.transfer(recipient, amount);
    }

    function isVoting() public view returns (bool) {
        for (uint256 i = 1; i <= proposalCount; i++) {
            if (block.number < proposals[i].creationBlock + votingPeriodInBlocks && !proposals[i].executed) {
                return true;
            }
        }
        return false;
    }
}
