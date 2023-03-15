
import "../interfaces/allowlist/IAllowlistManager.sol";
contract AllowlistManagerMock is IAllowlistManager {


    function addressIsAllowed(uint256 _commitmentId, address _account) public returns (bool _allowed) {
      return true;
    }


}
