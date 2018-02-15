
const { getEventSignature, assertRejects, delay } = require('./utils.js');
const addEvmFunctions = require('./evmFunctions.js'); 
const Promise = require("bluebird"); 

var FTT = artifacts.require("./FTT.sol");
var TV  = artifacts.require("./TokenVesting.sol");

contract("FTT", async (accounts) => {
    
    addEvmFunctions(web3);
    Promise.promisifyAll(web3.eth, { suffix: "Promise" });
    Promise.promisifyAll(web3.version, { suffix: "Promise" });
    Promise.promisifyAll(web3.evm, { suffix: "Promise" });

    let ftt; 
    var owner = accounts[0]; 
    var tdeIssuer = accounts[1];
    var operationalReserveAddress = accounts[2]; 
    var contributorOne = accounts[3];
    var contributorTwo = accounts[4]; 
    var contributorThree = accounts[5];

    // 18 decimals
    var expectedTotalSupply = web3.toBigNumber('1000000000000000000000000000');
    var expectedTokenSaleCap = web3.toBigNumber('600000000000000000000000000'); 
    var expectedftTeamFund = web3.toBigNumber('40000000000000000000000000');    
    var expectedftOperationalFund = web3.toBigNumber('400000000000000000000000000');
    
    // 8 decimals
    // var expectedTotalSupply = web3.toBigNumber('100000000000000000');
    // var expectedTokenSaleCap = web3.toBigNumber('60000000000000000'); 
    // var expectedftTeamFund = web3.toBigNumber('4000000000000000');    
    // var expectedftOperationalFund = web3.toBigNumber('40000000000000000');    

    let isTestRPC;

    beforeEach("Prepare test", async () => {
        var node = await web3.version.getNodePromise(); 
        isTestRPC = node.indexOf("EthereumJS TestRPC") >= 0;         
        ftt = await FTT.new({from: owner });
    });

    it("Should return the correct totalSupply value", async () => {
        var totalSupply = await ftt.totalSupply.call(); 
        assert.equal(totalSupply.toString(10), expectedTotalSupply.toString(10));
    });

    it("Should return the correct FT_TOKEN_SALE_CAP", async () => {  
        var ftTokenSaleCap = await ftt.FT_TOKEN_SALE_CAP.call(); 
        assert.equal(ftTokenSaleCap.toString(10), expectedTokenSaleCap.toString(10));
    });    

    it("Should return the correct FT_OPERATIONAL_FUND amount", async() => {
        var ftOperationalFund = await ftt.FT_OPERATIONAL_FUND.call(); 
        assert.equal(ftOperationalFund.toString(10), expectedftOperationalFund.toString(10));
    });

    it("Should return the correct FT_TEAM_FUND amount", async() => {
        var ftTeamFund = await ftt.FT_TEAM_FUND.call(); 
        assert.equal(ftTeamFund.toString(10), expectedftTeamFund.toString(10));
    });    

    it("TDE should not be active", async() => {
        tdeActive = await ftt.tdeActive.call(); 
        assert.isFalse(tdeActive);
    }); 

    it("Should not be possible to finalize TDE before it has started.", async() => {
        assertRejects(ftt.finalize({ from: owner }), 
        "Should not bepossible to finalize TDE before it has started.");
    });

    it("Should not be possible to invoke critical TDE events before it has started.", async() => {
        assertRejects(ftt.setOperationalReserveAddress(operationalReserveAddress, { from: owner }), 
        "Should not bepossible to set operational reserve address before TDE has started.");

        assertRejects(ftt.issueFTT(contributorOne, 100000000000, { from: owner }), 
        "Should not bepossible to issue FTT before TDE has started.");        
    });

    it("FTT issued should equal zero before TDE starts", async() => {
        var fttIssued = await ftt.fttIssued.call(); 
        assert.equal(fttIssued, 0);
    }); 

    it("Should perform end-to-end TDE workflow without failure - token sale cap reached.", async() => {

        var tdeActive = await ftt.tdeActive.call();
        var tdeStartTime = await ftt.tdeStartTime.call(); 
        var tdeDuration = await ftt.tdeDuration.call(); 
        var teamVestingAddress = await ftt.teamVestingAddress.call();
        var tdeStarted = await ftt.tdeStarted.call(); 

        var expectedTdeDuration = 5184000; // 60 days

        assert.isFalse(tdeActive); 
        assert.equal(tdeStartTime, 0); 
        assert.equal(tdeDuration, expectedTdeDuration); 

        // await delay((60) * 1000);
        // await web3.evm.increaseTimePromise(60 * 1000);

        assert.equal(teamVestingAddress, 0x0); 
        assert.isFalse(tdeStarted); 

        // start TDE 
        var txObj = await ftt.startTde({from: owner});

        tdeActive = await ftt.tdeActive.call();
        tdeStartTime = await ftt.tdeStartTime.call(); 
        tdeDuration = await ftt.tdeDuration.call(); 
        tdeStarted = await ftt.tdeStarted.call();      
        
        assert.isTrue(tdeActive); 
        assert.isTrue(tdeStarted);
        assert.isTrue(tdeStartTime > 0); 
        
        // set TDE issuer 
        await ftt.setTdeIssuer(tdeIssuer, {from: owner});

        // Ensure that TDE issuer is set correctly.
        var setTdeIssuer = await ftt.tdeIssuer.call(); 
        assert.equal(setTdeIssuer, tdeIssuer);

        // Issue tokens to contributor
        var txObj = await ftt.issueFTT(contributorOne, 50000000000001, {from: tdeIssuer});
        
        var balanceOfContributorOne = await ftt.balanceOf(contributorOne); 
        assert.equal(balanceOfContributorOne, 50000000000001, "Incorrect contributorOne balance"); 

        // Issue FTT to contributor two 
        var txObj = await ftt.issueFTT(contributorTwo, 50000000000002, {from: tdeIssuer});
        
        var balanceOfContributorTwo = await ftt.balanceOf(contributorTwo);
        assert.equal(balanceOfContributorTwo, 50000000000002, "Incorrect contributorTwo balance");

        // Attempt to issue hard cap amount 
        assertRejects(ftt.issueFTT(contributorThree, expectedTokenSaleCap.toString(), {from: tdeIssuer}), 
             "Should not bepossible to issue FTT tokenSaleCap at this point");           

        var fttIssued = await ftt.fttIssued.call(); 
        var contributorTotal = balanceOfContributorOne.plus(balanceOfContributorTwo); 

        assert.equal(fttIssued, contributorTotal.toString(10)); 

        // Contributor one transfers to contributor two 
        await ftt.transfer(contributorTwo, balanceOfContributorOne.toString(10), {from:contributorOne});
        assert.equal(await ftt.balanceOf(contributorTwo), contributorTotal.toString(10));
        assert.equal(await ftt.balanceOf(contributorOne), 0);

        var remainingSupply = expectedTokenSaleCap.minus(fttIssued); 

        // Issue the remaining supply so that cap is reached. 
        var txObj = await ftt.issueFTT(contributorThree, remainingSupply.toString(10), {from: tdeIssuer});

        assert.isTrue(await ftt.capReached.call());

        // Ensure that operational reserve address is set 
        await ftt.setOperationalReserveAddress(operationalReserveAddress, {from: owner}); 
        assert.equal(await ftt.operationalReserveAddress.call(), operationalReserveAddress);

        // End the TDE 
        await ftt.stopTde(false, {from: owner}); 
        tdeActive = await ftt.tdeActive.call();
        assert.isFalse(tdeActive);

        // Finalize the TDE 
        await ftt.finalize({from: owner}); 
        assert.isTrue(await ftt.isFinalized.call());
                
        var teamVestingAddress = await ftt.teamVestingAddress.call(); 
        var unsoldVestingAddress = await ftt.unsoldVestingAddress.call();

        // Check the operational reserve balance
        var opReserveBalance = await ftt.balanceOf(operationalReserveAddress); 
        assert.equal(opReserveBalance.toString(10), expectedftOperationalFund.minus(expectedftTeamFund).toString(10));

        // Verify the team balance in vesting contract. 
        var teamVestingBalance = await ftt.balanceOf(teamVestingAddress); 
        assert.equal(teamVestingBalance.toString(10), expectedftTeamFund.toString(10), "Team vesting balance should equal: " + expectedftTeamFund.toString(10));
        
        // Revoke funds from team TokenVesting
        tv = await TV.at(teamVestingAddress); 
        await tv.revoke(ftt.address);
        var ownerBalance = await ftt.balanceOf(owner);
        assert.equal(ownerBalance.toString(10), expectedftTeamFund.toString(10), "Owner should now hold team allocation.");
    });

    it("Should perform end-to-end TDE workflow without failure - TDE period elapsed.", async() => {

        var tdeActive = await ftt.tdeActive.call();
        var tdeStartTime = await ftt.tdeStartTime.call(); 
        var tdeDuration = await ftt.tdeDuration.call(); 
        var teamVestingAddress = await ftt.teamVestingAddress.call();
        var tdeStarted = await ftt.tdeStarted.call(); 

        var expectedTdeDuration = 5184000; // 60 days

        assert.isFalse(tdeActive); 
        assert.equal(tdeStartTime, 0); 
        assert.equal(tdeDuration, expectedTdeDuration); 

        assert.equal(teamVestingAddress, 0x0); 
        assert.isFalse(tdeStarted); 

        // start TDE 
        var txObj = await ftt.startTde({from: owner});

        tdeActive = await ftt.tdeActive.call();
        tdeStartTime = await ftt.tdeStartTime.call(); 
        tdeDuration = await ftt.tdeDuration.call(); 
        tdeStarted = await ftt.tdeStarted.call();      
        
        assert.isTrue(tdeActive); 
        assert.isTrue(tdeStarted);
        assert.isTrue(tdeStartTime > 0); 
        
        // set TDE issuer 
        await ftt.setTdeIssuer(tdeIssuer, {from: owner});

        // Ensure that TDE issuer is set correctly.
        var setTdeIssuer = await ftt.tdeIssuer.call(); 
        assert.equal(setTdeIssuer, tdeIssuer);

        console.log('Reducing TDE period'); 
        // Reduce TDE period to 60 seconds.
        await ftt.shortenTde(5183940,{from: owner});
        assert.equal(await ftt.tdeDuration.call(), 60, "New TDE duration should be 60 seconds."); 

        // Issue tokens to contributor
        var txObj = await ftt.issueFTT(contributorOne, 50000000000001, {from: tdeIssuer});
        
        var balanceOfContributorOne = await ftt.balanceOf(contributorOne); 
        assert.equal(balanceOfContributorOne, 50000000000001, "Incorrect contributorOne balance"); 

        // Issue FTT to contributor two 
        var txObj = await ftt.issueFTT(contributorTwo, 50000000000002, {from: tdeIssuer});
        
        var balanceOfContributorTwo = await ftt.balanceOf(contributorTwo);
        assert.equal(balanceOfContributorTwo, 50000000000002, "Incorrect contributorTwo balance");

        // Attempt to issue hard cap amount 
        assertRejects(ftt.issueFTT(contributorThree, expectedTokenSaleCap.toString(), {from: tdeIssuer}), 
             "Should not bepossible to issue FTT tokenSaleCap at this point");           

        var fttIssued = await ftt.fttIssued.call(); 
        var contributorTotal = balanceOfContributorOne.plus(balanceOfContributorTwo); 

        assert.equal(fttIssued, contributorTotal.toString(10)); 

        // Contributor one transfers to contributor two 
        await ftt.transfer(contributorTwo, balanceOfContributorOne.toString(10), {from:contributorOne});
        assert.equal(await ftt.balanceOf(contributorTwo), contributorTotal.toString(10));
        assert.equal(await ftt.balanceOf(contributorOne), 0);

        var remainingSupply = expectedTokenSaleCap.minus(fttIssued); 

        // // Issue the remaining supply so that cap is reached. 
        // var txObj = await ftt.issueFTT(contributorThree, remainingSupply.toString(10), {from: tdeIssuer});
        // assert.isTrue(await ftt.capReached.call());

        // Ensure that operational reserve address is set 
        await ftt.setOperationalReserveAddress(operationalReserveAddress, {from: owner}); 
        assert.equal(await ftt.operationalReserveAddress.call(), operationalReserveAddress);

        // Force TDE period to elapse through delay
        var forcedDelayInSeconds = 80; 
        console.log(`Force TDE period to elapse through delay... (${forcedDelayInSeconds} seconds)`); 
        await delay((forcedDelayInSeconds) * 1000);
        console.log(`Delay ended.`);
        assert.equal(fttIssued, contributorTotal.toString(10));

        // End the TDE 
        await ftt.stopTde(false, {from: owner}); 
        tdeActive = await ftt.tdeActive.call();
        assert.isFalse(tdeActive);

        // Finalize the TDE 
        await ftt.finalize({from: owner}); 
        assert.isTrue(await ftt.isFinalized.call());
                
        var teamVestingAddress = await ftt.teamVestingAddress.call(); 
        var unsoldVestingAddress = await ftt.unsoldVestingAddress.call();

        // Check the operational reserve balance
        var opReserveBalance = await ftt.balanceOf(operationalReserveAddress); 
        assert.equal(opReserveBalance.toString(10), expectedftOperationalFund.minus(expectedftTeamFund).toString(10));

        // Verify the team balance in team vesting contract. 
        var teamVestingBalance = await ftt.balanceOf(teamVestingAddress); 
        assert.equal(teamVestingBalance.toString(10), expectedftTeamFund.toString(10), "Team vesting balance should equal: " + expectedftTeamFund.toString(10));
        
        // Verify the unsold balance in the unsold vesting contract
        var unsoldVestingBalance = await ftt.balanceOf(unsoldVestingAddress); 
        assert.equal(expectedTokenSaleCap.minus(contributorTotal).toString(10), unsoldVestingBalance.toString(10))

        // Test revocation of team TokenVesting
        var tvt = await TV.at(teamVestingAddress); 
        await tvt.revoke(ftt.address, {from: owner});
        var ownerBalance = await ftt.balanceOf(owner);
        assert.equal(ownerBalance.toString(10), expectedftTeamFund.toString(10), "Owner should now hold team allocation.");

        // Test revocation of unsold TokenVesting 
        var tvu = await TV.at(unsoldVestingAddress); 
        await tvu.revoke(ftt.address, {from: owner}); 
        var ownerBalanceWithTVU = await ftt.balanceOf(owner);

        var teamAndUnsoldVestingBalance = teamVestingBalance.plus(unsoldVestingBalance);          
        assert.equal(ownerBalanceWithTVU.toString(10), teamAndUnsoldVestingBalance.toString(10));
    });    
 
});
