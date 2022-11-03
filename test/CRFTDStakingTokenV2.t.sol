// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CRFTDStakingTokenV1} from "CRFTD/legacy/CRFTDStakingToken.sol";
import {CRFTDStakingToken as CRFTDStakingTokenRoot} from "CRFTD/CRFTDStakingTokenRoot.sol";
import {CRFTDStakingToken as CRFTDStakingTokenChild} from "CRFTD/CRFTDStakingTokenChild.sol";

import "CRFTD/CRFTDStakingTokenRoot.sol" as RootErrors;
import "CRFTD/CRFTDStakingTokenChild.sol" as ChildErrors;

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import {MockERC20UDS} from "UDS/../test/mocks/MockERC20UDS.sol";
import {MockERC721UDS} from "UDS/../test/mocks/MockERC721UDS.sol";

import {MockFxTunnel} from "./mocks/MockFxTunnel.sol";
import {TestCRFTDStakingToken} from "./CRFTDStakingToken.t.sol";

import "forge-std/Test.sol";
import "futils/futils.sol";

contract TestCRFTDStakingTokenV2 is TestCRFTDStakingToken {
    using futils for *;

    address logicV2;
    address logicChild;

    MockCRFTDStakingTokenRoot tokenV2;
    CRFTDStakingTokenChild tokenChild;

    address fxTunnel;

    function setUp() public override {
        TestCRFTDStakingToken.setUp();

        fxTunnel = address(new MockFxTunnel());

        logicV2 = address(new MockCRFTDStakingTokenRoot(address(0), fxTunnel));
        logicChild = address(new CRFTDStakingTokenChild(fxTunnel));

        bytes memory initCall = abi.encodeWithSelector(CRFTDStakingTokenChild.init.selector, "TokenChild", "TKNCHLD");
        tokenChild = CRFTDStakingTokenChild(address(new ERC1967Proxy(logicChild, initCall)));
        tokenChild.setFxRootTunnel(address(token));

        vm.label(address(nft), "nftRoot");
        vm.label(address(token), "tokenV1");
        vm.label(address(fxTunnel), "fxTunnel");
        vm.label(address(tokenChild), "tokenChild");
    }

    function upgradeToken() internal {
        skip(5 days);

        token.upgradeToAndCall(logicV2, "");

        tokenV2 = MockCRFTDStakingTokenRoot(address(token));

        vm.label(address(token), "tokenV2Root");
    }

    /* ------------- setUp() ------------- */

    function test_setUpV2() public {
        upgradeToken();

        resetBalance();

        test_setUp();
    }

    /* ------------- stake() ------------- */

    function test_stakeV2() public {
        test_stake2();

        upgradeToken();

        resetBalance();

        test_stake2();
    }

    function test_stakeV2(
        uint256 amountIn,
        uint256 amountOut,
        uint256 r
    ) public {
        amountIn = bound(amountIn, 0, 20);

        test_stake(amountIn, amountOut, r);

        upgradeToken();

        resetBalance();

        unchecked {
            r += 666;
        }

        test_stake(amountIn, amountOut, r);
    }

    /* ------------- migration() ------------- */

    uint256 constant MIGRATION_START_DATE = (1 << 42) - 1;

    function test_safeMigrate() public {
        token.stake(address(nft), [1, 4, 3].toMemory());

        upgradeToken();

        tokenV2.startMigration(address(tokenChild));

        assertEq(tokenV2.fxChildTunnel(), address(tokenChild));
        assertEq(tokenV2.rewardEndDate(), MIGRATION_START_DATE);

        uint256[][] memory ids = new uint256[][](1);
        ids[0] = token.stakedIdsOf(address(nft), tester, 77);

        uint256 migratedBalance = tokenV2.totalBalanceOf(tester);

        assertTrue(migratedBalance > 0);

        tokenV2.safeMigrate([address(nft)].toMemory(), ids);

        skip(10 days);

        assertEq(tokenV2.balanceOf(tester), 0);
        assertEq(tokenV2.totalBalanceOf(tester), 0);

        assertEq(tokenV2.ownerOf(address(nft), 1), tester);
        assertEq(tokenV2.ownerOf(address(nft), 3), tester);
        assertEq(tokenV2.ownerOf(address(nft), 4), tester);

        assertEq(tokenChild.ownerOf(address(nft), 1), tester);
        assertEq(tokenChild.ownerOf(address(nft), 3), tester);
        assertEq(tokenChild.ownerOf(address(nft), 4), tester);

        assertEq(tokenChild.balanceOf(tester), migratedBalance);

        skip(10 days);
    }

    /// user has already migrated and migrates further balances
    function test_safeMigrate2() public {
        test_safeMigrate();

        skip(10 days);

        address(tokenChild).balanceDiff(tester);

        tokenV2.safeMigrate(new address[](0), new uint256[][](0));

        assertEq(tokenV2.balanceOf(tester), 0);
        assertEq(tokenV2.totalBalanceOf(tester), 0);

        assertEq(address(tokenChild).balanceDiff(tester), 0);

        skip(10 days);

        tokenV2.mint(tester, 333e18);

        tokenV2.safeMigrate(new address[](0), new uint256[][](0));

        assertEq(tokenV2.balanceOf(tester), 0);
        assertEq(tokenV2.totalBalanceOf(tester), 0);

        assertEq(address(tokenChild).balanceDiff(tester), 333e18);

        assertEq(tokenV2.ownerOf(address(nft), 1), tester);
        assertEq(tokenV2.ownerOf(address(nft), 3), tester);
        assertEq(tokenV2.ownerOf(address(nft), 4), tester);

        assertEq(tokenChild.ownerOf(address(nft), 1), tester);
        assertEq(tokenChild.ownerOf(address(nft), 3), tester);
        assertEq(tokenChild.ownerOf(address(nft), 4), tester);
    }

    /// user migrates with incomplete ids
    function test_safeMigrate_revert_MigrationIncomplete() public {
        token.stake(address(nft), [1, 3, 4].toMemory());

        upgradeToken();

        tokenV2.startMigration(address(tokenChild));

        uint256[][] memory ids = new uint256[][](1);
        ids[0] = [1, 4].toMemory();

        vm.expectRevert(RootErrors.MigrationIncomplete.selector);
        tokenV2.safeMigrate([address(nft)].toMemory(), ids);
    }

    /// user has already migrated and tries safe migrate again
    function test_safeMigrate_revert_MigrationIncomplete2() public {
        test_safeMigrate();

        uint256[][] memory ids = new uint256[][](1);
        ids[0] = [1].toMemory();

        vm.expectRevert(RootErrors.MigrationIncomplete.selector);
        tokenV2.safeMigrate([address(nft)].toMemory(), ids);
    }

    function test_safeMigrate_guard_exploit() public {
        token.stake(address(nft), [1, 3, 4].toMemory());

        upgradeToken();

        tokenV2.startMigration(address(tokenChild));

        uint256[][] memory ids = new uint256[][](1);
        ids[0] = [1, 1, 1].toMemory();

        tokenV2.safeMigrate([address(nft)].toMemory(), ids);

        skip(10 days);

        assertEq(tokenV2.ownerOf(address(nft), 1), tester);
        assertEq(tokenV2.ownerOf(address(nft), 3), tester);
        assertEq(tokenV2.ownerOf(address(nft), 4), tester);

        assertEq(tokenChild.ownerOf(address(nft), 1), tester);
        assertEq(tokenChild.ownerOf(address(nft), 3), address(0));
        assertEq(tokenChild.ownerOf(address(nft), 4), address(0));
    }

    function test_safeMigrate_revert_MigrationNotStarted() public {
        upgradeToken();

        vm.expectRevert(RootErrors.MigrationNotStarted.selector);

        tokenV2.safeMigrate(new address[](0), new uint256[][](0));
    }

    function test_synchronizeIdsWithChild_revert_MigrationNotStarted() public {
        upgradeToken();

        vm.expectRevert(RootErrors.MigrationNotStarted.selector);

        tokenV2.synchronizeIdsWithChild(new address[](0), new uint256[][](0));
    }

    function test_revert_MigrationRequired() public {
        token.stake(address(nft), [1].toMemory());

        skip(10 days);

        upgradeToken();

        tokenV2.startMigration(address(tokenChild));

        vm.expectRevert(RootErrors.MigrationRequired.selector);
        tokenV2.stake(address(nft), [2].toMemory());

        vm.expectRevert(RootErrors.MigrationRequired.selector);
        tokenV2.unstake(address(nft), [1].toMemory());

        vm.expectRevert(RootErrors.MigrationRequired.selector);
        tokenV2.synchronizeIdsWithChild(new address[](0), new uint256[][](0));
    }
}

contract MockCRFTDStakingTokenRoot is CRFTDStakingTokenRoot {
    constructor(address checkpointManager, address fxRoot) CRFTDStakingTokenRoot(checkpointManager, fxRoot) {}

    function burn(address from, uint256 value) public {
        _burn(from, value);
    }

    function mint(address to, uint256 quantity) public {
        _mint(to, quantity);
    }
}
