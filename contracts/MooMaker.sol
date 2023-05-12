// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
/**
TODO:
- Prevent signature replayability
 */
contract MooMaker {

    struct Order {
        IERC20 tokenIn;
        uint256 amountIn;
        IERC20 tokenOut;
        uint256 amountOut;
        uint256 validTo;
        address maker;
        uint256 nonce;
    } 

    bytes32 immutable DOMAIN_SEPARATOR; 

    //CoW rinkeby settlement contract
    address public constant authorizedAddress = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;

    mapping(address => bool) public isWhitelistedMaker;
    
    bytes32 constant EIP712DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    bytes32 constant ORDER_TYPEHASH = keccak256(
        "Order(address tokenIn, uint256 amountIn, address tokenOut, uint256 amountOut, uint256 validTo, address maker, uint256 nonce)"
    );


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

    function hashOrder(Order memory _order) private pure returns (bytes32) {
        return keccak256(abi.encode(
            ORDER_TYPEHASH,
            _order.tokenIn,
            _order.amountIn,
            _order.tokenOut,
            _order.amountOut,    
            _order.validTo,            
            _order.maker
        ));
    }

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

        // verify maker signature
        _requireValidSignature(_order.maker, hashToSign(hashOrder(_order)), _signature);

        require(block.timestamp < _order.validTo, "Expired");       

        // swap
        require(_order.tokenIn.transferFrom(msg.sender, _order.maker, _order.amountIn), "In transfer failed");
        require(_order.tokenOut.transferFrom(_order.maker, msg.sender, _order.amountOut), "Out transfer failed");
    } 


    function addMaker(address _maker) external {    
        isWhitelistedMaker[_maker] = true;
    }

    function removeMaker(address _maker) external {
        isWhitelistedMaker[_maker] = false;
    }  
}