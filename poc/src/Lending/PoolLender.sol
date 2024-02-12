// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LendingBorrowing {
    using SafeERC20 for IERC20;

    error InsufficientCollateral();
    error InsufficientBorrowableAmount();
    error ActiveLoanExists();
    error NoActiveLoan();
    error LoanNotDueYet();
    error InsufficientStake();

    struct Loan {
        address borrower;
        uint256 amount;
        uint256 interestRate; // Annual interest rate in percentage (e.g., 5% => 5)
        uint256 startDate;
        uint256 duration; // In seconds
        bool active;
    }

    mapping(address => uint256) public borrowBalances;
    mapping(address => uint256) public collateralBalances;
    mapping(address => Loan) public loans;

    event Lend(address indexed lender, uint256 amount);
    event Borrow(
        address indexed borrower,
        uint256 amount,
        uint256 interestRate,
        uint256 duration
    );
    event Stake(address indexed staker, uint256 amount);
    event WithdrawCollateral(address indexed staker, uint256 amount);
    event Withdraw(address indexed lender, uint256 amount);

    IERC20 public borrowToken;
    IERC20 public collateralToken;

    constructor(address _borrowToken, address _collateralToken) {
        borrowToken = IERC20(_borrowToken);
        collateralToken = IERC20(_collateralToken);
    }

    function lend(uint256 _amount) external {
        borrowToken.safeTransferFrom(msg.sender, address(this), _amount);
        borrowBalances[msg.sender] += _amount;
        emit Lend(msg.sender, _amount);
    }

    function borrow(
        uint256 _amount,
        uint256 _interestRate,
        uint256 _duration
    ) external {
        // Check if there is an active loan
        if (loans[msg.sender].active) {
            revert ActiveLoanExists();
        }

        // Calculate maximum borrowable amount based on collateral
        // for simplicity we assume the rate to be 1 / 1
        uint256 maxBorrowableAmount = (collateralBalances[msg.sender] * 80) /
            100;
        if (maxBorrowableAmount < _amount) {
            revert InsufficientCollateral();
        }

        // Check if the borrower has enough collateral
        if (borrowToken.balanceOf(address(this)) < _amount) {
            revert InsufficientBorrowableAmount();
        }

        // Calculate interest
        uint256 interest = (_amount * _interestRate * _duration) /
            (365 days * 100);
        uint256 totalAmount = _amount + interest;

        // Update balances
        borrowBalances[msg.sender] += totalAmount;
        loans[msg.sender] = Loan({
            borrower: msg.sender,
            amount: totalAmount,
            interestRate: _interestRate,
            startDate: block.timestamp,
            duration: _duration,
            active: true
        });

        borrowToken.safeTransfer(msg.sender, _amount);
        emit Borrow(msg.sender, _amount, _interestRate, _duration);
    }

    function repay() external {
        Loan storage loan = loans[msg.sender];
        if (!loan.active) {
            revert NoActiveLoan();
        }
        if (block.timestamp < loan.startDate + loan.duration) {
            revert LoanNotDueYet();
        }
        borrowBalances[msg.sender] -= loan.amount;
        address _borrower = loan.borrower;
        uint256 _amount = loan.amount;
        delete loans[msg.sender];
        // Transfer the loan amount back to the lender
        borrowToken.safeTransferFrom(msg.sender, _borrower, _amount);
    }

    function stake(uint256 _amount) external {
        collateralToken.safeTransferFrom(msg.sender, address(this), _amount);
        collateralBalances[msg.sender] += _amount;
        emit Stake(msg.sender, _amount);
    }

    function withdrawCollateral(uint256 _amount) external {
        if (collateralBalances[msg.sender] < _amount) {
            revert InsufficientStake();
        }

        collateralBalances[msg.sender] -= _amount;
        collateralToken.safeTransfer(msg.sender, _amount);
        emit WithdrawCollateral(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external {
        if (borrowBalances[msg.sender] < _amount) {
            revert InsufficientStake();
        }

        borrowBalances[msg.sender] -= _amount;
        borrowToken.safeTransfer(msg.sender, _amount);
        emit Withdraw(msg.sender, _amount);
    }
}
