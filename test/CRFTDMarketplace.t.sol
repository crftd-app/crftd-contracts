// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import "solmate/test/utils/mocks/MockERC20.sol";
import "solmate/tokens/WETH.sol";

import "CRFTD/CRFTDMarketplace.sol";
import "ArrayUtils/ArrayUtils.sol";

contract TestMarketplace is Test {
    using ArrayUtils for *;

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

    address bob = address(0xb0b);
    address alice = address(0xbabe);
    address tester = address(this);

    function setUp() public {
        weth = new WETH();

        market = new CRFTDMarketplace(payable(weth));

        mock1 = new MockERC20("", "", 18);
        mock2 = new MockERC20("", "", 18);

        mock1.approve(address(market), type(uint256).max);
        mock2.approve(address(market), type(uint256).max);

        mock1.mint(tester, 100e18);
        mock2.mint(tester, 100e18);

        paymentTokens.push(address(mock1));

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

        items.push(item);

        itemDutchAuction = item;
        itemDutchAuction.end = block.timestamp + 1 hours;
        itemDutchAuction.tokenPricesEnd.push(0e18);
        itemDutchAuction.tokenPricesEnd.push(20e18);

        itemsDutchAuction.push(itemDutchAuction);

        itemRaffle = item;
        itemRaffle.maxSupply = 20;
        itemRaffle.raffleNumPrizes = 10;
        itemRaffle.raffleControllers.push(bob);

        itemsRaffle.push(itemRaffle);

        checkBalance(mock1, tester);
    }

    /* ------------- helpers ------------- */

    mapping(address => mapping(address => uint256)) _balance_check;

    function checkBalance(MockERC20 token, address user) internal returns (uint256) {
        uint256 balance = token.balanceOf(user);
        uint256 balanceBefore = _balance_check[address(token)][user];

        if (balanceBefore == 0) {
            return _balance_check[address(token)][user] = balance;
        } else {
            _balance_check[address(token)][user] = balance;
            return balanceBefore - balance;
        }
    }

    function calculateDAPrice(
        uint256 startPrice,
        uint256 endPrice,
        uint256 start,
        uint256 end
    ) internal view returns (uint256) {
        uint256 timestamp = block.timestamp > end ? end : block.timestamp;

        return startPrice - ((startPrice - endPrice) * (timestamp - start)) / (end - start);
    }

    /* ------------- purchaseMarketItems() ------------- */

    function test_purchaseMarketItems() public {
        market.purchaseMarketItems(items, paymentTokens);

        assertEq(checkBalance(mock1, tester), item.tokenPricesStart[0]);

        bytes32 itemHash = keccak256(abi.encode(item));

        assertEq(market.totalSupply(itemHash), 1);
        assertEq(market.numPurchases(itemHash, tester), 1);
    }

    function test_purchaseMarketItems2() public {
        items.push(item);
        paymentTokens.push(address(mock1));

        market.purchaseMarketItems(items, paymentTokens);

        assertEq(checkBalance(mock1, tester), item.tokenPricesStart[0] * 2);

        bytes32 itemHash = keccak256(abi.encode(item));

        assertEq(market.totalSupply(itemHash), 2);
        assertEq(market.numPurchases(itemHash, tester), 2);
    }

    /* ------------- purchaseMarketItemsDutchAuction() ------------- */

    function test_purchaseMarketItemsDutchAuction() public {
        market.purchaseMarketItems(itemsDutchAuction, paymentTokens);

        assertEq(checkBalance(mock1, tester), itemDutchAuction.tokenPricesStart[0]);
    }

    function test_purchaseMarketItemsDutchAuction2() public {
        skip(1 hours / 3);

        uint256 expectedTokenPrice = calculateDAPrice(
            itemDutchAuction.tokenPricesStart[0],
            itemDutchAuction.tokenPricesEnd[0],
            itemDutchAuction.start,
            itemDutchAuction.end
        );

        market.purchaseMarketItems(itemsDutchAuction, paymentTokens);

        assertEq(checkBalance(mock1, tester), expectedTokenPrice);
    }

    function test_purchaseMarketItemsDutchAuction3() public {
        skip(10 hours);

        market.purchaseMarketItems(itemsDutchAuction, paymentTokens);

        assertEq(checkBalance(mock1, tester), itemDutchAuction.tokenPricesEnd[0]);
    }

    /* ------------- purchaseMarketItemsRaffle() ------------- */

    function test_purchaseMarketItemsRaffle() public {
        market.purchaseMarketItems(itemsRaffle, paymentTokens);

        assertEq(checkBalance(mock1, tester), itemRaffle.tokenPricesStart[0]);

        bytes32 itemHash = keccak256(abi.encode(itemRaffle));

        assertEq(market.getRaffleEntrants(itemHash)[0], tester);
        assertEq(market.getRaffleWinners(itemHash, itemRaffle.raffleNumPrizes).length, 0);

        skip(1 days);

        vm.prank(bob);
        market.revealRaffle(itemRaffle);

        assertEq(market.getRaffleWinners(itemHash, itemRaffle.raffleNumPrizes)[0], tester);
    }

    function assertIncludes(address[] memory arr, address addr) internal {
        uint256 i;

        for (; i < arr.length; ++i) if (arr[i] == addr) return;

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

    function test_purchaseMarketItemsRaffle2() public {
        for (uint256 i; i < 20; i++) {
            address user = address(uint160(0x100 + i));

            mock1.mint(user, 1000 ether);

            vm.prank(user);
            mock1.approve(address(market), type(uint256).max);

            vm.prank(user);
            market.purchaseMarketItems(itemsRaffle, paymentTokens);
        }

        skip(101 days);
        vm.roll(23);

        vm.prank(bob);
        market.revealRaffle(itemRaffle);

        bytes32 itemHash = keccak256(abi.encode(itemRaffle));

        address[] memory entrants = market.getRaffleEntrants(itemHash);
        address[] memory winners = market.getRaffleWinners(itemHash, itemRaffle.raffleNumPrizes);

        assertUnique(winners);
        assertIsSubset(winners, entrants);
    }
}
