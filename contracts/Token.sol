// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/access/AccessControl.sol";
// import "@openzeppelin/contracts/interfaces/IERC721.sol";

// import "./Staking.sol";

// contract Token is AccessControl {
//     bytes32 public constant MINT_AUTHORITY = keccak256("MINT_AUTHORITY");
//     bytes32 public constant BURN_AUTHORITY = keccak256("BURN_AUTHORITY");

//     address public treasuryAddress = address(0xb0b);

//     constructor(IERC721 nft) ERC20("Token", "TKN", 18) Staking(nft) {
//         _setupRole(DEFAULT_ADMIN_ROLE, treasuryAddress);
//         _mint(treasuryAddress, 10_000_000 * 1e18);
//     }

//     /* ------------- Restricted ------------- */

//     function mint(address user, uint256 amount) external payable onlyRole(MINT_AUTHORITY) {
//         _mint(user, amount);
//     }

//     /* ------------- ERC20Burnable ------------- */

//     function burn(uint256 amount) external payable {
//         _burn(msg.sender, amount);
//     }

//     function burnFrom(address user, uint256 amount) external payable {
//         if (!hasRole(BURN_AUTHORITY, msg.sender)) {
//             uint256 allowed = allowance[user][msg.sender];
//             if (allowed != type(uint256).max) allowance[user][msg.sender] = allowed - amount;
//         }
//         _burn(user, amount);
//     }

//     /* ------------- MultiCall ------------- */

//     // handy tool; can be dangerous for contracts that accept eth as payment
//     function multiCall(bytes[] calldata data) external payable {
//         unchecked {
//             for (uint256 i; i < data.length; ++i) address(this).delegatecall(data[i]);
//         }
//     }

//     /* ------------- Owner ------------- */

//     function withdraw() external onlyOwner {
//         uint256 balance = address(this).balance;
//         payable(msg.sender).transfer(balance);
//     }

//     function recoverToken(ERC20 token) external onlyOwner {
//         uint256 balance = token.balanceOf(address(this));
//         token.transfer(msg.sender, balance);
//     }

//     function recoverNFT(IERC721 token, uint256 id) external onlyOwner {
//         token.transferFrom(address(this), msg.sender, id);
//     }
// }
