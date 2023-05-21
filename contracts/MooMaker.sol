// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MooMaker{

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
        address tokenIn;
        uint256 amountIn;
        address tokenOut;
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

    function addMaker(address _maker) external {    
        isWhitelistedMaker[_maker] = true;
    } 

    function removeMaker(address _maker) external {
        isWhitelistedMaker[_maker] = false;
    }  

    function _invalidateOrder(bytes32 _hash) internal {
        require(!invalidatedOrders[_hash], "Invalid Order");
        invalidatedOrders[_hash] = true;
    }       

    //hashes order data
    function _hashOrder(Order memory _order) public pure returns (bytes32) {
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

    //generates final hash including domain separator to be signed by maker from received order hash
    function getEthSignedMessageHash(bytes32 _orderHash)
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

    //view function that can be called by test maker to generate hash that maker has to sign
    function generateEIP712Hash(Order memory _order) public view returns (bytes32) {
        return getEthSignedMessageHash(_hashOrder(_order));
    } 

    function recoverSigner(
        bytes32 _hash,
        bytes memory signature
    ) public view returns (address) {
        bytes32 r;
        bytes32 s;
        uint8 v;
        bytes32 messageHash = getEthSignedMessageHash(_hash);

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        if (v < 27) {
            v += 27;
        }

        return ecrecover(messageHash, v, r, s);
    }   

    function swap(Order memory _order, bytes memory _signature) external {
        // only cow contract can execute swap
        //require(msg.sender == authorizedAddress, "Unauthorized");

        // maker must be whitelisted
        //require(isWhitelistedMaker[_order.maker], "Not Maker");  

        //checking that it is not to late to use maker quote
        //require(block.timestamp < _order.validTo, "Expired");  

        // verify maker signature
        bytes32 orderhash = _hashOrder(_order);
        address recsigner = recoverSigner(orderhash, _signature);          
        require(recsigner == _order.maker, "Ivalid signature");  

        //Checking that quote is not reused
        _invalidateOrder(orderhash);

        // swap
        IERC20 tokenIn = IERC20(_order.tokenIn);
        IERC20 tokenOut = IERC20(_order.tokenOut);
        require(tokenIn.transferFrom(msg.sender, _order.maker, _order.amountIn), "In transfer failed");
        require(tokenOut.transferFrom(_order.maker, msg.sender, _order.amountOut), "Out transfer failed");

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
}
