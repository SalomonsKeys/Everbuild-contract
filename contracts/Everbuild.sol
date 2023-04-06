// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IEverburn.sol";

contract Everbuild is ERC721Enumerable, Ownable {
    constructor() ERC721("Everbuild", "EBLD") {}

    event RoyaltiesClaimed(address indexed _address, uint indexed _amount);
    event RoyaltiesWithdrawn(address indexed _address, uint indexed _amount);
    
    event WhitelistMintEnabledChanged(bool enabled);
    event PublicMintEnabledChanged(bool enabled);
    event RoyaltiesClaimedEnabledChanged(bool enabled);
    event Minted(address indexed _to, uint256 indexed _tokenId);




    uint public price = 2000000000;// 20000 tokens
    bool public whitelistMintEnabled;
    bool public publicMintEnabled;
    bool public royaltiesClaimedEnabled;
    uint public tokensToClaim; // We can use this variable to be displayd to show how many tokens are left to claim on the website.
    uint public royaltiesWithdrawalTimestamp; // This will be used to set the time when the royalties can be withdrawn.

    //********************** Mappings && Arrays ************************************
    address[] public claimableAddresses; // This will be used to store the addresses of the people who can claim their tokens.
    mapping(address => uint) public claimable; // This will be used to store the amount of tokens a user can claim.
    mapping(address => uint) public whitelistAmount; //This will be used to check how many tokens a whitelisted address can mint.
    mapping(address => uint) public _mintedTokens; // This will be used to prevent people from miting more than x for the public mint.
    // a mapping to keep tracking of the total amount of tokens people have claimed
    mapping(address => uint) public totalRoyaltiesClaimed;
    //*********************************************************************


    //********************** Constants ************************************
    IEverburn private constant everburn = IEverburn(0xA500fA36631025BC45745c7de6aEB8B09715fd43);
    uint public constant MAX_SUPPLY = 12; 
    uint public constant PUBLIC_MAX_MINT = 2; //Amount of tokens to be distributed, we can change this to a global variable if we want to change the amount of tokens to be distributed.
    address public constant devWallet = 0x18C78629D321f11A1cdcbbAf394C78eb29412A4b; //This is the address of the dev wallet. It will hold the everburn tokens.
    uint constant ROYALTIES_WITHDRAWAL_DEADLINE = 30 days; // This is the time people have to claim their payouts before they will be sent to the dev wallet.

    //*********************************************************************




    //********************** Minting Functions ****************************
    function mintMultiple(uint _amount, bool useAvax) public payable {
    require(publicMintEnabled == true, "Public mint is closed");
    require(_amount > 0, "You cannot mint 0 tokens");
    require((_mintedTokens[msg.sender] + _amount <= PUBLIC_MAX_MINT) || msg.sender == owner() , "Maximum tokens minted");

    require(totalSupply() + _amount < MAX_SUPPLY, "ALL NFTs have been minted");

    if (useAvax) {
        uint avaxPrice = price * _amount * 10**9; // Convert to gwei, assuming 1 Everburn = 1 gwei
        require(msg.value >= avaxPrice, "Insufficient AVAX sent");
        payable(devWallet).transfer(avaxPrice);
    } else {
        require(everburn.balanceOf(msg.sender) >= price * _amount, "You have Insufficient Everburn");
        require(everburn.transferFrom(msg.sender, devWallet, price * _amount), "Transfer failed");
    }

    _mintedTokens[msg.sender] += _amount;

    for (uint i = 0; i < _amount; i++) {
        uint userTokenId = totalSupply() + 1;

        _safeMint(msg.sender, totalSupply() + 1);
        _safeMint(owner(), totalSupply() + 1);

        emit Minted(msg.sender, userTokenId);

    }
}


    
    function mintWithEverburn(uint _amount) public payable {
        require(whitelistMintEnabled == true, "whitelist is closed");
        require(_amount > 0, "You cannot mint 0 tokens");
        require(_amount <= whitelistAmount[msg.sender], "You have exceeded the amount of tokens you can mint");
        require(totalSupply() + _amount < MAX_SUPPLY, "ALL NFTs have been minted");
        
        whitelistAmount[msg.sender] -= _amount;

    
        for (uint i = 0; i < _amount; i++) {
            uint256 userTokenId = totalSupply() + 1;

            _safeMint(msg.sender, totalSupply() + 1);
            _safeMint(owner(), totalSupply() + 1);

            emit Minted(msg.sender, userTokenId);
        }

    }


    

//*********************************************************************




//************* Global Variable Setters ********************************
    
        function setPrice(uint _price) external onlyOwner {
            price = _price;
        }


        function addToWhitelist(address _address, uint _amount) external onlyOwner {
            whitelistAmount[_address] = _amount;
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
    
       
//*********************************************************************


//******* Set whitelist addresses and amount of nfts they can mint **************************

    function setWhitelistSnapshot(address[] memory _addresses, uint[] memory _amounts, uint totalMints) external onlyOwner {
        require(_addresses.length == _amounts.length, "Lengths do not match, this means you have one more than the other");
        for(uint i = 0; i < _addresses.length; i++) {
            totalMints = totalMints - _amounts[i];
            whitelistAmount[_addresses[i]] = _amounts[i];
        }

        // This final check will make sure the total mints is equal to the sum of the amounts. If not it will revert everything.
        require(totalMints == 0, "The total mints did not match the sum of the amounts");
    }

//*******************************************************************************************


 //********************** Payment Distributions ************************
    function setRoyaltieSnapshot(address[] memory recipients, uint[] memory amounts, uint totalTokens) external onlyOwner {
        require(recipients.length == amounts.length, "Lengths do not match, this means you have one more than the other");
        uint claimableTokens = totalTokens;
        claimableAddresses = new address[](0); // This will reset the array so we can use it again.
        // Here im checking if the total tokens is equal to the sum of the amounts
        for(uint i = 0; i < recipients.length; i++) {
            totalTokens -= amounts[i];
            claimable[recipients[i]] += amounts[i];
            claimableAddresses.push(recipients[i]);
        }

        // This final check will make sure the total tokens is equal to the sum of the amounts and will revert everything if it is not
        require(totalTokens == 0, "The total tokens did not match the sum of the amounts");
        tokensToClaim = claimableTokens;
        royaltiesWithdrawalTimestamp = block.timestamp + ROYALTIES_WITHDRAWAL_DEADLINE;
        
    }
        
    function claimRoyalties() external {
       
        require(royaltiesClaimedEnabled == true, "Royalties claim is closed");
        uint availableToClaim = claimable[msg.sender];
        require(availableToClaim > 0, "Nothing to claim");
        require(everburn.balanceOf(address(this)) >= availableToClaim, "Not enough tokens to claim");
        
        // Since i recorded the amount of tokens the user has with availableToClaim up above, below we reset his claimable amount to 0
        claimable[msg.sender] = 0;
        tokensToClaim -= availableToClaim;

        
        everburn.transfer(msg.sender, availableToClaim);
        totalRoyaltiesClaimed[msg.sender] += availableToClaim;
        
        emit RoyaltiesClaimed(msg.sender, availableToClaim);
    }

    //**This is a gas expensive loop since we are looping through the array and updating. Reinitialize the array with claimableAddresses = new address[](0); just like in the set royalties function  */
    function withdrawUnclaimedRoyalties() external onlyOwner {
        require(block.timestamp >= royaltiesWithdrawalTimestamp, "Cannot withdraw yet");
        
        uint unclaimedRoyalties = tokensToClaim;
        // Transfer the unclaimed royalties to the owner
        everburn.transfer(devWallet, unclaimedRoyalties);
        tokensToClaim = 0;

        // Update the claimable mapping for all users who had claimable royalties
        for (uint i = 0; i < claimableAddresses.length; i++) {
            address recipient = claimableAddresses[i];
            if (claimable[recipient] > 0) {
                claimable[recipient] = 0;
            }
        }

        emit RoyaltiesWithdrawn(owner(), unclaimedRoyalties);
    }

    //*********************************************************************






    //**************** Transfer everburn tokens and check balance *********************
    function transferTokens(address _to, uint _amount) external onlyOwner {
        require(everburn.balanceOf(address(this)) >= _amount, "Insufficient Everburn balance");
        everburn.transfer(_to, _amount);
    }


    //*********************************************************************************

    //*********** The following functions are overrides required by Solidity ******************
    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://{ipfs url here}/";
    }
    //*******************************************************************************************

    function getClaimableAddresses() public view returns (address[] memory) {
    return claimableAddresses;
}



    function withdraw(address payable _to) external onlyOwner {
        _to.transfer(address(this).balance);
    }



}
