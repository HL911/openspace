pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract MyERC721 is ERC721URIStorage {
    uint256 private _tokenIdCounter;

    constructor() ERC721(unicode"集训营", "CAMP") {}

    //  QmZNFPwox146ohY93ViFD8omSThRAVYF1A96MNHbWoa2Nr

    // ipfs://QmT4YDZ2dgTSpfHwPndnSuvHrAXNvtDBKNDUwN8nuZiVHT
    function mint(address student, string memory tokenURI)
        public
        returns (uint256)
    {
        uint256 newItemId = _tokenIdCounter;
        _mint(student, newItemId);
        _setTokenURI(newItemId, tokenURI);
        _tokenIdCounter++;
        return newItemId;
    }
}