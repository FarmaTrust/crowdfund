var FTToken = artifacts.require("./FTToken.sol");

contract('FTToken', (accounts) => {

  var creatorAddress = accounts[0];
  var farmaTrustDeposit = accounts[1];
  var recipientAddress = accounts[2];
  var delegatedAddress = accounts[3];

  it("should contain expected FTToken totalSupply of 1000000000", () => {
    return FTToken.deployed().then((instance) => {
      return instance.totalSupply.call();
    }).then(balance => {
      assert.equal(balance.valueOf(), 1000000000, "1000000000 FTToken are not in supply");
    });
  });

  it("should contain 600000000 FTToken in the creator balance", () => {
    return FTToken.deployed().then(instance => {
      return instance.balanceOf.call(creatorAddress);
    }).then(balance => {
      assert.equal(balance.valueOf(), 600000000, "600000000 wasn't in the creator balance");
    });
  });

  it("should transfer 1000 FTToken to the recipient balance", () => {
    var FTTokenInstance;
    return FTToken.deployed().then(instance => {
      FTTokenInstance = instance;
      return FTTokenInstance.transfer(recipientAddress, 1000, {from: creatorAddress});
    }).then(result => {
      return FTTokenInstance.balanceOf.call(recipientAddress);
    }).then(recipientBalance => {
      assert.equal(recipientBalance.valueOf(), 1000, "1000 wasn't in the recipient balance");
      return FTTokenInstance.balanceOf.call(creatorAddress);
    }).then(creatorBalance => {
      assert.equal(creatorBalance.valueOf(), 599999000, "9000 wasn't in the creator balance");
    });
  });

  it("should approve 500 FTToken to the delegated balance", () => {
    var FTTokenInstance;
    return FTToken.deployed().then(instance => {
      FTTokenInstance = instance;
      return FTTokenInstance.approve(delegatedAddress, 500, {from: creatorAddress});
    }).then(result => {
      return FTTokenInstance.allowance.call(creatorAddress, delegatedAddress);
    }).then(delegatedAllowance => {
      assert.equal(delegatedAllowance.valueOf(), 500, "500 wasn't approved to the delegated balance");
    });
  });

  it("should transfer 200 FTToken from the creator to the alt recipient via the delegated address", () => {
    var FTTokenInstance;
    return FTToken.deployed().then(instance => {
      FTTokenInstance = instance;
      return FTTokenInstance.transferFrom(creatorAddress, recipientAddress, 200, {from: delegatedAddress});
    }).then(result => {
      return FTTokenInstance.balanceOf.call(recipientAddress);
    }).then(recipientBalance => {
      assert.equal(recipientBalance.valueOf(), 1200, "1200 wasn't in the recipient balance");
      return FTTokenInstance.allowance.call(creatorAddress, delegatedAddress);
    }).then(delegatedAllowance => {
      assert.equal(delegatedAllowance.valueOf(), 300, "300 wasn't set as the delegated balance");
    });
  });

});
