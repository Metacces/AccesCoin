// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract bridge_BSC is ReentrancyGuard, Pausable, Ownable {

    IERC20 public Acces = IERC20(0x1E5c718b4377B5deEEF01AFf5BDC29a9528df1A3);

    address[] public gatewayWallets;

    uint256 public swapFee = 0 gwei;
    uint256 public cooldownTime = 3 minutes;

    bytes32[] public pendingSwaps;
    bytes32[] public pendingBalanceSwaps;

    enum SwapStatus {
        None,
        Created,
        PendingSwap,
        Processed,
        Completed,
        PendingBalance
    }

    struct UserData {
        uint256 amount;
        address recipient;
        SwapStatus status;
    }

    struct SwapRequest {
        address sender;
        uint256 amount;
        address recipient;
        uint256 confirmations;
        bool executed;
        uint256 Type; // 1 = To EVM  -  2 = From EVM
        uint256 chainId;
        SwapStatus status;
    }

    mapping(address => bytes32[]) private userSwapIds;
    mapping(bytes32 => bool) private isSwapId;

    mapping(address => bool) public isAdmin;
    mapping(bytes32 => SwapRequest) public swapRequests;
    mapping(bytes32 => address[]) public swapApprovals;
    mapping(address => mapping(bytes32 => UserData)) public userSwaps;
    mapping(address => bytes32) public lastUserSwap;
    mapping(address => uint256) public lastSwapTime;

    modifier onlyAdmin() {
        require(isAdmin[msg.sender] = true, "User not admin");
        _;
    }

    modifier rateLimited(address _user) {
        if (!isAdmin[_user]) {
            require(
                block.timestamp - lastSwapTime[_user] >= cooldownTime,
                "You must wait before initiating another swap"
            );
        }
        _;
    }

    event TokensLocked(
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        bytes32 swapId,
        uint256 chainId
    );
    event TokensUnlocked(address indexed user, uint256 amount);
    event SwapProcessed(bytes32 indexed swapId);
    event SwapPending(bytes32 indexed swapId);
    event SwapPendingBalance(bytes32 indexed swapId);

    constructor(address[] memory _gateways) Ownable(msg.sender) {
        isAdmin[msg.sender] = true;
        for(uint256 i = 0; i < 6; i++){
            setGatewayWallets(_gateways[i]);
        }
    }

    function setAdmin(address _admin, bool _new) external onlyOwner {
        if (_new == true) {
            isAdmin[_admin] = true;
        } else {
            isAdmin[_admin] = false;
        }
    }

    function setGatewayWallets(address _wallet) public onlyOwner {
        gatewayWallets.push(_wallet);
    }

    function removeGatewayWallet(address walletToRemove) external onlyOwner {
        int256 index = findWalletIndex(walletToRemove);
        require(index >= 0, "Wallet not found in gateway wallets");

        // Remove wallet from the array
        for (uint256 i = uint256(index); i < gatewayWallets.length - 1; i++) {
            gatewayWallets[i] = gatewayWallets[i + 1];
        }
        gatewayWallets.pop();
    }

    function getAllGatewayWallets() external view returns (address[] memory) {
        return gatewayWallets;
    }

    function setSwapFee(uint256 _newFee) external onlyOwner {
        swapFee = _newFee;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function isGatewayWallet(address _address) internal view returns (bool) {
        for (uint256 i = 0; i < gatewayWallets.length; i++) {
            if (gatewayWallets[i] == _address) return true;
        }
        return false;
    }

    function hasApproved(bytes32 _swapId, address _wallet)
        internal
        view
        returns (bool)
    {
        address[] memory approvals = swapApprovals[_swapId];
        for (uint256 i = 0; i < approvals.length; i++) {
            if (approvals[i] == _wallet) return true;
        }
        return false;
    }

    // Internal function to add or update UserData for a specific user and swapId
    function _updateUserSwap(
        address _sender,
        address _recipient,
        bytes32 _swapId,
        uint256 _amount,
        SwapStatus _status
    ) internal {
        UserData storage userData = userSwaps[_sender][_swapId];
        userData.amount = _amount;
        userData.recipient = _recipient;
        userData.status = _status;
        if (!isSwapId[_swapId]) {
            userSwapIds[_sender].push(_swapId);
        }
    }

    // This is called by the server when a swap coming from EVM network
    function approveSwap(bytes32 _swapId) external {
        require(
            isGatewayWallet(msg.sender),
            "Only gateway wallets can approve swaps"
        );
        require(
            !hasApproved(_swapId, msg.sender),
            "Wallet has already approved this swap"
        );

        swapApprovals[_swapId].push(msg.sender);
    }

    // This is called by the server when a swap is initiated from Source network
    function markSwapAsProcessed(bytes32 _swapId) external {
        require(
            isGatewayWallet(msg.sender),
            "Only gateway wallets can process swaps"
        );
        SwapRequest storage request = swapRequests[_swapId];
        require(
            request.status == SwapStatus.PendingSwap,
            "Swap not in correct state"
        );
        request.status = SwapStatus.Processed;
        request.confirmations = 1;
        _updateUserSwap(
            request.sender,
            request.recipient,
            _swapId,
            request.amount,
            SwapStatus.Processed
        );
        emit SwapProcessed(_swapId);

        // Remove swapId from pendingSwaps
        _removePendingSwap(_swapId);
    }

    function setSwapId(
        address _sender,
        address _recipient,
        uint256 _amount,
        uint256 _type
    ) internal returns (bytes32 swapId) {
        swapId = keccak256(
            abi.encodePacked(_sender, _amount, block.timestamp, _type)
        );
        swapRequests[swapId] = SwapRequest({
            sender: _sender,
            amount: _amount,
            recipient: _recipient,
            confirmations: 0,
            executed: false,
            Type: _type,
            chainId: block.chainid,
            status: SwapStatus.Created
        });
        lastUserSwap[_sender] = swapId;
        _updateUserSwap(
            _sender,
            _recipient,
            swapId,
            _amount,
            SwapStatus.Created
        );
        isSwapId[swapId] = true;
        return swapId;
    }

    // Function to initiate a swap to an EVM network
    function to_EVM(uint256 _amount, address _recipient)
        external
        payable
        whenNotPaused
        nonReentrant
        returns (bytes32 swapId, uint256 chainId)
    {
        require(msg.value >= swapFee, "Swap fee is required");
        require(_amount > 0, "Amount should be greater than 0");
        require(
            Acces.transferFrom(msg.sender, address(this), _amount),
            "Transfer failed"
        );

        if (_recipient == address(0)) {
            _recipient = msg.sender;
        }

        swapId = setSwapId(msg.sender, _recipient, _amount, 1);

        // Get the chain ID
        chainId = block.chainid;

        // Update the swap request with the chain ID
        swapRequests[swapId].chainId = chainId;

        // Distribute the received Ether equally among gateway wallets
        uint256 amountPerWallet = swapFee / gatewayWallets.length;
        for (uint256 i = 0; i < gatewayWallets.length; i++) {
            payable(gatewayWallets[i]).transfer(amountPerWallet);
        }

        emit TokensLocked(msg.sender, _recipient, _amount, swapId, chainId);
        swapRequests[swapId].status = SwapStatus.PendingSwap;
        pendingSwaps.push(swapId);
        emit SwapPending(swapId);

        // Return the swap ID and chain ID
        return (swapId, chainId);
    }

    // A python code will listen to events from EVM smart contract that the swap is completed
    function confirmSwap(bytes32 _swapId) external {
        require(
            isGatewayWallet(msg.sender),
            "Only gateway wallets can execute this function"
        );
        SwapRequest storage request = swapRequests[_swapId];
        require(!request.executed, "Swap already executed");
        request.confirmations = 2;
        request.executed = true;
        request.status = SwapStatus.Completed;
        _updateUserSwap(
            request.sender,
            request.recipient,
            _swapId,
            request.amount,
            SwapStatus.Completed
        );
    }

    // Function to handle incoming swaps from an EVM network
    function from_EVM(
        address _sender,
        address _recipient,
        uint256 _amount,
        bytes32 _swapId
    )
        external
        whenNotPaused
        returns (uint256 chainId)
    {
        require(
            isGatewayWallet(msg.sender),
            "Only gateway wallets can execute this function"
        );
        require(_amount > 0, "Amount should be greater than 0");

        bytes32 swapId = _swapId;
        SwapRequest storage request = swapRequests[swapId];
        require(!request.executed, "Swap already executed");

        // Get the chain ID
        chainId = block.chainid;

        // Update the swap request with the chain ID
        request.chainId = chainId;

        if (Acces.balanceOf(address(this)) < _amount) {
            // Update the swap request to indicate it's pending due to insufficient balance
            swapRequests[swapId] = SwapRequest({
                sender: _sender,
                amount: _amount,
                recipient: _recipient,
                confirmations: 1,
                executed: false,
                Type: 2,
                chainId: chainId,
                status: SwapStatus.PendingBalance
            });
            pendingBalanceSwaps.push(swapId);
            _updateUserSwap(
                request.sender,
                request.recipient,
                swapId,
                request.amount,
                SwapStatus.PendingBalance
            );
            emit SwapPendingBalance(swapId);
        } else {
            // Existing logic for processing the swap
            swapRequests[swapId] = SwapRequest({
                sender: _sender,
                amount: _amount,
                recipient: _recipient,
                confirmations: 1,
                executed: false,
                Type: 2,
                chainId: chainId,
                status: SwapStatus.Completed
            });
            require(swapApprovals[swapId].length >= 2, "Not enough approvals");
            Acces.transfer(_recipient, _amount);
            request.confirmations = 2;
            request.executed = true;
            _updateUserSwap(
                request.sender,
                request.recipient,
                swapId,
                request.amount,
                SwapStatus.Completed
            );
            emit TokensUnlocked(_recipient, _amount);
        }

        // Return the chain ID
        return chainId;
    }

    function processpendingBalanceSwaps() external onlyAdmin {
        uint256 contractBalance = Acces.balanceOf(address(this));
        uint256 i = 0;

        // Iterate through the pendingBalanceSwaps array
        while (i < pendingBalanceSwaps.length && contractBalance > 0) {
            bytes32 swapId = pendingBalanceSwaps[i];
            SwapRequest storage request = swapRequests[swapId];

            if (
                request.status == SwapStatus.PendingBalance &&
                contractBalance >= request.amount
            ) {
                // Process the swap
                Acces.transfer(request.recipient, request.amount);

                // Update swap request status and contract balance
                request.status = SwapStatus.Completed;
                request.executed = true;
                request.confirmations = 2;
                contractBalance -= request.amount;

                _updateUserSwap(
                    request.sender,
                    request.recipient,
                    swapId,
                    request.amount,
                    SwapStatus.Completed
                );

                // Emit event for swap completion
                emit TokensUnlocked(request.recipient, request.amount);

                // Remove processed swap from pendingBalanceSwaps
                _removePendingBalance(i);
            } else {
                // Move to the next swap if this one can't be processed
                i++;
            }
        }
    }

    function processPendingBalanceByIndex(uint256 _swapIndex)
        external
        onlyAdmin
    {
        require(
            _swapIndex < pendingBalanceSwaps.length,
            "Swap index out of bounds"
        );

        bytes32 swapId = pendingBalanceSwaps[_swapIndex];
        SwapRequest storage request = swapRequests[swapId];
        uint256 contractBalance = Acces.balanceOf(address(this));

        require(
            request.status == SwapStatus.PendingBalance,
            "Swap not pending balance"
        );
        require(
            contractBalance >= request.amount,
            "Insufficient contract balance"
        );

        // Process the swap
        Acces.transfer(request.recipient, request.amount);

        // Update swap request status
        request.status = SwapStatus.Completed;
        request.executed = true;
        request.confirmations = 2;

        _updateUserSwap(
            request.sender,
            request.recipient,
            swapId,
            request.amount,
            SwapStatus.Completed
        );

        // Emit event for swap completion
        emit TokensUnlocked(request.recipient, request.amount);

        // Remove processed swap from pendingBalanceSwaps
        _removePendingBalance(_swapIndex);
    }

    function _removePendingSwap(bytes32 _swapId) internal {
        for (uint256 i = 0; i < pendingSwaps.length; i++) {
            if (pendingSwaps[i] == _swapId) {
                pendingSwaps[i] = pendingSwaps[pendingSwaps.length - 1];
                pendingSwaps.pop();
                break;
            }
        }
    }

    // Utility function to remove a processed swap from the pendingBalanceSwaps array
    function _removePendingBalance(uint256 index) internal {
        require(index < pendingBalanceSwaps.length, "Index out of bounds");

        // Move the last element to the index and pop the last element
        pendingBalanceSwaps[index] = pendingBalanceSwaps[
            pendingBalanceSwaps.length - 1
        ];
        pendingBalanceSwaps.pop();
    }

    function getAllPendingSwaps() external view returns (SwapRequest[] memory) {
        SwapRequest[] memory swaps = new SwapRequest[](pendingSwaps.length);

        for (uint256 i = 0; i < pendingSwaps.length; i++) {
            SwapRequest storage request = swapRequests[pendingSwaps[i]];
            swaps[i] = request;
        }

        return swaps;
    }

    // Get incoming pending balance swaps
    function getAllpendingBalanceSwaps()
        external
        view
        returns (bytes32[] memory)
    {
        return pendingBalanceSwaps;
    }

    // Public function to get all swaps for a user
    function getAllUserSwaps(address _user)
        external
        view
        returns (UserData[] memory)
    {
        bytes32[] memory swapIds = userSwapIds[_user];
        UserData[] memory swaps = new UserData[](swapIds.length);

        for (uint256 i = 0; i < swapIds.length; i++) {
            swaps[i] = userSwaps[_user][swapIds[i]];
        }

        return swaps;
    }

    function replaceGatewayWallet(address oldWallet, address newWallet)
        external
        onlyOwner
    {
        // Find the index of the old wallet
        int256 index = findWalletIndex(oldWallet);

        // Check if the wallet was found
        require(index >= 0, "Old wallet not found");

        // Replace the old wallet with the new wallet
        gatewayWallets[uint256(index)] = newWallet;
    }

    // Helper function to find the index of a wallet
    function findWalletIndex(address wallet) internal view returns (int256) {
        for (uint256 i = 0; i < gatewayWallets.length; i++) {
            if (gatewayWallets[i] == wallet) {
                return int256(i);
            }
        }
        return -1; // Return -1 if the wallet is not found
    }
}
