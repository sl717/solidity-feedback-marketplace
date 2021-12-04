// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./FoxNFT.sol";


contract FOX {
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {}
    function approve(address spender, uint256 amount) public returns (bool) {}
    function transfer(address recipient, uint256 amount) public returns (bool) {}
    function allowance(address owner, address spender) public view returns (uint256) {}
}


contract Marketplace is AccessControl {

    int maxQuantity = 10;

    struct FoxProd {
        string name;
        string description;
        uint256 price;
        int quantity;
        address owner;
        uint8 flag;
    }
    
    bytes32 public constant PRODUCE_ROLE = keccak256("PRODUCE_ROLE");
    
    mapping (string => FoxProd) public foxProds;
    string [] public hashes;
    
    FoxNFT ft;
    FOX fox;
    
    address public feeAddress;
    uint public feePercent;
    
    event ProductCreated(string hash, uint256 price, int quantity, address owner);
    event ProductSale(string hash, uint256 price, address to);
    
    constructor(FoxNFT _ft, address _fox, uint _fee) {
        ft = _ft;
        fox = FOX(address(_fox));
        feeAddress = _msgSender();
        feePercent = _fee;
        _setupRole(PRODUCE_ROLE, _msgSender());
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }
    
    function setMaxQuantity(int _quantity) public {
        maxQuantity = _quantity;
    }
    
    function getMaxQuantity() public view returns(int) {
        return maxQuantity;
    }
    
    function compareStrings(string memory a, string memory b) public view returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }
    
    function addNewProduction(string memory _name, string memory _description, uint256 _price, int _quantity, string memory _hash) public returns (bool) {
        require(hasRole(PRODUCE_ROLE, _msgSender()), "Must have produce role to mint");
        require(_quantity <= maxQuantity, "Quantity cannot be higher than the maximum quantity");
        require(foxProds[_hash].flag != 1);
        foxProds[_hash] = FoxProd(_name, _description, _price, _quantity, _msgSender(), 1);
        hashes.push(_hash);
        
        emit ProductCreated(_hash, _price, _quantity, _msgSender());
        return true;
    }
    
    function getProdList() public view returns(string[] memory){
        return hashes;
    }
    
    function getProdByHash(string memory _hash) public view returns(FoxProd memory){
        return foxProds[_hash];
    }
    
    function setProdByHash(string memory _name, string memory _description, uint256 _price, int _quantity, string memory _hash) public returns (bool) {
        require(hasRole(PRODUCE_ROLE, _msgSender()), "Must have produce role to mint");
        require(_quantity <= maxQuantity, "Quantity cannot be higher than the maximum quantity");
        require(foxProds[_hash].flag != 1);
        require(foxProds[_hash].owner == _msgSender(), "Only production owner can chnage the properties of nft.");
        foxProds[_hash] = FoxProd(_name, _description, _price, _quantity, _msgSender(), 1);
        return true;
    }
    
    function deleteProdByHash(string memory _hash) public returns (bool) {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()) || (foxProds[_hash].owner == _msgSender()), "Admin or product owner only can delete this.");
        uint arrIndex; 
        bool isExist = false;
        for (uint256 index = 0; index < hashes.length; index++){
            if (compareStrings(_hash, hashes[index])){
                arrIndex = index;
                isExist = true;
            }
        }
        
        if(isExist){
            hashes[arrIndex] = hashes[hashes.length-1];
            hashes.pop(); 
        }
        
        delete foxProds[_hash];
        return true;
    }
    
    function buy(address to, string memory _hash, uint256 _amount ) public payable returns (int) {
        require(foxProds[_hash].quantity >= 1, "Must have quantity more than 1");
        require(_amount == foxProds[_hash].price * 10**9, "Amount should be same with price");
        uint256 feeAmount = foxProds[_hash].price * feePercent * 10**5 ;   //100 % is 10000
        require(fox.transferFrom(msg.sender, address(0x1), _amount - feeAmount), "ERC20: transfer amount exceeds allowance");
        require(fox.transferFrom(msg.sender, feeAddress, feeAmount), "ERC20: transfer amount exceeds allowance");
        ft.mint(to, _hash);
        foxProds[_hash].quantity = foxProds[_hash].quantity - 1;
        if(foxProds[_hash].quantity == 0){
            deleteProdByHash(_hash);
        }
        emit ProductSale(_hash, _amount, _msgSender());
        return foxProds[_hash].quantity;
    }
    
    //set fee precentage
    function setFeeAmount(uint _feeAmount) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Admin only can do this.");
        feePercent = _feeAmount;
    }
    
    //set fee address
    function setFeeAddress(address _feeAddress) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Admin only can do this.");
        feeAddress = _feeAddress;
    }
}