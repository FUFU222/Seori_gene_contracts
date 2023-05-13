// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../contracts/SeoriGenerative.sol";
import "../contracts/SeoriURI.sol";

contract CounterTest is Test {
    SeoriGenerative public nft;
    SeoriURI public uri;

    string public constant BASE_URI_FOR_TEST = "https://test.com/";

    function setUp() public {
        nft = new SeoriGenerative();
        uri = new SeoriURI();
        nft.setInterfaceOfTokenURI(address(uri));
    }

    function testTokenURI() public {
        assertEq(nft.tokenURI(1), string.concat(BASE_URI_FOR_TEST, vm.toString(uint256(1)), ".json"));
    }

    function test_expectRevert_airdropMint_amountZero() public {
        nft.grantRole(nft.AIRDROP_ROLE(), address(this));
        vm.expectRevert();
        address[] memory p1 = new address[] (1);
        uint256[] memory p2 = new uint256[] (1);
        p1[0] = vm.addr(1);
        nft.airdropMint(p1, p2);

    }

    function test_expectRevert_airdropMint_exceedSupply() public {
        nft.grantRole(nft.AIRDROP_ROLE(), address(this));
        address[] memory p1 = new address[] (1);
        uint256[] memory p2 = new uint256[] (1);
        p1[0] = vm.addr(1);
        p2[0] = nft.maxSupply();
        vm.expectRevert();
        nft.airdropMint(p1, p2);

    }
}
