// SPDX-License-Identifier: MIT


pragma solidity >=0.7.0 <0.9.0;

import {Base64} from "base64-sol/base64.sol";
import "erc721a/contracts/ERC721A.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "operator-filter-registry/src/DefaultOperatorFilterer.sol";


//tokenURI interface
interface ITokenURI {
    function tokenURI(uint256 _tokenId) external view returns (string memory);
}

contract SeoriGenerative is ERC2981, DefaultOperatorFilterer, Ownable, ERC721A, AccessControl {
    constructor() ERC721A("SeoriGenerative", "SEORI") {
        //Role initialization
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(AIRDROP_ROLE, msg.sender);

        //first mint and burn
        _mint(msg.sender, 5);

        //for test
        //setOnlyAllowlisted(false);
        //setMintCount(false);
        //setPause(false);
        //setMaxSupply(6);
    }

    //
    //withdraw section
    //

    address public constant withdrawAddress =
        0xddf110763eBc75419A39150821c46a58dDD2d667;

    function withdraw() public payable onlyOwner {
        (bool os, ) = payable(withdrawAddress).call{
            value: address(this).balance
        }("");
        require(os);
    }

    //
    //mint section
    //

    uint256 public cost = 0.001 ether;
    uint256 public constant maxSupply = 5000;
    uint8 public maxMintAmountPerTransaction = 100;
    uint16 public publicSaleMaxMintAmountPerAddress = 300;
    bool public paused = true;

    bool public onlyAllowlisted = true;
    bool public mintCount = true;
    bool public burnAndMintMode;// = false;

    //0 : Merkle Tree
    //1 : Mapping
    uint8 public allowlistType;// = 0;
    uint16 public saleId;// = 0;
    bytes32 public merkleRoot = 0xa5b07db99cc7e790aea5121ef230a1781b181eee17ba26a12a469781c539419a;
    mapping(uint256 => mapping(address => uint256)) public userMintedAmount;
    mapping(uint256 => mapping(address => uint256)) public allowlistUserAmount;

    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is another contract.");
        _;
    }

    //mint with merkle tree
    function mint(
        uint256 _mintAmount,
        uint256 _maxMintAmount,
        bytes32[] calldata _merkleProof,
        uint256 _burnId
    ) public payable callerIsUser {
        require(!paused, "the contract is paused");
        require(0 < _mintAmount, "need to mint at least 1 NFT");
        require(
            _mintAmount <= maxMintAmountPerTransaction,
            "max mint amount per session exceeded"
        );
        require(
            _nextTokenId() - 1 + _mintAmount <= maxSupply,
            "max NFT limit exceeded"
        );
        require(cost * _mintAmount <= msg.value, "insufficient funds");

        uint256 maxMintAmountPerAddress;
        if (onlyAllowlisted == true) {
            if (allowlistType == 0) {
                //Merkle tree
                bytes32 leaf = keccak256(
                    abi.encodePacked(msg.sender, _maxMintAmount)
                );
                require(
                    MerkleProof.verify(_merkleProof, merkleRoot, leaf),
                    "user is not allowlisted"
                );
                maxMintAmountPerAddress = _maxMintAmount;
            } else if (allowlistType == 1) {
                //Mapping
                require(
                    allowlistUserAmount[saleId][msg.sender] != 0,
                    "user is not allowlisted"
                );
                maxMintAmountPerAddress = allowlistUserAmount[saleId][
                    msg.sender
                ];
            }
        } else {
            maxMintAmountPerAddress = uint256(publicSaleMaxMintAmountPerAddress);
        }

        if (mintCount == true) {
            require(
                _mintAmount <=
                    maxMintAmountPerAddress -
                        userMintedAmount[saleId][msg.sender],
                "max NFT per address exceeded"
            );
            userMintedAmount[saleId][msg.sender] += _mintAmount;
        }

        if (burnAndMintMode == true) {
            require(_mintAmount == 1, "");
            require(msg.sender == ownerOf(_burnId), "Owner is different");
            _burn(_burnId);
        }

        // Under callerIsUser, safeMint wastes gas without meanings.
        //_safeMint(msg.sender, _mintAmount);
        _mint(msg.sender, _mintAmount);
    }

    bytes32 public constant AIRDROP_ROLE = keccak256("AIRDROP_ROLE");

    function airdropMint(
        address[] calldata _airdropAddresses,
        uint256[] memory _UserMintAmount
    ) public {
        require(
            hasRole(AIRDROP_ROLE, msg.sender),
            "Caller is not a air dropper"
        );
        uint256 _mintAmount = 0;
        for (uint256 i = 0; i < _UserMintAmount.length; i++) {
            _mintAmount += _UserMintAmount[i];
        }
        require(0 < _mintAmount, "need to mint at least 1 NFT");
        require(
            totalSupply() + _mintAmount <= maxSupply,
            "max NFT limit exceeded"
        );
        for (uint256 i = 0; i < _UserMintAmount.length; i++) {
            _safeMint(_airdropAddresses[i], _UserMintAmount[i]);
        }
    }

    function setBurnAndMintMode(bool _burnAndMintMode) public onlyOwner {
        burnAndMintMode = _burnAndMintMode;
    }

    function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function setPause(bool _state) public onlyOwner {
        paused = _state;
    }

    function setAllowListType(uint256 _type) public onlyOwner {
        require(_type == 0 || _type == 1, "Allow list type error");
        allowlistType = uint8(_type);
    }

    function setAllowlistMapping(
        uint256 _saleId,
        address[] memory addresses,
        uint256[] memory saleSupplies
    ) public onlyOwner {
        require(addresses.length == saleSupplies.length);
        for (uint256 i = 0; i < addresses.length; i++) {
            allowlistUserAmount[_saleId][addresses[i]] = saleSupplies[i];
        }
    }

    function getAllowlistUserAmount(
        address _address
    ) public view returns (uint256) {
        return allowlistUserAmount[saleId][_address];
    }

    function getUserMintedAmountBySaleId(
        uint256 _saleId,
        address _address
    ) public view returns (uint256) {
        return userMintedAmount[_saleId][_address];
    }

    function getUserMintedAmount(
        address _address
    ) public view returns (uint256) {
        return userMintedAmount[saleId][_address];
    }

    function setSaleId(uint256 _saleId) public onlyOwner {
        saleId = uint8(_saleId);
    }

    /* maxSupply changed to constant
    function setMaxSupply(uint256 _maxSupply) public onlyOwner {
        maxSupply = _maxSupply;
    }
    */

    function setPublicSaleMaxMintAmountPerAddress(
        uint256 _publicSaleMaxMintAmountPerAddress
    ) public onlyOwner {
        publicSaleMaxMintAmountPerAddress = uint16(_publicSaleMaxMintAmountPerAddress);
    }

    function setCost(uint256 _newCost) public onlyOwner {
        cost = _newCost;
    }

    function setOnlyAllowlisted(bool _state) public onlyOwner {
        onlyAllowlisted = _state;
    }

    function setMaxMintAmountPerTransaction(
        uint256 _maxMintAmountPerTransaction
    ) public onlyOwner {
        maxMintAmountPerTransaction = uint8(_maxMintAmountPerTransaction);
    }

    function setMintCount(bool _state) public onlyOwner {
        mintCount = _state;
    }

    //
    //interface metadata
    //

    ITokenURI public interfaceOfTokenURI;

    function setInterfaceOfTokenURI(address _address) public onlyOwner {
        interfaceOfTokenURI = ITokenURI(_address);
    }

    //
    //token URI
    //

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        _exists(tokenId);
        if (address(interfaceOfTokenURI) != address(0)) {
            return interfaceOfTokenURI.tokenURI(tokenId);
        }
        return "";
    }

    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    //
    //burnin' section
    //

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    function externalMint(address _address, uint256 _amount) external payable {
        require(hasRole(MINTER_ROLE, msg.sender), "Caller is not a minter");
        require(
            _nextTokenId() - 1 + _amount <= maxSupply,
            "max NFT limit exceeded"
        );
        _safeMint(_address, _amount);
    }

    function externalBurn(uint256[] memory _burnTokenIds) external {
        require(hasRole(BURNER_ROLE, msg.sender), "Caller is not a burner");
        for (uint256 i = 0; i < _burnTokenIds.length; i++) {
            uint256 tokenId = _burnTokenIds[i];
            require(msg.sender == ownerOf(tokenId), "Owner is different");
            _burn(tokenId);
        }
    }

    //
    //sbt section
    //

    bool public isSBT = false;

    function setIsSBT(bool _state) public onlyOwner {
        isSBT = _state;
    }
    
    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual override {
        require(
            isSBT == false ||
                from == address(0) ||
                to == address(0x000000000000000000000000000000000000dEaD),
            "transfer is prohibited"
        );
        super._beforeTokenTransfers(from, to, startTokenId, quantity);
    }

    function setApprovalForAll(
        address operator,
        bool approved
    ) public virtual override onlyAllowedOperatorApproval(operator) {
        require(isSBT == false, "setApprovalForAll is prohibited");
        super.setApprovalForAll(operator, approved);
    }

    function approve(
        address to,
        uint256 tokenId
    ) public payable virtual override onlyAllowedOperatorApproval(to) {
        require(isSBT == false, "approve is prohibited");
        super.approve(to, tokenId);
    }

    ///////////////////////////////////////////////////////////////////////////
    // ERC2981 Royalty
    ///////////////////////////////////////////////////////////////////////////
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    //
    // override section
    //
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC2981, ERC721A, AccessControl) returns (bool) {
        return
            ERC2981.supportsInterface(interfaceId) ||
            AccessControl.supportsInterface(interfaceId) ||
            ERC721A.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-transferFrom}.
     *      In this example the added modifier ensures that the operator is allowed by the OperatorFilterRegistry.
     */
    function transferFrom(address from, address to, uint256 tokenId) public payable override onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     *      In this example the added modifier ensures that the operator is allowed by the OperatorFilterRegistry.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public payable override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     *      In this example the added modifier ensures that the operator is allowed by the OperatorFilterRegistry.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        payable
        override
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId, data);
    }


}
