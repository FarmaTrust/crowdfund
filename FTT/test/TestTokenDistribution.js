var TokenDistribution = artifacts.require("./TokenDistribution.sol");
var FTToken = artifacts.require("./FTToken.sol");

contract('TokenDistribution', (accounts) => {

  var creatorAddress = accounts[0];
  var recipientAddress = accounts[2];

  var TokenDistributionAddress;
  TokenDistribution.deployed().then(instance => {
    TokenDistributionAddress = instance.address;
  });

  var FTTokenAddress;
  FTToken.deployed().then(instance => {
    FTTokenAddress = instance.address;
  });

  it("should transfer 600000000 FTToken to the TokenDistribution balance", () => {
    var FTTokenInstance;
    return FTToken.deployed().then(instance => {
      FTTokenInstance = instance;
      return FTTokenInstance.transfer(TokenDistributionAddress, 600000000, {from: creatorAddress});
    }).then(result => {
      return FTTokenInstance.balanceOf.call(TokenDistributionAddress);
    }).then(TokenDistributionBalance => {
      assert.equal(TokenDistributionBalance.valueOf(), 600000000, "600000000 wasn't in the TokenDistribution balance");
    });
  });

  it("should have a TokenDistribution balance of 600000000", () => {
    return TokenDistribution.deployed().then(instance => {
      return instance.availableBalance.call();
    }).then(availableBalance => {
      assert.equal(availableBalance.valueOf(), 600000000, "600000000 wasn't the available TokenDistribution balance");
    });
  });

  it("should transfer tokens to the creator address", () => {
    var TokenDistributionInstance;
    return TokenDistribution.deployed().then(instance => {
      TokenDistributionInstance = instance;
      return TokenDistributionInstance.buy({from: creatorAddress, value: web3.toWei(1, 'ether')});
    }).then(result => {
      return TokenDistributionInstance.availableBalance.call();
    }).then(availableBalance => {
      console.log("avail bal: " + availableBalance);
      //assert.equal(availableBalance.valueOf(), 999, "999 wasn't the available TokenDistribution balance");

      // var buy = TokenDistributionInstance.Buy(
      //   { fromBlock: "latest" })
      //   .watch((error, value) => {
      //     if (error) {
      //       console.error(error);
      //     } else {
      //       console.log("------- tde event: ");
      //       console.log(value);
      //     }
      //   });  
    });
           
  });

  it("should contain 9199 FTT in the creator balance", () => {
    return FTToken.deployed().then(instance => {
      return instance.balanceOf.call(creatorAddress);
    }).then(balance => {
      assert.equal(balance.valueOf(), 9199, "9199 wasn't in the creator balance");
    });
  });

  it("should transfer 9199 FTT to the recipient address", () => {
    var TokenDistributionInstance;
    return TokenDistribution.deployed().then(instance => {
      TokenDistributionInstance = instance;
      return TokenDistributionInstance.buyFor(recipientAddress, {from: creatorAddress, value: web3.toWei(1, 'ether')});
    }).then(result => {
      return TokenDistributionInstance.availableBalance.call();
    }).then(availableBalance => {
      assert.equal(availableBalance.valueOf(), 599981602, "599981602 wasn't the available TokenDistribution balance");
    });
  });

  it("should contain 9199 FTToken in the recipient balance", () => {
    return FTToken.deployed().then(instance => {
      return instance.balanceOf.call(recipientAddress);
    }).then(balance => {
      console.log("recip bal: " + balance);
      assert.equal(balance.valueOf(), 9199, "9199 wasn't in the recipient balance");
    });
  });

});
