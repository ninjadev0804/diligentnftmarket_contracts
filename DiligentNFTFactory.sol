// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./DiligentNFT.sol";

/* diligent diligentNFT Factory
    Create new diligent diligentNFT collection
*/
contract DiligentNFTFactory {
    // owner address => nft list
    mapping(address => address[]) private nfts;

    mapping(address => bool) private diligentNFT;

    event CreatedNFTCollection(
        address creator,
        address nft,
        string name,
        string symbol
    );

    function createNFTCollection(
        string memory _name,
        string memory _symbol,
        uint256 _royalty,
        address payable _royaltyRecipient
    ) external {
        DiligentNFT nft = new DiligentNFT(
            _name,
            _symbol,
            msg.sender,
            _royalty,
            _royaltyRecipient
        );
        nfts[msg.sender].push(address(nft));
        diligentNFT[address(nft)] = true;
        emit CreatedNFTCollection(msg.sender, address(nft), _name, _symbol);
    }

    function getOwnCollections() external view returns (address[] memory) {
        return nfts[msg.sender];
    }

    function isDiligentNFT(address _nft) external view returns (bool) {
        return diligentNFT[_nft];
    }
}