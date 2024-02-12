// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IFlashLoanEtherReceiver {
    function execute() external payable;
}

contract FlashLoan {
    error RepayFailed();

    // flash loan contract to borrow eth
    function flashLoan(uint256 amount) external {
        uint256 balanceBefore = address(this).balance;

        IFlashLoanEtherReceiver(msg.sender).execute{value: amount}();

        if (address(this).balance < balanceBefore) revert RepayFailed();
    }
}
