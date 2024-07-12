// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract DiligentNFT is ERC721, Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    mapping(uint256 => string) private _tokenURIs;

    uint256 private royalty;
    address payable private royaltyRecipient;
    // Royalty percentage
    uint256 public royaltyPercentage;

    event NewNFTMinted(uint256 tokenId, address owner, string tokenUri);

    constructor(
        string memory _name, 
        string memory _symbol, 
        address _owner,
        uint256 _royalty,
        address _royaltyRecipient
    ) ERC721(_name, _symbol) {
        require(_royalty <= 1000, "can't more than 10 percent");
        require(_royaltyRecipient != address(0));
        royalty = _royalty;
        royaltyRecipient = payable(_royaltyRecipient);
        transferOwnership(_owner);
    }

    function Mint(address _to, string memory _uri) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(_to, tokenId);
        _setTokenURI(tokenId, _uri);

        emit NewNFTMinted(tokenId, _to, _uri);
    }

    // Burn existing NFT
    function burn(
        uint256 tokenId
    ) internal {
        super._burn(tokenId);
    }

     function _tokenURI(
        uint256 tokenId
    ) public view returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function getRoyalty() external view returns (uint256) {
        return royalty;
    }

    function getRoyaltyRecipient() external view returns (address) {
        return royaltyRecipient;
    }

    function updateRoyalty(uint256 _royalty) external onlyOwner {
        require(_royalty <= 10000, "can't more than 10 percent");
        royalty = _royalty;
    }

    function _setTokenURI(uint256 tokenId, string memory _uri) internal {
        _tokenURIs[tokenId] = _uri;
    }
}