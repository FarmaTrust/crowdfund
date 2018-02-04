var SafeMath = artifacts.require("./SafeMath.sol");
var FTToken = artifacts.require("./FTToken.sol");
var Addresses = artifacts.require("./Addresses.sol");
var TokenDistribution = artifacts.require("./TokenDistribution.sol");
var FundTokenVesting = artifacts.require("./FundTokenVesting.sol");
var UnsoldTokenVesting = artifacts.require("./UnsoldTokenVesting.sol");

var TDE_beneficiary = web3.eth.accounts[1];  // To-do: multi-sig wallet
var FTV_Beneficiary = web3.eth.accounts[0];  // To-do: multi-sig wallet
var UTV_Beneficiary = web3.eth.accounts[0];  // To-do: multi-sig wallet

var start = web3.eth.blockNumber;
var end = web3.eth.blockNumber+1000;

var limit = 600000000;

// To-do: calculate phase 1, 2 and 3 prices client side then use each to init TDE contract. 
var price = 0.00010870;
price = web3.toWei(price, "ether")
var cap = 5000; 
cap = web3.toWei(cap, "ether")

// FundTokenVesting parameters
const ftv_cliff = 15768000;    // ~6 months
const ftv_duration = 124416000 // ~4 years 
var ftv_revocable = true;

// UnsoldTokenVesting parameters
const utv_cliff = 31104000;    // ~1 year
const utv_duration = 155520000 // ~5 years 
var utv_revocable = true;

module.exports = function(deployer) {
  deployer.deploy(SafeMath);
  deployer.link(SafeMath, FTToken);
  deployer.deploy(Addresses);
  deployer.link(Addresses, FTToken);
  deployer.link(SafeMath, FundTokenVesting);
  deployer.deploy(FundTokenVesting, FTV_Beneficiary, start, ftv_cliff, ftv_duration, ftv_revocable)
    .then(() => {
      console.log("ftva: " + FundTokenVesting.address);
      deployer.link(SafeMath, UnsoldTokenVesting);
      deployer.deploy(UnsoldTokenVesting, UTV_Beneficiary, start, utv_cliff, utv_duration, utv_revocable)
        .then(() => {
          deployer.deploy(FTToken, FundTokenVesting.address)
            .then(() => {
              return deployer.deploy(
                TokenDistribution,
                FTToken.address,
                start,
                end,
                price,
                limit, 
                cap, 
                TDE_beneficiary, 
                UnsoldTokenVesting.address
              ).then(function(){});
            });
          })
    });
}
