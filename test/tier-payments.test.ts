import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("TierPayments", function () {

  // Creamos un Fixture para los tests.
  async function deployTierPaymentContract() {

    // owner cuenta dueña y otherAccount para testear los OnlyOwners/
    const [owner, otherAccount, addr2, addr3, addr4, addr5] = await ethers.getSigners();

    const TierPayment = await ethers.getContractFactory("TierPayment");
    const tierPayment = await TierPayment.deploy();

    return { tierPayment, owner, otherAccount, addr2, addr3, addr4, addr5 };
  }

  describe("Tests related Tiers: ", function () {
    it("Checking Tier 1, 2 or 3 and Should return walletsArray.length 0 and quantity 0", async function () {

      const { tierPayment} = await loadFixture(deployTierPaymentContract);
      const [walletArray, quantity] = await tierPayment.checkTierMembers(1);
      expect(quantity).to.be.equal(ethers.BigNumber.from(0));
      expect(walletArray.length).to.be.equal(0);
    });
    
    it("Checking Tier N Should return Tier must be 1, 2 or 3", async function () {

      const { tierPayment } = await loadFixture(deployTierPaymentContract);
      await expect(tierPayment.checkTierMembers(4)).to.be.revertedWith(
        "Tier must be 1, 2 or 3"
      );
    });

    it("Should Tier percentage be Tier 1 = 20%, Tier2 = 20%, Tier3 = 40%", async function () {

      const { tierPayment } = await loadFixture(deployTierPaymentContract);
      expect(await tierPayment.TierPercentage(1)).to.equal(20);
      expect(await tierPayment.TierPercentage(2)).to.equal(20);
      expect(await tierPayment.TierPercentage(3)).to.equal(40);
    });

    it("Should add a wallet into the Tier1 ", async function () {

      const { tierPayment, otherAccount } = await loadFixture(deployTierPaymentContract);
      await tierPayment.addWalletToAnSpecificTier(1, otherAccount.address);
      const [walletArray, quantity] = await tierPayment.checkTierMembers(1);
      expect(walletArray[0]).to.equal(otherAccount.address);
      expect(quantity).to.equal(1);

    })

    it("Should reject add a wallet if already exist on another Tier", async function () {

      const { tierPayment, otherAccount } = await loadFixture(deployTierPaymentContract);
      await tierPayment.addWalletToAnSpecificTier(1, otherAccount.address);
      await expect(tierPayment.addWalletToAnSpecificTier(2, otherAccount.address)).to.be.revertedWith("This wallet exist in 1 of our tiers");
    })

    it("Should return ReturnTiers Struct", async function () {
      const { tierPayment, otherAccount,addr2,addr3, addr4, addr5 } = await loadFixture(deployTierPaymentContract);
      
      await tierPayment.addWalletToAnSpecificTier(1, otherAccount.address);
      await tierPayment.addWalletToAnSpecificTier(2, addr2.address);
      await tierPayment.addWalletToAnSpecificTier(1, addr3.address);
      await tierPayment.addWalletToAnSpecificTier(3, addr4.address);
      await tierPayment.addWalletToAnSpecificTier(3, addr5.address);
      const [
        MembersT1,
        MembersCountT1,
        MembersT2,
        MembersCountT2,
        MembersT3,
        MembersCountT3
      ] = await tierPayment.checkAllTiers();
      expect(MembersT1.toString()).to.equal(
        `${otherAccount.address},${addr3.address}` 
      );
      expect(MembersT2.toString()).to.equal(
        addr2.address 
      );
      expect(MembersT3.toString()).to.equal(
         `${addr4.address},${addr5.address}` 
      );
      expect(MembersCountT1).to.equal(MembersT1.length);
      expect(MembersCountT2).to.equal(MembersT2.length);
      expect(MembersCountT3).to.equal(MembersT3.length);

    });
  });

  // TODO describe Paylemnt Tests.
});

