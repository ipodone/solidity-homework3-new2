// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MyNFT
 * @dev 一个完整的NFT合约实现，支持铸造、元数据管理和供应量控制
 * @notice 使用OpenZeppelin库实现标准ERC721功能
 */
contract MyNFT is ERC721, ERC721URIStorage, Ownable {
    // Token ID计数器
    uint256 private _tokenIdCounter;
    
    // 最大供应量
    uint256 public constant MAX_SUPPLY = 10000;
    
    // 铸造价格
    uint256 public mintPrice = 0.00001 ether;
    
    /**
     * @dev NFT铸造事件
     * @param minter 铸造者地址
     * @param tokenId 新创建的Token ID
     * @param uri 元数据URI
     */
    event NFTMinted(
        address indexed minter, 
        uint256 indexed tokenId, 
        string uri
    );
    
    /**
     * @dev 构造函数
     * @notice 初始化NFT集合名称和符号，设置合约所有者
     */
    constructor() ERC721("MyNFT", "MNFT") Ownable(msg.sender) {}
    
    /**
     * @dev 铸造NFT
     * @param uri NFT的元数据URI（通常是IPFS链接）
     * @return 新创建的Token ID
     * @notice 需要支付mintPrice的ETH才能铸造
     */
    function mint(string memory uri) public payable returns (uint256) {
        // 检查供应量限制
        require(_tokenIdCounter < MAX_SUPPLY, "Max supply reached");
        
        // 检查支付金额
        require(msg.value >= mintPrice, "Insufficient payment");
        
        // 递增计数器
        _tokenIdCounter++;
        uint256 newTokenId = _tokenIdCounter;
        
        // 安全铸造NFT
        _safeMint(msg.sender, newTokenId);
        
        // 设置元数据URI
        _setTokenURI(newTokenId, uri);
        
        // 触发事件
        emit NFTMinted(msg.sender, newTokenId, uri);
        
        return newTokenId;
    }
    
    /**
     * @dev 重写tokenURI函数
     * @param tokenId Token ID
     * @return 元数据URI
     * @notice 需要重写以解决多重继承的冲突
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
    
    /**
     * @dev 检查接口支持
     * @param interfaceId 接口ID
     * @return 是否支持该接口
     * @notice 实现ERC165标准，支持接口查询
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    
    /**
     * @dev 查询总供应量
     * @return 已铸造的NFT数量
     */
    function totalSupply() public view returns (uint256) {
        return _tokenIdCounter;
    }
    
    /**
     * @dev 提取铸造费用
     * @notice 只有合约所有者可以调用
     */
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }
    
    /**
     * @dev 设置铸造价格
     * @param newPrice 新的铸造价格（wei）
     * @notice 只有合约所有者可以调用
     */
    function setMintPrice(uint256 newPrice) public onlyOwner {
        mintPrice = newPrice;
    }
}