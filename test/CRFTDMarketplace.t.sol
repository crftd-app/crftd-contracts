// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import "solmate/test/utils/mocks/MockERC20.sol";
import "solmate/tokens/WETH.sol";

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import {CollablandProxy} from "src/lib/CollablandProxy.sol";

import "src/CRFTDMarketplace.sol";
import "futils/futils.sol";

contract TestMarketplace is Test {
    using futils for *;

    WETH weth;

    CRFTDMarketplace market;

    CRFTDMarketplace.MarketItem[] items;
    CRFTDMarketplace.MarketItem[] itemsDutchAuction;
    CRFTDMarketplace.MarketItem[] itemsRaffle;

    CRFTDMarketplace.MarketItem item;
    CRFTDMarketplace.MarketItem itemDutchAuction;
    CRFTDMarketplace.MarketItem itemRaffle;

    MockERC20 mock1;
    MockERC20 mock2;

    address[] paymentTokens;

    address bob;
    uint256 bobPk;
    address alice;
    uint256 alicePk;
    address self = address(this);

    function setUp() public {
        market = new CRFTDMarketplace();

        mock1 = new MockERC20("", "", 18);
        mock2 = new MockERC20("", "", 18);

        mock1.approve(address(market), type(uint256).max);
        mock2.approve(address(market), type(uint256).max);

        mock1.mint(self, 100e18);
        mock2.mint(self, 100e18);

        (bob, bobPk) = makeAddrAndKey("bob");
        (alice, alicePk) = makeAddrAndKey("alice");

        item.marketId = 0;
        item.start = block.timestamp;
        item.end;
        item.expiry = block.timestamp + 10 hours;
        item.maxPurchases = 2;
        item.maxSupply = 4;
        item.raffleNumPrizes;
        item.raffleControllers;
        item.receiver = alice;
        item.dataHash = 0x00;
        item.acceptedPaymentTokens.push(address(mock1));
        item.acceptedPaymentTokens.push(address(mock2));
        item.tokenPricesStart.push(10e18);
        item.tokenPricesStart.push(50e18);
        item.tokenPricesEnd;

        itemDutchAuction = item;
        itemDutchAuction.end = block.timestamp + 1 hours;
        itemDutchAuction.tokenPricesEnd.push(0e18);
        itemDutchAuction.tokenPricesEnd.push(20e18);

        itemRaffle = item;
        itemRaffle.maxSupply = 20;
        itemRaffle.raffleNumPrizes = 10;
        itemRaffle.raffleControllers.push(bob);

        checkBalance(mock1, self);

        vm.startPrank(self, self);
    }

    /* ------------- helpers ------------- */

    mapping(address => mapping(address => uint256)) _balance_check;

    function checkBalance(ERC20 token, address user) internal returns (uint256) {
        uint256 balance = token.balanceOf(user);
        uint256 balanceBefore = _balance_check[address(token)][user];

        if (balanceBefore == 0) {
            return _balance_check[address(token)][user] = balance;
        } else {
            _balance_check[address(token)][user] = balance;
            return balanceBefore - balance;
        }
    }

    function calculateDAPrice(uint256 startPrice, uint256 endPrice, uint256 start, uint256 end)
        internal
        view
        returns (uint256)
    {
        uint256 timestamp = block.timestamp > end ? end : block.timestamp;

        return startPrice - ((startPrice - endPrice) * (timestamp - start)) / (end - start);
    }

    /* ------------- purchaseMarketItems() ------------- */

    function test_purchaseMarketItems() public {
        items.push(item);
        paymentTokens.push(address(mock1));

        market.purchaseMarketItems(items, paymentTokens, 0x0);

        assertEq(checkBalance(mock1, self), item.tokenPricesStart[0]);

        bytes32 itemHash = keccak256(abi.encode(item));

        assertEq(market.totalSupply(itemHash), 1);
        assertEq(market.numPurchases(itemHash, self), 1);
    }

    // bytes32 constant GAS_SLOT = keccak256("gas.slot");

    // function logGas(bool log) private {
    //     vm.toString(uint256(0));
    //     bytes32 slot = GAS_SLOT;
    //     uint256 lastGasUsed;
    //     assembly {
    //         lastGasUsed := sload(slot)
    //         sstore(slot, 1)
    //         sstore(slot, gas())
    //     }
    //     if (lastGasUsed != 0 && log) {
    //         uint256 gasNow = gasleft();
    //         uint256 gasSpent = lastGasUsed - gasNow - 1410;
    //         console.log(string.concat(vm.toString(gasSpent), " gas "));
    //     }
    // }

    function test_purchaseMarketItems2() public {
        items.push(item);
        items.push(item);

        item.marketId = 123;
        items.push(item);

        paymentTokens.push(address(mock1));
        paymentTokens.push(address(mock1));
        paymentTokens.push(address(mock2));

        market.purchaseMarketItems(items, paymentTokens, 0x0);

        assertEq(checkBalance(mock1, self), items[0].tokenPricesStart[0] * 2);
        assertEq(checkBalance(mock2, self), items[2].tokenPricesStart[1]);

        bytes32 itemHash0 = keccak256(abi.encode(items[0]));
        bytes32 itemHash1 = keccak256(abi.encode(items[2]));

        assertEq(market.totalSupply(itemHash0), 2);
        assertEq(market.totalSupply(itemHash1), 1);
        assertEq(market.numPurchases(itemHash0, self), 2);
        assertEq(market.numPurchases(itemHash1, self), 1);
    }

    function signPermit(ERC20 token, address owner, uint256 value, uint256 deadline, uint256 privateKey)
        public
        view
        returns (CRFTDMarketplace.ERC20Permit memory permit)
    {
        permit.token = token;
        permit.owner = owner;
        permit.value = value;
        permit.deadline = deadline;

        bytes32 permitHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        owner,
                        address(market),
                        value,
                        token.nonces(self),
                        deadline
                    )
                )
            )
        );

        (permit.v, permit.r, permit.s) = vm.sign(privateKey, permitHash);
    }

    function test_xxx() public {
        // // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // // these malleable signatures as well.
        // if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
        //     return (address(0), RecoverError.InvalidSignatureS);
        // }

        // // If the signature is valid (and not malleable), return the signer address
        // address signer = ecrecover(hash, v, r, s);
        // if (signer == address(0)) {
        //     return (address(0), RecoverError.InvalidSignature);
        // }

        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", keccak256("hello")));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPk, hash);
        bytes32 s2 = bytes32(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - uint256(s));
        uint8 v2 = v == 27 ? 28 : 27;

        console.log("v", v);
        console.log("r", uint256(r));
        console.log("s", uint256(s));

        console.log("v2", v2);
        console.log("r2", uint256(r));
        console.log("s2", uint256(s2));

        assertEq(ecrecover(hash, v, r, s), bob);
        assertEq(ecrecover(hash, v2, r, s2), bob);
    }

    // function test_purchaseMarketItemsWithPermit() public {
    //     vm.stopPrank();
    //     vm.startPrank(bob);

    //     items.push(item);
    //     items.push(item);

    //     paymentTokens.push(address(mock1));
    //     paymentTokens.push(address(mock2));

    //     vm.expectRevert();
    //     market.purchaseMarketItems(items, paymentTokens, 0x0);

    //     mock1.mint(bob, 100e18);
    //     mock2.mint(bob, 100e18);

    //     CRFTDMarketplace.ERC20Permit[] memory permits = new CRFTDMarketplace.ERC20Permit[](2);
    //     permits[0] = signPermit(mock1, bob, type(uint256).max, block.timestamp + 1 days, bobPk);
    //     permits[1] = signPermit(mock2, bob, type(uint256).max, block.timestamp + 1 days, bobPk);

    //     market.purchaseMarketItemsWithPermits(permits, items, paymentTokens, 0x0);

    //     // assertEq(checkBalance(mock1, self), item.tokenPricesStart[0]);

    //     // bytes32 itemHash = keccak256(abi.encode(item));

    //     // assertEq(market.totalSupply(itemHash), 1);
    //     // assertEq(market.numPurchases(itemHash, self), 1);
    // }

    function test_purchaseMarketItems_revert_MaxPurchasesReached() public {
        items.push(item);
        items.push(item);
        items.push(item);

        paymentTokens.push(address(mock1));
        paymentTokens.push(address(mock1));
        paymentTokens.push(address(mock1));

        vm.expectRevert(MaxPurchasesReached.selector);
        market.purchaseMarketItems(items, paymentTokens, 0x0);
    }

    function test_purchaseMarketItems_revert_NotActive() public {
        items.push(item);
        paymentTokens.push(address(mock1));

        items[0].start = block.timestamp + 1;

        vm.expectRevert(NotActive.selector);
        market.purchaseMarketItems(items, paymentTokens, 0x0);

        vm.warp(items[0].expiry + 1);

        vm.expectRevert(NotActive.selector);
        market.purchaseMarketItems(items, paymentTokens, 0x0);
    }

    function test_purchaseMarketItems_revert_InvalidPaymentToken() public {
        items.push(item);
        paymentTokens.push(address(mock1));

        paymentTokens[0] = address(0x1337);

        vm.expectRevert(InvalidPaymentToken.selector);
        market.purchaseMarketItems(items, paymentTokens, 0x0);
    }

    // FIX
    // function test_purchaseMarketItems_revert_InvalidEthAmount() public {
    //     item.acceptedPaymentTokens[0] = address(0);

    //     items.push(item);
    //     items.push(item);

    //     paymentTokens.push(address(0));
    //     paymentTokens.push(address(0));

    //     vm.expectRevert(InvalidEthAmount.selector);
    //     market.purchaseMarketItems(items, paymentTokens, 0x0);

    //     vm.expectRevert(InvalidEthAmount.selector);
    //     market.purchaseMarketItems{value: 123}(items, paymentTokens, 0x0);

    //     market.purchaseMarketItems{value: item.tokenPricesStart[0] * 2}(items, paymentTokens, 0x0);
    // }

    /* ------------- purchaseMarketItemsDutchAuction() ------------- */

    function test_purchaseMarketItemsDutchAuction() public {
        items.push(itemDutchAuction);
        paymentTokens.push(address(mock1));

        market.purchaseMarketItems(items, paymentTokens, 0x0);

        assertEq(checkBalance(mock1, self), itemDutchAuction.tokenPricesStart[0]);
    }

    function test_purchaseMarketItemsDutchAuction2() public {
        items.push(itemDutchAuction);
        paymentTokens.push(address(mock1));

        skip(1 hours / 3);

        uint256 expectedTokenPrice = calculateDAPrice(
            itemDutchAuction.tokenPricesStart[0],
            itemDutchAuction.tokenPricesEnd[0],
            itemDutchAuction.start,
            itemDutchAuction.end
        );

        market.purchaseMarketItems(items, paymentTokens, 0x0);

        assertEq(checkBalance(mock1, self), expectedTokenPrice);
    }

    function test_purchaseMarketItemsDutchAuction3() public {
        items.push(itemDutchAuction);
        paymentTokens.push(address(mock1));

        skip(10 hours);

        market.purchaseMarketItems(items, paymentTokens, 0x0);

        assertEq(checkBalance(mock1, self), itemDutchAuction.tokenPricesEnd[0]);
    }

    /* ------------- purchaseMarketItemsRaffle() ------------- */

    function test_purchaseMarketItemsRaffle() public {
        items.push(itemRaffle);
        paymentTokens.push(address(mock1));

        market.purchaseMarketItems(items, paymentTokens, 0x0);

        assertEq(checkBalance(mock1, self), itemRaffle.tokenPricesStart[0]);

        bytes32 itemHash = keccak256(abi.encode(itemRaffle));

        assertEq(market.getRaffleEntrants(itemHash)[0], self);
        assertEq(market.getRaffleWinners(itemHash, itemRaffle.raffleNumPrizes).length, 0);

        skip(1 days);

        vm.stopPrank();
        vm.prank(bob);
        market.revealRaffle(itemRaffle);

        assertEq(market.getRaffleWinners(itemHash, itemRaffle.raffleNumPrizes)[0], self);
    }

    function assertIncludes(address[] memory arr, address addr) internal {
        uint256 i;

        for (; i < arr.length; ++i) {
            if (arr[i] == addr) return;
        }

        assertTrue(i != arr.length, "Arr doesn't contain element");
    }

    function assertUnique(address[] memory arr) internal {
        uint256 arrLen = arr.length;

        for (uint256 i; i < arrLen; ++i) {
            for (uint256 j; j < arrLen; ++j) {
                if (i != j && arr[i] == arr[j]) {
                    emit log("Error: Duplicate Element found");
                    fail();
                }
            }
        }
    }

    function assertIsSubset(address[] memory a, address[] memory b) internal {
        uint256 lenA = a.length;
        uint256 lenB = b.length;

        uint256 j;

        for (uint256 i; i < lenA; ++i) {
            for (; j < lenB; ++j) {
                if (a[i] == a[j]) break;
            }
            if (j == lenB) {
                emit log("Error: Element does not exist");
                fail();
            }
        }
    }

    // function test_purchaseMarketItemsRaffle2() public {
    //     for (uint256 i; i < 20; i++) {
    //         address user = address(uint160(0x100 + i));

    //         mock1.mint(user, 1000 ether);

    //         vm.prank(user);
    //         mock1.approve(address(market), type(uint256).max);

    //         vm.prank(user);
    //         market.purchaseMarketItems(items, paymentTokens, 0x0);
    //     }

    //     skip(101 days);
    //     vm.roll(23);

    //     vm.prank(bob);
    //     market.revealRaffle(itemRaffle);

    //     bytes32 itemHash = keccak256(abi.encode(itemRaffle));

    //     address[] memory entrants = market.getRaffleEntrants(itemHash);
    //     address[] memory winners = market.getRaffleWinners(itemHash, itemRaffle.raffleNumPrizes);

    //     assertUnique(winners);
    //     assertIsSubset(winners, entrants);
    // }
}
