// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma abicoder v2; // 복합 경로(bytes path) 처리를 위해 필요

// OpenZeppelin 3.x/4.x 버전에 따른 일반적인 경로
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol"; 
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import './interfaces/IUniswapV3Pool.sol';

/**
 * @title AquaFeeCollector
 * @dev 업그레이드 가능한 방식으로 구현된 유니스왑 V3 수수료 수거 및 바이백 컨트랙트
 */
contract AquaFeeCollector is Initializable {
    using SafeERC20 for IERC20;

    address public constant BURN_ADDRESS = address(0xdead);
    address public owner;

    mapping(address => uint256) public totalBurned; 

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    event OwnerChanged(address indexed oldOwner, address indexed newOwner);

    function initialize() public initializer {
        owner = msg.sender; // 초기 배포자를 오너로 설정
    }

    /**
     * @notice 여러 풀에서 프로토콜 수수료를 일괄 수거합니다.
     * @dev Pool의 collectProtocol 로직이 수정되었으므로, 자금은 자동으로 이 컨트랙트(feeTo)로 들어옵니다.
     */
    function batchCollect(address[] calldata pools) external onlyOwner {
        for (uint256 i = 0; i < pools.length; i++) {
            // Pool 컨트랙트가 msg.sender == feeTo(이 컨트랙트)인지 확인할 것입니다.
            IUniswapV3Pool(pools[i]).collectProtocol(type(uint128).max, type(uint128).max);
        }
    }

    /**
     * @notice 컨트랙트에 쌓인 특정 토큰을 외부로 인출합니다. (비상용 또는 기타 용도)
     */
    function withdraw(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(to, amount);
    }

    function setOwner(address _owner) external onlyOwner {
        require(msg.sender == owner);
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }

    /**
     * @notice 소각 기능 업데이트: 누적 수치 기록
     */
    function burn(address token, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount zero");
        
        // 데이터 기록
        totalBurned[token] += amount;
        
        // 실제 소각 (0xdead로 전송)
        IERC20(token).safeTransfer(BURN_ADDRESS, amount);
    }

    function getVersion() external pure returns (string memory) {
        return "V1.0 - Multi-Token Tracking";
    }
}