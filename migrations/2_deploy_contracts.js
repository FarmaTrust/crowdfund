let SafeMath = artifacts.require('SafeMath.sol');
let FTT = artifacts.require('FTT.sol');

module.exports = function(deployer) {
  deployer.deploy(SafeMath);
  deployer.link(SafeMath, FTT);
  deployer.deploy(FTT)
    .then(() => {
      return FTT.deployed()
        .then((ftt) => {
          console.log(" *** deployed ftt address is: " + ftt.address + " **** ");
        });
    });
};