// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./FoxNFT.sol";

contract FOX {
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public returns (bool) {}

    function approve(address spender, uint256 amount) public returns (bool) {}

    function transfer(address recipient, uint256 amount)
        public
        returns (bool)
    {}

    function allowance(address owner, address spender)
        public
        view
        returns (uint256)
    {}
}

contract Marketplace is AccessControl, Ownable {
    // Set the MaxQuantity of the production
    uint256 maxQuantity = 100;
    
    // Revenue Data
    address public MARKETING_ADDRESS = 0xB183eE73A5bD8f4b389AcEc44F437e022D128D5D;
    address public DEV_ADDRESS = 0xEC254c788d397fB18bb84Ad47a77d53424e93240;
    address public CREATION_ADDRESS =0xeA3d00e68e1a890348298a60b75F117aFd685152;

    uint public MARKETING_PERCENT = 15;
    uint public DEV_PERCENT = 43;
    uint public CREATION_PERCENT = 10;

    struct FoxProd {
        string name;
        string description;
        uint256 price;
        uint256 quantity;
        address owner;
        uint8 flag;
    }

    bytes32 public constant EDIT_ROLE = keccak256("EDIT_ROLE");

    // Mapping Set
    mapping(string => FoxProd) public foxProds;
    string[] hashes;

    FoxNFT ft;
    FOX fox;

    // Set the FeePercent and feeAddress
    address public feeAddress;
    uint256 public feePercent;

    // In constructor, give the role to msgSender
    constructor(
        FoxNFT _ft,
        address _fox,
        uint256 _fee
    ) {
        ft = _ft;
        fox = FOX(address(_fox));
        feePercent = _fee;
        _setupRole(EDIT_ROLE, _msgSender());
    }

    // Set and get the MaxQuantity of the production
    function setMaxQuantity(uint256 _quantity) public onlyOwner{
        maxQuantity = _quantity;
    }

    function getMaxQuantity() public view returns (uint256) {
        return maxQuantity;
    }

    // Compare Stings
    function compareStrings(string memory a, string memory b)
        public
        pure
        returns (bool)
    {
        return (keccak256(abi.encodePacked((a))) ==
            keccak256(abi.encodePacked((b))));
    }

    // TEST if it has EDIT ROLE
    modifier editable() {
        require(
            hasRole(EDIT_ROLE, _msgSender()),
            "Must Have Edit Role to Do"
        );
        _;
    }

    // Add new productions into the Marketplace
    function addNewProduction(
        string memory _name,
        string memory _description,
        uint256 _price,
        uint256 _quantity,
        string memory _hash
    ) public editable returns (bool) {
        require(
            _quantity <= maxQuantity,
            "Quantity cannot be higher than the maximum quantity"
        );
        require(
            foxProds[_hash].flag != 1,
            "You can't create this production, it is already existed!"
        );
        foxProds[_hash] = FoxProd(
            _name,
            _description,
            _price,
            _quantity,
            _msgSender(),
            1
        );
        hashes.push(_hash);

        return true;
    }

    // Set some props to the existing Production in the Marketplace
    function setProdByHash(string memory _name, string memory _description, uint256 _price, uint _quantity, string memory _hash) public editable returns(bool) {
        require(_quantity <= maxQuantity, "Quantity cannot be higher than the maximum quantity");
        require(foxProds[_hash].flag == 1);
        require(foxProds[_hash].owner == _msgSender(), "Only production owner can chnage the properties of nft.");
        foxProds[_hash] = FoxProd(_name, _description, _price, _quantity, _msgSender(), 1);
        return true;
    }

    // Remove some Quantity from the existing Production in the Marketplace
    function deleteProdByHash(string memory _hash) public returns(bool) {
        require(owner() == _msgSender() || (foxProds[_hash].owner == _msgSender()), "Admin or product owner only can delete this.");
        uint arrIndex; 
        bool isExist = false;
        for (uint256 index = 0; index < hashes.length; index++) {
            if (compareStrings(_hash, hashes[index])) {
                arrIndex = index;
                isExist = true;
            }
        }

        if (isExist) {
            hashes[arrIndex] = hashes[hashes.length - 1];
            hashes.pop();
        }

        delete foxProds[_hash];
        return true;
    }

    // Get FoxProds by using _hash
    function getProdList() public view returns (string[] memory) {
        return hashes;
    }

    function getProdByHash(string memory _hash)
        public
        view
        returns (FoxProd memory)
    {
        return foxProds[_hash];
    }

    // Buy the production you want
    function buy(
        address to,
        string memory _hash,
        uint256 _amount
    ) public payable returns (uint256) {
        require(
            foxProds[_hash].quantity >= 1,
            "Must have quantity more than 1"
        );
        require(
            _amount == foxProds[_hash].price * 10**9,
            "Amount should be same with price"
        );
       
        uint256 BurnPercent = 100  - MARKETING_PERCENT - DEV_PERCENT - CREATION_PERCENT;
        uint256 feeAmount = (_amount * feePercent) / 100;
        
        require(
            fox.transferFrom(msg.sender, MARKETING_ADDRESS, _amount * MARKETING_PERCENT / 100),
            "ERC20: Sending to Marketing Failed"
        );

        require(
            fox.transferFrom(msg.sender, DEV_ADDRESS, _amount * DEV_PERCENT / 100),
            "ERC20: Sendig to Dev Failed"
        );
        require(
            fox.transferFrom(msg.sender, CREATION_ADDRESS, _amount * CREATION_PERCENT / 100),
            "ERC20: Sending to Creation Failed"
        );
        require(
            fox.transferFrom(msg.sender, address(0x1), _amount * BurnPercent / 100),
            "ERC20: Burn Failed"
        );

        require(
            fox.transferFrom(msg.sender, feeAddress, feeAmount),
            "ERC20: transfer fees to Set Addresss!"
        );
        ft.mint(to, _hash);
        foxProds[_hash].quantity = foxProds[_hash].quantity - 1;
        if (foxProds[_hash].quantity == 0) deleteProdByHash(_hash);
        
        return foxProds[_hash].quantity;
    }

    // Set Tax fee percetage and fee address
    function setFeeAmount(uint _feeAmount) public onlyOwner {
        feePercent = _feeAmount;
    }
    
    function setFeeAddress(address _feeAddress) public onlyOwner {
        feeAddress = _feeAddress;
    }

    // Set DEVELOPER's Address and Fee
    function setDEVData(address _newAdd, uint _newPer) public onlyOwner{
        DEV_ADDRESS = _newAdd;
        DEV_PERCENT = _newPer;
    }
    
    // Set MARKETING Address and Fee
    function setMARKETINGData(address _newAdd, uint _newPer) public onlyOwner{
        MARKETING_ADDRESS = _newAdd;
        MARKETING_PERCENT = _newPer;
    }

    // Set CREATION Address and Fee
    function setCREATIONDate(address _newAdd, uint _newPer) public onlyOwner{
        CREATION_ADDRESS = _newAdd;
        CREATION_PERCENT = _newPer;
    }
}