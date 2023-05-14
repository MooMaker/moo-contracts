// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract MooMaker is Ownable2Step{

    event Swap(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 amountOut,
        uint256 validTo,
        address indexed maker,
        bytes indexed uid
    );

    struct Order {
        IERC20 tokenIn;
        uint256 amountIn;
        IERC20 tokenOut;
        uint256 amountOut;
        uint256 validTo;
        address maker;
        bytes uid; // cow order id
    } 

    bytes32 immutable DOMAIN_SEPARATOR; 

    //CoW rinkeby/gnosis/mainnet settlement contract
    address public constant authorizedAddress = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;

    mapping(address => bool) public isWhitelistedMaker;
    
    bytes32 constant EIP712DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    bytes32 constant ORDER_TYPEHASH = keccak256(
        "Order(address tokenIn,uint256 amountIn,address tokenOut,uint256 amountOut,uint256 validTo,address maker,bytes uid)"
    );

    //used to invalidtaed executed trades to avoid reusage of maker quote
    mapping(bytes32 => bool) public invalidatedOrders;


    constructor() {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712DOMAIN_TYPEHASH,
                keccak256("MooMaker"), // contract name
                keccak256("1"), // Version
                block.chainid,
                address(this)
            )
        );
    }

    //generates hash to be signed by maker from received order hash
    function hashToSign(bytes32 _orderHash)
        public
        view
        returns (bytes32 hash)
    {
        return keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            _orderHash
        ));
    }

    //hashes order data
    function _hashOrder(Order memory _order) private pure returns (bytes32) {
        return keccak256(abi.encode(
            ORDER_TYPEHASH,
            _order.tokenIn,
            _order.amountIn,
            _order.tokenOut,
            _order.amountOut,    
            _order.validTo,        
            _order.maker,
            _order.uid
        ));
    }

    //view function that can be called by test maker to generate hash that maker has to sign
    function generateEIP712Hash(Order memory _order) public view returns (bytes32) {
        return hashToSign(_hashOrder(_order));
    } 


    //checks validity of signature before settlement
    function _requireValidSignature(address _signer, bytes32 _orderHash, bytes calldata _signature) internal view {
        require(
                SignatureChecker.isValidSignatureNow(_signer, _orderHash, _signature),
                "Invalid signature"
        );
    }  

    function swap(Order calldata _order, bytes calldata _signature) external {
        // only cow contract can execute swap
        require(msg.sender == authorizedAddress, "Unauthorized");

        // maker must be whitelisted
        require(isWhitelistedMaker[_order.maker], "Not Maker");  

        //checking that it is not to late to use maker quote
        require(block.timestamp < _order.validTo, "Expired");  

        bytes32 orderhash = _hashOrder(_order);        

        // verify maker signature
        _requireValidSignature(_order.maker, hashToSign(orderhash), _signature);        

        //Checking that quote is not reused
        _invalidateOrder(orderhash);

        // swap
        require(_order.tokenIn.transferFrom(msg.sender, _order.maker, _order.amountIn), "In transfer failed");
        require(_order.tokenOut.transferFrom(_order.maker, msg.sender, _order.amountOut), "Out transfer failed");

        emit Swap(
            address(_order.tokenIn),
            _order.amountIn,
            address(_order.tokenOut),
            _order.amountOut,    
            _order.validTo,        
            _order.maker,
            _order.uid
        );
    } 


    function addMaker(address _maker) external onlyOwner {    
        isWhitelistedMaker[_maker] = true;
    } 

    function removeMaker(address _maker) external onlyOwner {
        isWhitelistedMaker[_maker] = false;
    }  

    function _invalidateOrder(bytes32 _hash) internal {
        require(!invalidatedOrders[_hash], "Invalid Order");
        invalidatedOrders[_hash] = true;
    }       
}
