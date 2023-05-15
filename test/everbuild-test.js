const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");
const {ethers} = require("hardhat");

describe("Everbuild", function () {
    async function deployEverBuild() {
        const [owner, addr1, addr2] = await ethers.getSigners();

        // Convert 0.001 Ether to Wei and pass it as a second argument to deploy()
        // const priceEtherInWei = ethers.utils.parseEther("0.001");
        
        const EverBuild = await ethers.getContractFactory("Everbuild");
        const everBuild = await EverBuild.deploy();
        await everBuild.deployed();
        return { everBuild, owner, addr1, addr2 };
    }

    it("Should mint multiple tokens using AVAX", async function () {
        const { everBuild, owner} = await loadFixture(deployEverBuild);

        // !important: When testing owner, remember that owner is the deployer and for every mint the owner will receive 1 token. So if 5 tokens are minted, the owner will have 10 tokens.
        const amountToMint = 5;
        const amountToMintWithOwner = amountToMint * 2;
        const pricePerToken = await everBuild.nftPriceUsingAVAX();

        // We will enable the public mint
        // And we will enable payments using AVAX
        await everBuild.connect(owner).setPublicMintEnabled();
        await everBuild.connect(owner).setAcceptAVAX(true);

        // We calculate the total amount of AVAX required to mint
        const totalAVAXRequired = pricePerToken.mul(amountToMint);

        // NFT Balance of the owner before minting.
        const initialBalance = await everBuild.balanceOf(owner.address);

        // We mint the tokens
        await everBuild.connect(owner).mintMultiple(amountToMint, true, { value: totalAVAXRequired });

        // NFT Balance of the owner after minting.
        const finalBalance = await everBuild.balanceOf(owner.address);

        // We check that the balance has increased by the amount minted
        expect(finalBalance).to.equal(initialBalance.add(amountToMintWithOwner));

        // // Check that the "minted" event was emitted
        // const eventFilter = everbuild.filters.Minted(owner.address, null);
        // const events = await everbuild.queryFilter(eventFilter);

        // // Assert that the event was emitted
        // expect(events.length).to.equal(amountToMint);

    });

    it("Should fail when trying to mint with insufficient funds", async function() {
        const { everBuild, owner} = await loadFixture(deployEverBuild);

        // We will enable the public mint
        // And we will enable payments using AVAX
        await everBuild.connect(owner).setPublicMintEnabled();
        await everBuild.connect(owner).setAcceptAVAX(true);

        const amountToMint = 5;  // or whatever amount that addr1 can't afford
        const insufficientFunds = ethers.utils.parseEther("0.0001");  // or whatever amount that addr1 can't afford
        await expect(
            everBuild.connect(owner).mintMultiple(amountToMint, true, { value: insufficientFunds}) // Assume 0.0001 AVAX is not enough
        ).to.be.revertedWith("Insufficient AVAX sent");  // Use the exact error message that your contract throws
    });
});