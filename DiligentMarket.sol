// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "./DiligentNFTFactory.sol";
import "./DiligentNFT.sol";

// interface diligentNFTFactoryInterface {
//     function createNFTCollection(
//         string memory _name,
//         string memory _symbol,
//         uint256 _royalty
//     ) external;

//     function isDiligentNFT(address _nft) external view returns (bool);
// }

// interface diligentNFTInterface {
//     function getRoyalty() external view returns (uint256);

//     function getRoyaltyRecipient() external view returns (address);
// }

contract DiligentMarket is Ownable, ReentrancyGuard {
    DiligentNFTFactory private diligentNFTFactory;
    IUniswapV2Router02 public uniswapRouter;
    IUniswapV2Pair public uniswapPair;

    uint256 public marketplaceFee = 4;
    uint256 public devFee = 2;
    uint256 public buybackFee = 2;
    // uint256 public collectionUploadFeeETH = 0.15 ether;
    // address public devWallet;
    // address public WETH = 0x4200000000000000000000000000000000000006;
    // address public diligentToken = 0x55A6f6CB50DB03259f6Ab17979a4891313Be2f45;

    uint256 public collectionUploadFeeETH = 0.00015 ether;
    uint256 public collectionUploadFeeToken = 0.0001275 ether;
    address public devWallet = 0xF004126Dd874BA5A0AEADEeD45238aD5ABbec36B;
    address public WETH = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address public diligentToken = 0x275A1B6f58c1994a6E0cb595Ea0681da4Ce68302;

    mapping(uint256 => SellList) public sales;
    uint256 public salesId;

    struct SellList {
        address seller;
        address nft;
        uint256 tokenId;
        uint256 price;
        bool isSold;
    }

    /// @notice This is the emitted event, when a selling list is created
    event CreatedList(
        address _seller,
        address _nft,
        uint256 _sellId,
        uint256 _tokenId
    );

    /// @notice This is the emitted event, when a selling list is canceled
    event CanceledList(address _executor, uint256 _sellId);

    /// @notice This is the emitted event, when a buy is made
    event BoughtListToken(
        address _buyer,
        address _nft,
        uint256 _tokenId,
        uint256 _price
    );

    constructor(
        address _devWallet // diligentNFTFactoryInterface _diligentNFTFactory
    ) {
        devWallet = _devWallet;
        // uniswapRouter = IUniswapV2Router02(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24);
        uniswapRouter = IUniswapV2Router02(
            0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff
        );
        uniswapPair = IUniswapV2Pair(
            0xBe28c077744df81563Aa2919f1F3FFf0ae14cfE2
        );
        // diligentNFTFactory = _diligentNFTFactory;
    }

    /// @dev Update marketplaceFee amount
    function updateMarketplaceFee(uint256 _marketplaceFee) external onlyOwner {
        marketplaceFee = _marketplaceFee;
    }

    /// @dev Update devWalletFee amount
    function updateDevWalletFee(uint256 _devFee) external onlyOwner {
        devFee = _devFee;
    }

    /// @dev Update buybackFee amount
    function updateBuyBackFee(uint256 _buybackFee) external onlyOwner {
        buybackFee = _buybackFee;
    }

    /// @dev Update feeRecipient address
    function updateFeeRecipient(address _devWallet) external onlyOwner {
        devWallet = _devWallet;
    }

    /**
        @dev Create NFT list for sale 
        @return Return true if the selling list is created successfully
    **/
    function createList(
        address _nft,
        uint256 _tokenId,
        uint256 _price
    ) external returns (bool) {
        require(IERC721(_nft).ownerOf(_tokenId) == msg.sender, "not nft owner");
        require(
            _price > 0,
            "createList: unit price for the tokens need to be greater than 0"
        );

        sales[salesId] = SellList(msg.sender, _nft, _tokenId, _price, false);
        salesId++;

        emit CreatedList(msg.sender, _nft, salesId, _tokenId);
        return true;
    }

    /**
        @dev Cancel selling list
        @return Return true if the selling list is canceled successfully
    **/
    function cancelList(uint256 _sellId) external returns (bool) {
        require(
            _sellId < salesId,
            "cancelList: should be greater than selling list Id"
        );
        require(
            sales[_sellId].seller == msg.sender,
            "cancelList: should be the owner of the selling list"
        );
        require(
            sales[_sellId].isSold != true,
            "cancelList: total tokends were sold"
        );

        delete sales[_sellId];

        emit CanceledList(msg.sender, _sellId);
        return true;
    }

    /**
        @dev Buy NFT of selling list
        @return Return true if the NFT is bought successfully
    **/
    function buyListToken(uint256 _sellId) external payable returns (bool) {
        require(
            _sellId < salesId,
            "buyListToken: should be greater than selling list Id"
        );
        require(
            msg.value >= sales[_sellId].price,
            "buyListToken: needs to be greater or equal to the price"
        );

        require(
            sales[_sellId].seller != msg.sender,
            "buyListToken: needs to be a non seller address"
        );
        require(sales[_sellId].isSold != true, "buyListToken: token were sold");

        uint256 saleCost = sales[_sellId].price;
        uint256 fee = (saleCost * marketplaceFee) / 100;
        uint256 dev_fee = (saleCost * devFee) / 100;
        uint256 swap_Fee = (saleCost * buybackFee) / 100;
        uint256 receiveCost = saleCost - fee;

        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = diligentToken;

        uniswapRouter.swapExactETHForTokens{value: swap_Fee}(
            0,
            path,
            msg.sender,
            block.timestamp + 600
        );

        if (diligentNFTFactory.isDiligentNFT(sales[_sellId].nft)) {
            DiligentNFT nft = DiligentNFT(sales[_sellId].nft);
            address royaltyRecipient = nft.getRoyaltyRecipient();
            uint256 royalty = nft.getRoyalty();

            if (royalty > 0) {
                uint256 royaltyTotal = calculateRoyalty(royalty, saleCost);

                // Transfer royalty fee to collection owner
                payable(royaltyRecipient).transfer(royaltyTotal);
                receiveCost -= royaltyTotal;
            }
        }

        payable(sales[_sellId].seller).transfer(receiveCost);
        payable(devWallet).transfer(dev_fee);

        IERC721(sales[_sellId].nft).safeTransferFrom(
            sales[_sellId].seller,
            msg.sender,
            sales[_sellId].tokenId
        );

        sales[_sellId].isSold = true;

        emit BoughtListToken(
            msg.sender,
            sales[_sellId].nft,
            sales[_sellId].tokenId,
            sales[_sellId].price
        );
        return true;
    }

    /**
        @dev Transfer NFT to receiver address
        @return Return true if the NFT is transferred successfully
    **/
    function transfer(
        address _receiver,
        address _token,
        uint256 _tokenId
    ) external returns (bool) {
        IERC721(_token).safeTransferFrom(msg.sender, _receiver, _tokenId);
        return true;
    }

    function calculateRoyalty(
        uint256 _royalty,
        uint256 _price
    ) public pure returns (uint256) {
        return (_price * _royalty) / 10000;
    }

    function withdrawETH() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function withdrawToken(address _tokenAddr) external onlyOwner {
        require(
            IERC20(_tokenAddr).balanceOf(address(this)) > 0,
            "Insufficient Token balance"
        );

        IERC20(_tokenAddr).transfer(
            msg.sender,
            IERC20(_tokenAddr).balanceOf(address(this))
        );
    }

    function uploadCollectionWithETH()
        external
        payable
        nonReentrant
        returns (bool)
    {
        require(msg.value == collectionUploadFeeETH, "Incorrect ETH amount sent");

        return true;
    }

    function uploadCollectionWithToken()
        external
        nonReentrant
        returns (bool)
    {
        uint256 feeETH = collectionUploadFeeToken;
        uint256 reserve0;
        uint256 reserve1;
        (reserve0, reserve1, ) = uniswapPair.getReserves();
        address token0 = uniswapPair.token0();

        // Paid in $DILIGENT
        uint256 amount;
        if (token0 == diligentToken) {
            amount = (feeETH * reserve0) / reserve1;
        } else {
            amount = (feeETH * reserve1) / reserve0;
        }

        require(
            IERC20(diligentToken).balanceOf(msg.sender) > amount,
            "Insufficient Token balance"
        );

        IERC20(diligentToken).transferFrom(msg.sender, address(this), amount);

        return true;
    }

    function getDiligentTokenPrice() public view returns (uint256) {
        (uint256 reserve0, uint256 reserve1, ) = uniswapPair.getReserves();
        address token0 = uniswapPair.token0();

        if (token0 == diligentToken) {
            return (reserve1 * 1e18) / reserve0;
        } else {
            return (reserve0 * 1e18) / reserve1;
        }
    }
}
