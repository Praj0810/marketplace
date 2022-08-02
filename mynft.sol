// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MyNFT is ERC721{
    //event emitted when NFT owner start bidding auction
    event BidStarted(address indexed nftOwner, uint256 _nftId, string _name);
    // Struct of NFt items details
    struct nftDetails {
        string name;
        uint256 nftId;
        address payable presentOwner; 
        address payable oldOwner;
        uint256 minPrice; 
        uint32 mintTime; 
        uint32 auctionTime;
        uint32 auctionEndsAt;
        bool tokenIdExist;  
        bool auctionStarted;
    }
    //Struct of NFT highest bidder
    struct Bidding{
        uint  highestBidAmt;
        address payable highestBidder;
    }
    // owner of NFT marketplace contract 
    address  public marketplaceOwner;
    //mapping tokenId with NFT deatils
    mapping(uint => nftDetails) public nftItems;
    //mapping tokenId with Nft highest bidder  
    mapping(uint => Bidding) public highestBidders;
    //mapping tokenId => bidder address => bidderfunds
    mapping(uint => mapping(address => uint)) public fundedbids;
    //Nft market tokenId
    uint public tokenId;
     /**
     * @dev Deployer deploy contract
     *
     * Requierments
     * @param _name - Deployer have to pass Market Place name.
     * @param _symbol - Deployer have to pass Market Place symbol.
     */
    constructor(string memory _name, string memory _symbol) 
        ERC721(_name, _symbol)
    {
        marketplaceOwner = msg.sender;
    }
    //modifiers:
    //Auction to be started only By NFT(_nftId) owner
    modifier auctionStartAcess(uint256 _nftId){
        nftDetails memory _nftDetails = nftItems[_nftId];
        require(_nftDetails.auctionStarted, "Auction not yet started");
        _;
    }
    //msg.sender should be owner of NFT(_nftId):
    modifier onlyNFtOwner(uint256 _nftId){
        nftDetails memory _nftDetails = nftItems[_nftId];
        require(msg.sender == _nftDetails.presentOwner, "Access by NFT owner only");
        _;
    }
    //msg.sender should not Bid in the NFt(_nftid) auction
    modifier notNftOwner(uint256 _nftId) {
        nftDetails memory _nftDetails = nftItems[_nftId];
        require(msg.sender != _nftDetails.presentOwner, " Latest NFT owner cannot bid ");
        _;
    }
    //check for token Id existence
    modifier nftItemExists(uint256 _nftId){
        nftDetails memory _nftDetails = nftItems[_nftId];
        require(_nftDetails.tokenIdExist , "Token does not exist");
        _;
    }
    //check for Minimum amount to be paid for bidding
    modifier minBidamount(uint256 _nftId){
        nftDetails memory _nftDetails = nftItems[_nftId];
        require(msg.value > _nftDetails.minPrice , "Bid amount is less than minBid amount");
        _;
    }
    /**
     * @dev user can mint their Nft
     * @param _name - User have to pass name for their NFT art item 
     */
    function mintNft(string memory _name) public {
        uint32 presentTime = uint32(block.timestamp);
        tokenId++;
        nftItems[tokenId]= nftDetails(_name, tokenId, payable(msg.sender), payable(0x0), 0, presentTime, 0, 0, true, false);
        _safeMint(msg.sender, tokenId);
    }
    /**
     * @dev User can get the details of NFT
     * @param _nftId - pass nftId to get NFTdetails.
     * '_nftId' must exist.
     */
    function getNftdetails(uint256 _nftId) public view nftItemExists(_nftId) returns (string memory name, uint256 nftId,
        address payable presentOwner, 
        address payable oldOwner,
        uint256 minPrice, 
        uint32 mintTime,
        uint32 auctionTime,
        uint32 auctionEndsAt,
        bool tokenIdExist,  
        bool auctionStarted)
        {
            nftDetails memory _nftDetails = nftItems[_nftId];
            return (
                _nftDetails.name,
                _nftDetails.nftId, 
                _nftDetails.presentOwner,
                _nftDetails.oldOwner, 
                _nftDetails.minPrice,
                _nftDetails.mintTime,
                _nftDetails.auctionTime,
                _nftDetails.auctionEndsAt,
                _nftDetails.tokenIdExist,
                _nftDetails.auctionStarted);
    }
    /**
     * @dev NFTOwner(presentowner) will start auction for their NFT
     * @param _nftId pass tokenId to start auction.
     * @param _minPrice pass value of miniPrice of NFT item
     * @param _auctionEndsAt pass timePeriod for how much time this auction will be on.
     * '_nftId' must exist.
     * 'onlyNFTOwner' will start the auction.
     * Emit event BidStarted 
     */
    function BidBegin(uint256 _nftId, uint256 _minPrice, uint32 _auctionEndsAt) public nftItemExists(_nftId) onlyNFtOwner(_nftId) {
        nftDetails storage _nftDetails = nftItems[_nftId];
        uint32 presentTime = uint32(block.timestamp);

        _nftDetails.minPrice = _minPrice * 1 ether;
        _nftDetails.auctionTime = presentTime;
        _nftDetails.auctionEndsAt = _nftDetails.auctionTime + _auctionEndsAt;

        _nftDetails.auctionStarted = true;

        emit BidStarted( _nftDetails.presentOwner,_nftDetails.nftId, _nftDetails.name);
    }
    /**
     * @dev People can place their bid for NFT they interested.
     * Requirements
     * @param _nftId - User haev to pass tokenId to place bid for that NFt.
     * '_ntfId' must exist.
     * 'auctionStartAcess' Auction should started.
     * 'notNFTOwner' Bider should not be Owner of NFT.
     * 'minBidamount' Biding price should be greater than minimum bid set by NFT Owner.
     *@return success bool
     */
    function Bid(uint256 _nftId) public payable notNftOwner(_nftId) nftItemExists(_nftId) minBidamount(_nftId) auctionStartAcess(_nftId) returns (bool success)
    {
        //reject payment of 0 Eth
        if(msg.value == 0) revert();
        //calculate the user's total bid based on the current amount they've sent to the contract
        //  plus whatever has been sent with this transaction
        Bidding storage _Bidding = highestBidders[_nftId];
        nftDetails storage _nftDetails = nftItems[_nftId];
        require(block.timestamp < _nftDetails.auctionEndsAt, " Bidding time ended");

        uint newBid = fundedbids[_nftId][msg.sender] + msg.value;
        // if the bidder isn't even willing to overbid the highestbid, 
        //there is nothing for us to do except reverting transaction.
        if (newBid <= _Bidding.highestBidAmt) revert();
        // if the bidder is NOT highestBidder, we set them as the new highestBidder and recalculate highestBidAmt.
        if (msg.sender != _Bidding.highestBidder) {
            _Bidding.highestBidder = payable(msg.sender);
        }
        fundedbids[_nftId][msg.sender] = newBid;
        _Bidding.highestBidAmt = newBid;
        return true;
    }
    /**
     * @dev we can see the bid auction winner as well as highest bidding amount of NFT.
     * Requierments
     * @param _nftId pass nftId to get winner of NFT.
     * '_nftId' must exist.
     * 'auctionStartAcess' Auction should be started.
     * @return highestBidAmt
     * @return highestBidder
     */
    function bidResults(uint256 _nftId) public view nftItemExists(_nftId) auctionStartAcess(_nftId) returns(uint256, address) {
        
        Bidding memory _Bidding = highestBidders[_nftId];
        nftDetails memory _nftDetails = nftItems[_nftId];
        if (block.timestamp < _nftDetails.auctionEndsAt)
            revert("Auction still running check after auction ends.");
        return (_Bidding.highestBidAmt, _Bidding.highestBidder); 
    }
    /**
     * @dev NFT Owner will call this function to transfer NFT to winner in return get highest biding amount
     * Requierments
     * @param _nftId pass nftId to transfer the NFT to bid Winner.
     * '_nftId' must exist.
     * 'onlyNFTOwner' will call this function.
     * @return success bool
     */
    function auctionEnd(uint256 _nftId) public nftItemExists(_nftId) onlyNFtOwner(_nftId) returns (bool){
        Bidding storage _Bidding = highestBidders[_nftId];
        nftDetails storage _nftDetails = nftItems[_nftId];
        if (block.timestamp < _nftDetails.auctionEndsAt) revert("Auction did not end yet");
        //transfer NFT item of particular token Id to the higgest bidder
        safeTransferFrom(_nftDetails.presentOwner,_Bidding.highestBidder,_nftId);
        (_nftDetails.presentOwner).transfer(_Bidding.highestBidAmt);
        //present owner is previous owner
        _nftDetails.oldOwner = _nftDetails.presentOwner;
        _nftDetails.presentOwner = _Bidding.highestBidder;
        _nftDetails.auctionStarted = false;
        fundedbids[_nftId][_nftDetails.presentOwner] = 0;

        _Bidding.highestBidAmt = 0;
        _Bidding.highestBidder = payable(0x0);
        return true;
    }
    /**
     * @dev People who bid for NFT can withdraw their amount if not won
     * Requirements
     * @param _nftId - pass nftId to get their amount bid for NFT.
     * '_nftId' must existd.
     * 'fundedbids' for _nftId must be greater than zero.
     */
    function withdrawal(uint256 _nftId) public nftItemExists(_nftId) {
        if (fundedbids[_nftId][msg.sender] < 1) revert();
        payable(msg.sender).transfer(fundedbids[_nftId][msg.sender]);
    }


    /**
     * @dev People will check total balance of contract
     * @return balance of contract
     */
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}