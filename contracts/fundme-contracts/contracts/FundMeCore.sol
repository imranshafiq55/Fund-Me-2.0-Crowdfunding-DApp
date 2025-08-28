// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "openzeppelin/contracts/security/ReentrancyGuard.sol";

contract FundMeCore is ReentrancyGuard{

    struct Campaign {
        uint256 id;             // Unique campaign ID
        address creator;        // Campaign creator
        string title;           // Campaign title
        string description;     // Short description
        uint256 goal;           // Funding goal in wei
        uint64 deadline;        // UNIX timestamp of deadline
        uint256 fundsRaised;    // Total amount raised
        bool withdrawn;         // Has creator withdrawn funds
    }

    uint256 public campaignCount;
    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => uint256)) public contributions;

    event CampaignCreated(
    uint256 indexed id,        // searchable by ID
    address indexed creator,   // searchable by creator
    uint256 goal,              // just stored, not searchable
    uint256 indexed deadline   // searchable by deadline
  );

  event ContributionMade(
    uint256 indexed campaignId,
    address indexed contributor,
    uint256 amount
  );

  event FundsWithdrawn(
    uint256 indexed campaignId,
    address indexed creator
  );

  event RefundIssued(
    uint256 indexed campaignId,
    address indexed contributor
  );
  ////////////Errors//////////////////////////
  error InvalidCampaignId(uint256 campaignId);
  error CampaignStillActive();
  error ContributionIsGreaterThanZero();
  error CallerIsNotCreatorOfCampaign();
  error FundingGoalNotMet(); 
  error FundsHasBeenWithdrawn();
  error TransferFailed();
  error SenderDidNotContributed();

  function createCampaign (string memory _title,
    string memory _description,
    uint256 _goal,
    uint64 _deadline) public{
    require(_goal > 0, "Goal must be greater than 0");
    require(_deadline > block.timestamp, "Deadline must be in the future");
       uint256 id = ++campaignCount;
       campaigns[id] = Campaign({
    id: id,
    creator: msg.sender,
    title: _title,
    description: _description,
    goal: _goal,
    deadline: _deadline,
    fundsRaised: 0,
    withdrawn: false
  });
  emit CampaignCreated(id, msg.sender, _goal, _deadline);
    
       }

   function  contribute(uint256 campaignId ) public payable {
    Campaign storage campaign = campaigns[campaignId];
    if (!(campaignId > 0 && campaignId <= campaignCount)) {
    revert InvalidCampaignId(campaignId);
   }
   if(!(block.timestamp < campaign.deadline)){
    revert CampaignStillActive();
   }
   if(!(msg.value > 0)){
    revert ContributionIsGreaterThanZero();
   }
   campaign.fundsRaised += msg.value;
   contributions[campaignId][msg.sender] += msg.value;
   emit ContributionMade(campaignId, msg.sender, msg.value);
   }    

   function withdraw(uint256 campaignId) external nonReentrant{
    Campaign storage campaign = campaigns[campaignId];
    if (!(campaignId > 0 && campaignId <= campaignCount)) {
    revert InvalidCampaignId(campaignId);
   }
   if (!(msg.sender == campaign.creator)){
    revert CallerIsNotCreatorOfCampaign();
   }
   if(block.timestamp < campaign.deadline){
    revert CampaignStillActive();
   }
   if(campaign.fundsRaised < campaign.goal){
    revert FundingGoalNotMet(); 
   }
   if (!(campaign.withdrawn == false)){
    revert FundsHasBeenWithdrawn();
   }

   (bool success, ) = campaign.creator.call{value: campaign.fundsRaised}("");
   if(!success){
    revert TransferFailed();
   }
   campaign.withdrawn = true;
   emit FundsWithdrawn(campaignId, campaign.creator);
   }
 
 function refund(uint256 campaignId) public nonReentrant{

    Campaign storage campaign = campaigns[campaignId];
    if (!(campaignId > 0 && campaignId <= campaignCount)) {
    revert InvalidCampaignId(campaignId);
   }
   if((block.timestamp < campaign.deadline)){
    revert CampaignStillActive();
   }
   if(campaign.fundsRaised >= campaign.goal){
    revert FundingGoalNotMet(); 
   }
   if(contributions[campaignId][msg.sender] == 0){
    revert SenderDidNotContributed();
   }

   uint256 amount = contributions[campaignId][msg.sender];
   (bool success, ) = payable(msg.sender).call{value: amount}("");
   if (!success) {
    revert TransferFailed();
   }

   campaign.fundsRaised -= amount;
   contributions[campaignId][msg.sender] = 0;
   emit RefundIssued(campaignId, msg.sender);
 }



}
