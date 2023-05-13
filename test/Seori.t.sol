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
}
