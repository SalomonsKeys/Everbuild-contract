// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IEverburn.sol";

contract Everbuild is ERC721Enumerable, Ownable {

    IEverburn private constant everburn = IEverburn(0xA500fA36631025BC45745c7de6aEB8B09715fd43);

    uint public price = 2000000000;// 2000 tokens
    uint public nftPriceUsingAVAX = 0.001 ether; // 1 AVAX = 1000 gwei
    address public devWallet = 0x18C78629D321f11A1cdcbbAf394C78eb29412A4b; 
    bool public acceptAVAX; // This will be used to enable/disable the ability to mint with AVAX. default is false.
    bool public whitelistMintEnabled;
    bool public publicMintEnabled;
    bool public royaltiesClaimedEnabled;
    uint public tokensToClaim;
    uint public royaltiesWithdrawalTimestamp;// This will hold the timestamp of when the dev can withdraw the royalties.
    uint public royaltiesWithdrawalDeadline = 30 days; // This is the time people have to claim their payouts before they will be sent to the dev wallet.
    uint public royaltiesTotalClaimed; // This will be used to keep track of the total amount of royalties claimed.
    uint public season = 1; // This will be used to keep track of the payout season.
    uint public MAX_PUBLIC_SUPPLY = 0; //350 max
    uint public MAX_WHITELIST_SUPPLY = 0; // 350 max
    uint public MAX_SUPPLY = 1400; 
    uint public PUBLIC_MAX_MINT = 30; 

    mapping(address => uint) public whitelistAmount; //This will be used to check how many tokens a whitelisted address can mint.
    mapping(address => uint) public _mintedTokens; // This will be used to prevent people from miting more than x for the public mint.
    // a mapping to keep tracking of the total amount of tokens people have claimed
    mapping(address => uint) public totalRoyaltiesClaimed;
    mapping(uint => mapping(address => uint)) public claimable;


    event RoyaltiesClaimed(address indexed _address, uint indexed _amount);
    event RoyaltiesWithdrawn(address indexed _address, uint indexed _amount);
    event WhitelistMintEnabledChanged(bool enabled);
    event PublicMintEnabledChanged(bool enabled);
    event RoyaltiesClaimedEnabledChanged(bool enabled);
    event Minted(address indexed _to, uint256 indexed _tokenId);


    constructor() ERC721("Everbuild", "EBLD") {}

    function mintMultiple(uint _amount, bool useAvax) external payable {
        require(publicMintEnabled == true, "Public mint is closed");
        require(_amount > 0, "You cannot mint 0 tokens");
        require((_mintedTokens[msg.sender] + _amount <= PUBLIC_MAX_MINT) || msg.sender == owner() , "Maximum tokens minted");
        require(MAX_PUBLIC_SUPPLY + _amount < 350, "Public Mint Max of 350 Reached");

        require(totalSupply() + _amount < MAX_SUPPLY, "ALL NFTs have been minted");

        if (useAvax) {
            require(acceptAVAX, "AVAX not accepted");
            uint avaxPrice = nftPriceUsingAVAX * _amount; // Convert to gwei, assuming 1 Everburn = 1 gwei
            require(msg.value >= avaxPrice, "Insufficient AVAX sent");
            payable(devWallet).transfer(avaxPrice);
        } else {
            require(everburn.balanceOf(msg.sender) >= price * _amount, "You have Insufficient Everburn");
            require(everburn.transferFrom(msg.sender, devWallet, price * _amount), "Transfer failed");
        }

        _mintedTokens[msg.sender] += _amount;

        for (uint i = 0; i < _amount; i++) {
            
            uint userTokenId = totalSupply() + 1;

            _safeMint(msg.sender, userTokenId);

            _safeMint(owner(), userTokenId + 1);

            emit Minted(msg.sender, userTokenId);

        }

        MAX_PUBLIC_SUPPLY += _amount;
    
    }

    function mintWithEverburn(uint _amount) external payable {
        require(whitelistMintEnabled == true, "whitelist is closed");
        require(_amount > 0, "You cannot mint 0 tokens");
        require(_amount <= whitelistAmount[msg.sender], "You have exceeded the amount of tokens you can mint");
        require(totalSupply() + _amount < MAX_SUPPLY, "ALL NFTs have been minted");
        require(MAX_WHITELIST_SUPPLY + _amount < 351, "Whitelist Mint Max of 350 Reached");

        whitelistAmount[msg.sender] -= _amount;

    
        for (uint i = 0; i < _amount; i++) {
            uint256 userTokenId = totalSupply() + 1;

            _safeMint(msg.sender, userTokenId);

            _safeMint(owner(), userTokenId + 1);

            emit Minted(msg.sender, userTokenId);
        }

        MAX_WHITELIST_SUPPLY += _amount;
    }

    function claimRoyalties() external {
       
        require(royaltiesClaimedEnabled == true, "Royalties claim is closed");
        uint availableToClaim = claimable[season][msg.sender];
        require(availableToClaim > 0, "Nothing to claim");
        require(everburn.balanceOf(address(this)) >= availableToClaim, "Not enough tokens to claim");
        
        // Since i recorded the amount of tokens the user has with availableToClaim up above, below we reset his claimable amount to 0
        claimable[season][msg.sender] = 0;
        tokensToClaim -= availableToClaim;

        
        everburn.transfer(msg.sender, availableToClaim);
        totalRoyaltiesClaimed[msg.sender] += availableToClaim;
        royaltiesTotalClaimed += availableToClaim;
        
        emit RoyaltiesClaimed(msg.sender, availableToClaim);
    }

    function setWhitelistSnapshot(address[] memory _addresses, uint[] memory _amounts, uint totalMints) external onlyOwner {
        require(_addresses.length == _amounts.length, "Lengths do not match, this means you have one more than the other");
        for(uint i = 0; i < _addresses.length; i++) {
            totalMints = totalMints - _amounts[i];
            whitelistAmount[_addresses[i]] = _amounts[i];
        }

        // This final check will make sure the total mints is equal to the sum of the amounts. If not it will revert everything.
        require(totalMints == 0, "The total mints did not match the sum of the amounts");
    }


    function setRoyaltieSnapshot(address[] memory recipients, uint[] memory amounts, uint totalTokens) external onlyOwner {
        require(recipients.length == amounts.length, "Lengths do not match, this means you have one more than the other");
        require(totalTokens <= everburn.balanceOf(address(this)), "You cannot claim more than the contract has");
        
        uint claimableTokens = totalTokens;
        // Here im checking if the total tokens is equal to the sum of the amounts
        for(uint i = 0; i < recipients.length; i++) {
            totalTokens -= amounts[i];
            claimable[season][recipients[i]] += amounts[i];
        }

        // This final check will make sure the total tokens is equal to the sum of the amounts and will revert everything if it is not
        require(totalTokens == 0, "The total tokens did not match the sum of the amounts");
        tokensToClaim = claimableTokens;
        royaltiesWithdrawalTimestamp = block.timestamp + royaltiesWithdrawalDeadline;
        
    }
    
    function withdrawUnclaimedRoyalties() external onlyOwner {
        require(block.timestamp >= royaltiesWithdrawalTimestamp, "Cannot withdraw yet");
        
        uint unclaimedRoyalties = tokensToClaim;
        // Transfer the unclaimed royalties to the owner
        everburn.transfer(devWallet, unclaimedRoyalties);
        tokensToClaim = 0;

        // Close the royalties claim for this season
        royaltiesClaimedEnabled = false;

        // Increase the season, effectively resetting the claimable mapping for the next round
        season++;


        emit RoyaltiesWithdrawn(owner(), unclaimedRoyalties);
    }

    
    function setEVBPrice(uint _price) external onlyOwner {
        price = _price;
    }

    function setAcceptAVAX(bool _acceptAvex) external onlyOwner {
        acceptAVAX = _acceptAvex;
    }

    function setNftPriceUsingAVAX(uint _newPrice) external onlyOwner {
        nftPriceUsingAVAX = _newPrice;
    }


    function addToWhitelist(address _address, uint _amount) external onlyOwner {
        whitelistAmount[_address] = _amount;
    }

    function setMaxPublicMint(uint _maxPM) external onlyOwner {
        require(_maxPM <= 30, "You cannot exceed 30 NFTs");
        PUBLIC_MAX_MINT = _maxPM;
    }

    function setMaxSupply(uint _maxSup) external onlyOwner {
        require(_maxSup <= 1400, "You cannot exceed 1400 NFTs");
        MAX_SUPPLY = _maxSup;
    }


    function setDevWallet(address _dev) external onlyOwner {
        devWallet = _dev;    
    }

    function setWhitelistMintEnabled() external onlyOwner {
        whitelistMintEnabled = !whitelistMintEnabled;
        emit WhitelistMintEnabledChanged(whitelistMintEnabled);

    }

    function setPublicMintEnabled() external onlyOwner {
        publicMintEnabled = !publicMintEnabled;
        emit PublicMintEnabledChanged(publicMintEnabled);

    }

    function setRoyaltiesClaimedEnabled() external onlyOwner {
        royaltiesClaimedEnabled = !royaltiesClaimedEnabled;
        emit RoyaltiesClaimedEnabledChanged(royaltiesClaimedEnabled);
    }

    function setRoyaltiesWithdrawalDeadline(uint _newDeadline) external onlyOwner {
        royaltiesWithdrawalDeadline = _newDeadline;
    }



    //**************** Transfer everburn tokens and check balance *********************
    function transferTokens(address _to, uint _amount) external onlyOwner {
        require(everburn.balanceOf(address(this)) >= _amount, "Insufficient Everburn balance");
        everburn.transfer(_to, _amount);
    }


    //*********************************************************************************

    //*********** The following functions are overrides required by Solidity ******************
    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://QmQYMEDgYkj4mLgJubUrq2GwYR4NfgwxgPWsGsmm9KNFdw?filename=0&ID=";
    }
    //*******************************************************************************************

 

    function withdraw(address payable _to) external onlyOwner {
        _to.transfer(address(this).balance);
    }

    // Emergency function to reset all unclaimed royalties
    function emergencyReset() external onlyOwner {
        // Increase the season number, invalidating all unclaimed royalties for the previous season
        season++;
    }

    // Reset and set the claimable amount for a specific address in the current season
    function setClaimableForAddress(address _address, uint _newAmount) external onlyOwner {
        tokensToClaim -= claimable[season][_address]; // deduct the claimable amount of this address from total claimable
        claimable[season][_address] = _newAmount; // set the claimable amount to the new amount
        tokensToClaim += _newAmount; // add the new claimable amount to total claimable
    }


}
