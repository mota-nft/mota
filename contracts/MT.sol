// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./lib/IERC20.sol";
import "./lib/Operator.sol";
import "./lib/Ownable.sol";
import './lib/IUniswapV2Factory.sol';
import './lib/IUniswapV2Router.sol';
import "openzeppelin-solidity/contracts/utils/math/SafeMath.sol";

contract ReceiveMT is Ownable {
    receive() external payable {
    }
    function transferBack(uint _amount) public payable onlyOwner{
        payable(owner()).transfer(_amount);
    }
}

contract ERC20 is IERC20, Operator {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    address public _lp;
    address public _lppool;
    
    function setLp(address lp, address lppool) public onlyOwner{
        _lp = lp;
        _lppool = lppool;
    }

    constructor (string memory name_, string memory symbol_) public {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        _beforeTokenTransfer(sender, recipient, amount);
        if(recipient==_lp && !MT(payable(_lppool)).GetInSwapAndLiquify()) {
            _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
            uint pctAmount = amount.mul(10).div(100);
            _balances[_lppool] = _balances[_lppool].add(pctAmount);
            emit Transfer(sender, _lppool, pctAmount);
            amount = amount.mul(90).div(100);
            MT(payable(_lppool)).swapAndTokensLiquify();
        }else if(recipient == _lppool && !MT(payable(_lppool)).GetInSwapAndLiquify()){
            _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
            MT(payable(_lppool)).swapAndTokensLiquify();
        }else{
            _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        }
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");
        _beforeTokenTransfer(address(0), account, amount);
        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");
        _beforeTokenTransfer(account, address(0), amount);
        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _setupDecimals(uint8 decimals_) internal virtual {
        _decimals = decimals_;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}

contract MT is ERC20 {
    receive() external payable {
    }
    using SafeMath for uint256;
    
    address TO;

    uint merge_limit = 1000000*1e18;
    
    IUniswapV2Router02 public  uniswapV2Router;
    address public  uniswapV2Pair;
    
    ReceiveMT public receiveMT;
    constructor(address _TO,uint _amount) public ERC20('MT', 'MT') {
        TO = _TO;
        _mint(TO,_amount);
        
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        
        receiveMT = new ReceiveMT();
    }
    
    function mint(address recipient, uint256 amount) public onlyOwner returns (bool) {
        uint256 balanceBefore = balanceOf(recipient);
        _mint(recipient, amount*1e18);
        uint256 balanceAfter = balanceOf(recipient);
        return balanceAfter >= balanceBefore;
    }

    function GetMergeLimit() public view returns(uint){
        return merge_limit;
    }
    
    function ChangeMergeLimit(uint _limit) public onlyOwner{
        merge_limit = _limit;
    }
    
    address mt = address(this);
    
    function _addLiquidityETH(uint256 tokenAmount, uint256 ethAmount) internal {
        // approve token transfer to cover all possible scenarios
        IERC20(mt).approve(address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            mt,
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            TO,
            block.timestamp
        );
    }
    
    function addLiquidityETH(uint256 tokenAmount) public payable{
        _addLiquidityETH(tokenAmount, msg.value);
    }
    
    bool inSwapAndLiquify;
    
    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }
    
    function GetInSwapAndLiquify() public view returns(bool){
        return inSwapAndLiquify;
    }
    
    function swapAndTokensLiquify() public lockTheSwap returns(bool){
        if(balanceOf(mt) < merge_limit) return false;
        uint _amount = merge_limit;

        // split the contract balance into halves
        uint256 half = _amount.div(2);
        uint256 otherHalf = _amount.sub(half);
    
        // capture the contract's current USDT balance.
        // this is so that we can capture exactly the amount of USDT that the
        // swap creates, and not make the liquidity event include any USDT that
        // has been manually sent to the contract
        uint256 initialBalance = address(receiveMT).balance;
    
        // swap tokens for USDT
        swapTokenForEth(address(receiveMT),half);
        // how much USDT did we just swap into?
        uint256 newBalance = address(receiveMT).balance.sub(initialBalance);
        receiveMT.transferBack(newBalance);
        // add liquidity to uniswap
        _addLiquidityETH(otherHalf,newBalance);
        return true;
    }
    
    function swapTokenForEth(address _recive, uint amountIn) private{
        
        address[] memory path = new address[](2);
        uint deadline = block.timestamp + 600;
        amountIn = amountIn;
    
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), amountIn);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountIn,
            1,
            path,
            _recive,
            deadline
        );
    }

    function SetTo(address _adr) public onlyOwner{
        TO = _adr;
    }
    
    mapping(address => bool) master;
    
    function AddMaster(address _adr) public OnlyThis{
        master[_adr] = true;
    }
    
    modifier OnlyThis(){
        require(msg.sender == owner() || msg.sender == address(this) || master[_msgSender()],"This address is error address");
        _;
    }
}