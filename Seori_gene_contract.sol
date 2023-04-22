// SPDX-License-Identifier: MIT


pragma solidity >=0.7.0 <0.9.0;

import {Base64} from "base64-sol/base64.sol";
import "erc721a/contracts/ERC721A.sol";
import {ERC2981} from "openzeppelin-contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "operator-filter-registry-src-DefaultOperatorFilterer.sol";

//tokenURI interface
interface iTokenURI {
    function tokenURI(uint256 _tokenId) external view returns (string memory);
}

contract SeoriGenerative is DefaultOperatorFilterer, Ownable, ERC721A, AccessControl {
    constructor() ERC721A("SeoriGenerative", "SEORI") {
        //Role initialization
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(AIRDROP_ROLE, msg.sender);

        //URI initialization
        setBaseURI("https://data.zqn.wtf/tereqn/metadata/");

        //use single metadata
        //setUseSingleMetadata(true);
        //setMetadataTitle("title");
        //setMetadataDescription("setumei");
        //setMetadataAttributes("poap");
        //setImageURI("https://data.zqn.wtf/sanuqn/images/1.png");//sanuqn

        //first mint and burn
        _safeMint(msg.sender, 5);

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

    uint256 public cost = 0;
    uint16 public constant maxSupply = 5000;
    uint8 public maxMintAmountPerTransaction = 10;
    uint8 public publicSaleMaxMintAmountPerAddress = 300;
    bool public paused = true;

    bool public onlyAllowlisted = true;
    bool public mintCount = true;
    bool public burnAndMintMode = false;

    //0 : Merkle Tree
    //1 : Mapping
    uint8 public allowlistType = 0;
    uint16 public saleId = 0;
    bytes32 public merkleRoot;
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
            maxMintAmountPerAddress = publicSaleMaxMintAmountPerAddress;
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

        _safeMint(msg.sender, _mintAmount);
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
        allowlistType = _type;
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
        saleId = _saleId;
    }

    function setMaxSupply(uint256 _maxSupply) public onlyOwner {
        maxSupply = _maxSupply;
    }

    function setPublicSaleMaxMintAmountPerAddress(
        uint256 _publicSaleMaxMintAmountPerAddress
    ) public onlyOwner {
        publicSaleMaxMintAmountPerAddress = _publicSaleMaxMintAmountPerAddress;
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
        maxMintAmountPerTransaction = _maxMintAmountPerTransaction;
    }

    function setMintCount(bool _state) public onlyOwner {
        mintCount = _state;
    }

    //
    //URI section
    //

    string public baseURI;
    string public baseExtension = ".json";

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function setBaseExtension(
        string memory _newBaseExtension
    ) public onlyOwner {
        baseExtension = _newBaseExtension;
    }

    //
    //interface metadata
    //

    iTokenURI public interfaceOfTokenURI;
    bool public useInterfaceMetadata = false;

    function setInterfaceOfTokenURI(address _address) public onlyOwner {
        interfaceOfTokenURI = iTokenURI(_address);
    }

    function setUseInterfaceMetadata(
        bool _useInterfaceMetadata
    ) public onlyOwner {
        useInterfaceMetadata = _useInterfaceMetadata;
    }

    //
    //single metadata
    //

    bool public useSingleMetadata = false;
    string public imageURI;
    string public metadataTitle;
    string public metadataDescription;
    string public metadataAttributes;

    //single image metadata
    function setUseSingleMetadata(bool _useSingleMetadata) public onlyOwner {
        useSingleMetadata = _useSingleMetadata;
    }

    function setMetadataTitle(string memory _metadataTitle) public onlyOwner {
        metadataTitle = _metadataTitle;
    }

    function setMetadataDescription(
        string memory _metadataDescription
    ) public onlyOwner {
        metadataDescription = _metadataDescription;
    }

    function setMetadataAttributes(
        string memory _metadataAttributes
    ) public onlyOwner {
        metadataAttributes = _metadataAttributes;
    }

    function setImageURI(string memory _newImageURI) public onlyOwner {
        imageURI = _newImageURI;
    }

    //
    //token URI
    //

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        if (useInterfaceMetadata == true) {
            return interfaceOfTokenURI.tokenURI(tokenId);
        }
        if (useSingleMetadata == true) {
            return
                string(
                    abi.encodePacked(
                        "data:application/json;base64,",
                        Base64.encode(
                            abi.encodePacked(
                                "{"
                                '"name":"',
                                metadataTitle,
                                '",',
                                '"description":"',
                                metadataDescription,
                                '",',
                                '"image": "',
                                imageURI,
                                '",',
                                '"attributes":[{"trait_type":"type","value":"',
                                metadataAttributes,
                                '"}]',
                                "}"
                            )
                        )
                    )
                );
        }
        return
            string(abi.encodePacked(ERC721A.tokenURI(tokenId), baseExtension));
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
    ) public payable virtual override onlyAllowedOperatorApproval(operator) {
        require(isSBT == false, "approve is prohibited");
        super.approve(to, tokenId);
    }

    //
    // override section
    //
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721A, AccessControl) returns (bool) {
        return
            AccessControl.supportsInterface(interfaceId) ||
            ERC721A.supportsInterface(interfaceId);
    }
}





    /**
     * @dev See {IERC721-transferFrom}.
     *      In this example the added modifier ensures that the operator is allowed by the OperatorFilterRegistry.
     */
    function transferFrom(address from, address to, uint256 tokenId) public override onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     *      In this example the added modifier ensures that the operator is allowed by the OperatorFilterRegistry.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     *      In this example the added modifier ensures that the operator is allowed by the OperatorFilterRegistry.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        override
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId, data);
    }







    /**
     * Returns the auxiliary data for `owner`. (e.g. number of whitelist mint slots used).
     */
    function _getAux(address owner) internal view returns (uint64) {
        return uint64(_packedAddressData[owner] >> _BITPOS_AUX);
    }

    /**
     * Sets the auxiliary data for `owner`. (e.g. number of whitelist mint slots used).
     * If there are multiple variables, please pack them into a uint64.
     */
    function _setAux(address owner, uint64 aux) internal virtual {
        uint256 packed = _packedAddressData[owner];
        uint256 auxCasted;
        // Cast `aux` with assembly to avoid redundant masking.
        assembly {
            auxCasted := aux
        }
        packed = (packed & _BITMASK_AUX_COMPLEMENT) | (auxCasted << _BITPOS_AUX);
        _packedAddressData[owner] = packed;
    }


