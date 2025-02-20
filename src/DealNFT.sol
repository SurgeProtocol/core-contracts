// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ERC721} from "openzeppelin/token/ERC721/ERC721.sol";
import {IERC20Metadata} from "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";
import {Math} from "openzeppelin/utils/math/Math.sol";
import {ReentrancyGuard} from "openzeppelin/security/ReentrancyGuard.sol";
import {IERC6551Registry} from "erc6551/interfaces/IERC6551Registry.sol";
import {AccountV3TBD} from "./AccountV3TBD.sol";
import {IDealNFT} from "./interfaces/IDealNFT.sol";
import {IWhitelist} from "./interfaces/IWhitelist.sol";
import {UD60x18, ud, ln, intoUint256} from "prb/UD60x18.sol";

contract DealNFT is ERC721, IDealNFT, ReentrancyGuard {
    using Math for uint256;
    using SafeERC20 for IERC20Metadata;

    error OnlyTreasury();
    error OnlySponsor();
    error OnlyArbitrator();
    error OnlyTokenOwner();
    error NotAuthorized();
    error ZeroDetected();
    error CannotSetup();
    error BadStakesRange();
    error CannotUnstake();
    error CannotRecover();
    error MinimumReached();
    error NotTransferable();
    error WhitelistError();
    error TokenOutOfBounds();
    error NotInClaimingState();
    error MinimumNotReached();
    error CannotConfigure();
    error CannotCancel();
    error NotActive();
    error ClosingTimeTooSmall();
    error ClosingTimeTooBig();
    error ClosingDelayTooBig();
    error ClosingFeeTooBig();
    error OwnerMismatch();

    // Events
    event Init(string social, string website, uint256 multiple, uint256 closingDelay, uint256 unstakingFee, uint256 closingTime, uint256 dealMinimum, uint256 dealMaximum, uint256 deliveryType, bool active, bool transferable, bool timeBasedClosing);
    event Setup(address escrowToken, uint256 closingDelay, uint256 unstakingFee, uint256 dealMinimum, uint256 dealMaximum, string website, string social, string image, string description, uint256 deliveryType);
    event Configure(string description, string social, string website, uint256 closingTime, uint256 dealMinimum, uint256 dealMaximum, uint256 multiple);
    event StateUpdated(State state);
    event Transferable(bool transferable);
    event ArbitratorUpdated(address indexed arbitrator);
    event SetStakersWhitelist(address whitelist);
    event SetClaimsWhitelist(address whitelist);
    event Claim(address indexed staker, uint256 tokenId, uint256 amount);
    event Stake(address indexed staker, address tokenBoundAccount, uint256 tokenId, uint256 amount);
    event Unstake(address indexed staker, address tokenBoundAccount, uint256 tokenId, uint256 amount);
    event Recover(address indexed staker, address tokenBoundAccount, uint256 tokenId, uint256 amount);    

    enum State { Setup, Active, Claiming, Closed, Cancelled }
    enum DeliveryType { Venture, Community, Meme }

    uint256 private constant MAX_FEE = 10e4;
    uint256 private constant PRECISION = 1e6;
    uint256 private constant CLAIMING_PERIOD = 1 weeks;
    uint256 private constant CLAIMING_FEE = 3e4;
    uint256 private constant MAX_CLOSING_RANGE = 52 weeks;
    address private constant ADDRESS_ZERO = address(0);

    address private immutable _treasury;
    address private immutable _registry;
    address private immutable _implementation;

    string private _nftURI;
    uint256 private _tokenId;
    uint256 private _claimId;

    IERC20Metadata public deliveryToken;
    uint256 public deliveryAmount;
    uint256 public totalClaimed;

    IWhitelist public stakersWhitelist;
    IWhitelist public claimsWhitelist;

    uint256 lastStakeTimestamp;
    mapping(uint256 tokenId => uint256) public stakedAmount;
    mapping(uint256 tokenId => uint256) public claimedAmount;
    mapping(address staker => uint256) public stakes;

    struct StakeData {
        address owner;
        address tba;
        uint256 staked;
        uint256 claimed;
    }

    struct Configuration {
        address escrowToken;
        address sponsor;
        address arbitrator;
        string image;
        string description;
        string social;
        string website;
        uint256 multiple;
        uint256 closingDelay;
        uint256 unstakingFee;
        uint256 closingTime;
        uint256 dealMinimum;
        uint256 dealMaximum;
        uint256 deliveryType;
        bool active;
        bool cancelled;
        bool transferable;
        bool timeBasedClosing;
    }

    Configuration private config;

    /**
        * @notice Constructor to initialize DealNFT contract
        * @param treasury_ The address of the treasury
        * @param registry_ The address of the registry
        * @param implementation_ The address of the implementation
        * @param name_ The name of the NFT
        * @param symbol_ The symbol of the NFT
        * @param nftURI_ The base URI of the NFT
        * @param config_ The parameters of the deal
     */
    constructor(
        address treasury_,
        address registry_,
        address implementation_,
        string memory nftURI_,
        string memory name_,
        string memory symbol_,
        Configuration memory config_
    ) ERC721(name_, symbol_) {
        if(treasury_ == ADDRESS_ZERO) revert ZeroDetected();
        if(registry_ == ADDRESS_ZERO) revert ZeroDetected();
        if(implementation_ == ADDRESS_ZERO) revert ZeroDetected();

        if(bytes(nftURI_).length == 0) revert ZeroDetected();
        if(bytes(name_).length == 0) revert ZeroDetected();
        if(bytes(symbol_).length == 0) revert ZeroDetected();

        if(config_.sponsor == ADDRESS_ZERO) revert ZeroDetected();
        if(config_.timeBasedClosing) {
            _validClosingTime(config_.closingTime, config_.closingDelay);
        }
        if(config_.dealMinimum > config_.dealMaximum) revert BadStakesRange();
        if(config_.multiple < 1e18) revert ZeroDetected();

        config = config_;

        if(config_.active) {
            _validateActivation();
        }

        _treasury = treasury_;
        _registry = registry_;
        _implementation = implementation_;
        _nftURI = string.concat(nftURI_, Strings.toHexString(address(this)), "/token/");

        emit Init(
            config_.social,
            config_.website,
            config_.multiple,
            config_.closingDelay,
            config_.unstakingFee,
            config_.closingTime,
            config_.dealMinimum,
            config_.dealMaximum,
            config_.deliveryType,
            config_.active,
            config_.transferable,
            config_.timeBasedClosing
        );
    }

    modifier onlyTreasury() {
        if(msg.sender != _treasury) revert OnlyTreasury();
        _;
    }

    modifier onlySponsor() {
        if(msg.sender != config.sponsor) revert OnlySponsor();
        _;
    }

    modifier onlyArbitrator() {
        if(msg.sender != config.arbitrator) revert OnlyArbitrator();
        _;
    }

    modifier onlyTokenOwner(uint256 tokenId) {
        if(msg.sender != ownerOf(tokenId)) revert OnlyTokenOwner();
        _;
    }

    /**
    * @notice Setup the deal
    * @param escrowToken_ The address of the escrow token
    * @param closingDelay_ The delay before closing the deal
    * @param unstakingFee_ The fee for unstaking tokens
    * @param website_ The website associated with the deal
    * @param social_ The Social account associated with the deal
    * @param image_ The image associated with the deal
    * @param description_ The description of the deal
    * @param deliveryType_ The type of delivery
     */
    function setup(
        address escrowToken_,
        uint256 closingDelay_,
        uint256 unstakingFee_,
        uint256 dealMinimum_,
        uint256 dealMaximum_,
        string memory social_,
        string memory website_,
        string memory image_,
        string memory description_,
        uint256 deliveryType_
    ) external onlySponsor {
        if(state() != State.Setup) revert CannotSetup();
        if(dealMinimum_ > dealMaximum_) revert BadStakesRange();

        config.escrowToken = escrowToken_;
        config.closingDelay = closingDelay_;
        config.unstakingFee = unstakingFee_;
        config.dealMinimum = dealMinimum_;
        config.dealMaximum = dealMaximum_;
        config.social = social_;
        config.website = website_;
        config.image = image_;
        config.description = description_;
        config.deliveryType = deliveryType_;

        emit Setup(escrowToken_, closingDelay_, unstakingFee_, dealMaximum_, dealMinimum_, website_, social_, image_, description_, deliveryType_);
    }

    /**
     * @notice Activates the deal
     * @dev requires all setup parameters to be set
     */
    function activate() external onlySponsor {
        _validateActivation();
        config.active = true;
        emit StateUpdated(State.Active);
    }

    /**
     * @notice Configure the deal
     * @param description_ Description of the deal
     * @param social_ Social account associated with the deal
     * @param website_ Website associated with the deal
     * @param closingTime_ Closing time of the deal
     * @param dealMinimum_ Minimum amount of tokens required for the deal
     * @param dealMaximum_ Maximum amount of tokens allowed for the deal
    */
    function configure(
        string memory description_,
        string memory social_,
        string memory website_,
        uint256 closingTime_,
        uint256 dealMinimum_,
        uint256 dealMaximum_,
        uint256 multiple_
    ) external onlySponsor {
        _canConfigure();        
        if(multiple_ < 1e18) revert ZeroDetected();

        if(config.timeBasedClosing) {
            _validClosingTime(closingTime_, config.closingDelay);
            if(dealMinimum_ > dealMaximum_) revert BadStakesRange();

            config.dealMinimum = dealMinimum_;
            config.dealMaximum = dealMaximum_;
            config.closingTime = closingTime_;
        }

        config.description = description_;
        config.social = social_;
        config.website = website_;

        config.multiple = multiple_;

        emit Configure(description_, social_, website_, closingTime_, dealMinimum_, dealMaximum_, multiple_);
    }

    function setArbitrator(address arbitrator_) external onlyTreasury {
        if(arbitrator_ == ADDRESS_ZERO) revert ZeroDetected();
        config.arbitrator = arbitrator_;
        emit ArbitratorUpdated(arbitrator_);
    }

    /**
     * @notice Deposit delivery tokens to the deal
     * @param amount The amount of tokens to transfer
     */
    function depositDeliveryTokens(address deliveryToken_, uint256 amount) external nonReentrant onlyArbitrator {
        if(deliveryToken_ == ADDRESS_ZERO) revert ZeroDetected();
        deliveryToken = IERC20Metadata(deliveryToken_);
        deliveryToken.safeTransferFrom(config.arbitrator, address(this), amount);
        deliveryAmount += amount;
    }

    /**
     * @notice Recover delivery tokens from the deal
     */
    function recoverDeliveryTokens() external nonReentrant onlyArbitrator {
        if(state() < State.Closed) revert CannotRecover();
        deliveryToken.safeTransfer(config.arbitrator, deliveryToken.balanceOf(address(this)));
    }

    /**
     * @notice Set whether the NFTs are transferable or not
     * @param transferable_ Boolean indicating if NFTs are transferable
     */
    function setTransferable(bool transferable_) external onlyArbitrator {
        config.transferable = transferable_;
        emit Transferable(transferable_);
    }

    /**
     * @notice configure whitelists for staking
     * @param stakerWhitelist_ enable whitelisting on stakes
     */
    function setStakersWhitelist(address stakerWhitelist_) external onlySponsor {
        stakersWhitelist = IWhitelist(stakerWhitelist_);
        emit SetStakersWhitelist(stakerWhitelist_);
    }

    /**
     * @notice configure whitelists for claiming
     * @param claimsWhitelist_ enable whitelisting on stakes
     */
    function setClaimsWhitelist(address claimsWhitelist_) external onlySponsor {
        claimsWhitelist = IWhitelist(claimsWhitelist_);
        emit SetClaimsWhitelist(claimsWhitelist_);
    }

    /**
     * @notice Cancel the deal
     */
    function cancel() external {
        if(msg.sender != config.sponsor && msg.sender != config.arbitrator) revert NotAuthorized();
        if(state() > State.Claiming) revert CannotCancel();
        config.cancelled = true;
        emit StateUpdated(State.Cancelled);
    }

    /**
     * @notice Stake tokens into the deal
     * @param staker The address of the staker
     * @param amount The amount of tokens to stake
     */
    function stake(address staker, uint256 amount) external nonReentrant {
        _stake(staker, amount);
    }

    /**
     * @notice Unstake tokens from the deal
     * @param tokenId The ID of the token to unstake
     */
    function unstake(uint256 tokenId) external nonReentrant onlyTokenOwner(tokenId) { 
        if(state() > State.Active) revert CannotUnstake();

        uint256 amount = stakedAmount[tokenId];
        AccountV3TBD tokenBoundAccount = getTokenBoundAccount(tokenId);

        stakedAmount[tokenId] = 0;
        stakes[msg.sender] -= amount;

        uint256 fee = amount.mulDiv(config.unstakingFee, PRECISION);
        tokenBoundAccount.send(msg.sender, amount - fee);
        tokenBoundAccount.send(config.sponsor, fee.ceilDiv(2));
        tokenBoundAccount.send(_treasury, fee/2);

        emit Unstake(msg.sender, address(tokenBoundAccount), tokenId, amount);
    }

    /**
     * @notice Recover tokens from the deal if the deal is Cancelled or Closed
     * @param tokenId The ID of the token to recover
     */
    function recover(uint256 tokenId) external nonReentrant onlyTokenOwner(tokenId) { 
        if(state() < State.Claiming) revert CannotRecover();

        if(state() == State.Claiming) {
            if(_minimumReached()) revert MinimumReached();
        }

        AccountV3TBD tokenBoundAccount = getTokenBoundAccount(tokenId);
        uint256 balance = IERC20Metadata(config.escrowToken).balanceOf(address(tokenBoundAccount));

        stakedAmount[tokenId] = claimedAmount[tokenId];

        tokenBoundAccount.send(msg.sender, balance);

        emit Recover(msg.sender, address(tokenBoundAccount), tokenId, balance);
    }

    /**
     * @notice Claim tokens from the deal
     */
    function claim() external nonReentrant onlyArbitrator {
        _canClaim();
        uint256 maximum = Math.min(config.dealMaximum, _totalStaked(_tokenId));
        while(_claimId < _tokenId) {
            _claimNext(maximum);
        }
        emit StateUpdated(State.Closed);
    }

    /**
     * @notice Claim the next token id from the deal
     */
    function claimNext() external nonReentrant onlyArbitrator {
        _canClaim();
        uint256 maximum = Math.min(config.dealMaximum, _totalStaked(_tokenId));
        _claimNext(maximum);
     }

    /**
     * @notice Internal function to claim the next token id from the deal
     * @dev funds are sent from the TBA to the sponsor until dealMaximum.
     */
    function _claimNext(uint256 maximum) private {
        uint256 tokenId = _claimId++;
        uint256 amount = stakedAmount[tokenId];
        address staker = ownerOf(tokenId);

        if(address(claimsWhitelist) != ADDRESS_ZERO && !claimsWhitelist.canClaim(staker)) {
            return;
        }

        if(totalClaimed + amount > config.dealMaximum) {
            amount = config.dealMaximum - totalClaimed;
        }

        if(amount > 0) {
            claimedAmount[tokenId] = amount;
            totalClaimed += amount;
            if(deliveryAmount > 0) {
                uint256 bonus = getDeliveryTokensFor(tokenId, maximum);
                if(bonus > 0) deliveryToken.safeTransfer(staker, bonus);
            }

            AccountV3TBD tokenBoundAccount = getTokenBoundAccount(tokenId);
            uint256 fee = amount.mulDiv(CLAIMING_FEE, PRECISION);

            tokenBoundAccount.send(config.arbitrator, amount - fee);
            tokenBoundAccount.send(_treasury, fee);

            emit Claim(staker, tokenId, amount);
        }
    }

    /**
     * @notice Get current state of the deal
     * @dev a deal is considered closed if the tokens have been claimed by the sponsor
     */
    function state() public view returns (State) {
        if(config.cancelled) return State.Cancelled;
        if(_isClaimed()) return State.Closed;

        if(config.timeBasedClosing){
            if(_afterClosed(config.closingTime)) {
                return State.Cancelled;
            }

            if(_beforeClose()) {
                if(config.active) return State.Active;
                return State.Setup;
            }

            return State.Claiming;
        } else {
            if(_minimumReached()) {
                if(_afterClosed(lastStakeTimestamp)){
                    return State.Cancelled;
                }

                return State.Claiming;
            }

            if(config.active) return State.Active;
            return State.Setup;
        }
    }

    /** 
     * @notice Get the total amount of tokens staked in the deal
     */
    function totalStaked() external view returns (uint256) {
        return _totalStaked(_tokenId);
    }

    /**
     * @notice Get the stakes from 0 to a NFT id
     * @param index The index of the last NFT
     */
    function getStakesTo(uint256 index) external view returns (StakeData[] memory) {
        if(index >= _tokenId) index = _tokenId > 0 ? _tokenId - 1 : 0;
        StakeData[] memory stakesTo = new StakeData[](index + 1);

        for(uint256 i = 0; i <= index; ) {
            address staker = ownerOf(i);
            stakesTo[i] = StakeData(staker, address(getTokenBoundAccount(i)), stakedAmount[i], claimedAmount[i]);
            unchecked { i++; }
        }

        return stakesTo;
    }

    /**
     * @notice Get the bonus for a particular stake
     * @param tokenId The index of the stake
     * @dev bonus is in 1eN precision, where N is the decimals of the delivery token
     * @dev T = total amount to be delivered
     * @dev M = first bonus discount
     * @dev C = deal maximum
     * @dev L = last stake
     * @dev X = sum of previous stakes
     * @dev R = amount of delivery tokens received
     * @dev K1, K2, constants
     */
    function getDeliveryTokensFor(uint256 tokenId, uint256 maximum) public view returns(uint256) {
        if (tokenId >= _tokenId) return 0;

        uint256 L = stakedAmount[tokenId];
        uint256 T = deliveryAmount;
        uint256 M = config.multiple;
        uint256 C = maximum;

        if(T == 0 || L == 0 || M == 0) return 0;

        if(M == 1e18) { // if no discount
            return L * T / _totalStaked(_tokenId); // stakedAmount * deliveryAmount / totalStaked
        }

        uint256 S = _totalStaked(tokenId);
        uint256 X = S - L;

        if (S > C) { // dealMaximum was reached - calculate bonus for a partial stake
            L = C > X ? C - X : 0;
        }

        uint256 lnM = intoUint256(ln(ud(M)));
        uint256 k1 = (T * 1e18) / lnM; // ends up with delivery decimals
        uint256 k2 = C * 1e18 / (M - 1e18); // ends up with escrow decimals
        uint256 k3 = 1e18 + (L * 1e18 / (X + k2)); // ends up with precision 1e18

        uint256 result = k1 * intoUint256(ln(ud(k3))) / 1e18; // result has delivery token decimals
        return result;
    }

    /**
     * @notice Get next available token id
     */
    function nextId() external view returns (uint256) {
        return _tokenId;
    }

    /**
     * @notice Get the TBA of a particular NFT
     */
    function getTokenBoundAccount(uint256 tokenId) public view returns(AccountV3TBD) {
        return AccountV3TBD(payable(IERC6551Registry(_registry).account(_implementation, bytes32(abi.encode(0)), block.chainid, address(this), tokenId)));
    }

    function escrowToken() external view override returns (IERC20Metadata) {
        return IERC20Metadata(config.escrowToken);
    }

    /**
     * @notice Block escrow token from being interacted with from the TBA
     */
    function allowToken(address to) external view returns (bool) {
        return to != config.escrowToken;
    }

    function getConfiguration() external view returns (Configuration memory) {
        return config;
    }

    /**
     * @notice Check if the minimum has been reached
     */
    function _minimumReached() private view returns (bool) {
        return _totalStaked(_tokenId) >= config.dealMinimum;
    }

    /**
     * @notice Check if all tokens have been claimed by the sponsor
     */
    function _isClaimed() private view returns (bool) {
        return totalClaimed > 0 && (totalClaimed >= config.dealMaximum || totalClaimed >= _totalStaked(_tokenId));
    }

    /**
     * @notice Check if the current time is before closing time
     */
    function _beforeClose() private view returns (bool) {
        return config.closingTime == 0 || block.timestamp <= config.closingTime;
    }

    /**
     * @notice Check if the current time is after closing time
     */
    function _afterClosed(uint256 since) private view returns (bool) {
        return since > 0 && block.timestamp > (since + CLAIMING_PERIOD);
    }

    /**
     * @inheritdoc ERC721
     */
    function _transfer(address from, address to, uint256 tokenId) internal override {
        if(!config.transferable) revert NotTransferable();

        uint256 amount = stakedAmount[tokenId];        

        if(address(stakersWhitelist) != ADDRESS_ZERO){
            uint256 staked = stakes[to] + amount;
            if(!stakersWhitelist.canStake(to, staked)) revert WhitelistError();
        }

        stakes[from] -= amount;
        stakes[to] += amount;

        super._transfer(from, to, tokenId);
    }

    /**
     * @inheritdoc ERC721
     */
    function _baseURI() internal view override returns (string memory) {
        return _nftURI;
    }

    /**
     * @notice Get the total amount of tokens staked in the deal
     */
    function _totalStaked(uint256 limit) internal view returns (uint256 total) {
        if(_tokenId == 0) return 0;
        if(limit >= _tokenId) limit = _tokenId - 1;

        for(uint256 i = 0; i <= limit; i++) {
            address staker = ownerOf(i);
            if(address(claimsWhitelist) == ADDRESS_ZERO || claimsWhitelist.canClaim(staker)) {
                total += stakedAmount[i];
            }
        }
    }

    /**
     * @notice Function to check claim requirements
     */
    function _canClaim() internal view {
        if(_claimId == _tokenId) revert TokenOutOfBounds();
        if(state() != State.Claiming) revert NotInClaimingState();
        if(!_minimumReached()) revert MinimumNotReached();
    }

    /**
     * @notice Function to check the deal can be configured
     */
    function _canConfigure() internal view {
        if(state() >= State.Closed) revert CannotConfigure();
        if(state() == State.Claiming) {
            if(_minimumReached()) revert MinimumReached();
        }
    }

    function _validateActivation() internal view {
        if(config.escrowToken == ADDRESS_ZERO) revert ZeroDetected();
        if(config.timeBasedClosing) {
            if(config.closingDelay <= 0) revert ZeroDetected();
            if(config.closingDelay > MAX_CLOSING_RANGE) revert ClosingDelayTooBig();
        }
        if(config.unstakingFee > MAX_FEE) revert ClosingFeeTooBig();
        if(bytes(config.website).length == 0) revert ZeroDetected();
        if(bytes(config.social).length == 0) revert ZeroDetected();
        if(bytes(config.image).length == 0) revert ZeroDetected();
    }

    /**
     * @notice Function to check the closing time is valid
     * @param closingTime_ The closing time to check
     */
    function _validClosingTime(uint256 closingTime_, uint256 closingDelay_) internal view {
        if(closingTime_ > 0 && closingTime_ < block.timestamp + closingDelay_) revert ClosingTimeTooSmall();
        if(closingTime_ > block.timestamp + MAX_CLOSING_RANGE) revert ClosingTimeTooBig();
    }

    function _stake(address staker, uint256 amount) internal {
        if(state() != State.Active) revert NotActive();
        if(amount <= 0) revert ZeroDetected();

        uint256 currentStake = stakes[staker] + amount;

        if(address(stakersWhitelist) != ADDRESS_ZERO){
            if(!stakersWhitelist.canStake(staker, currentStake)) revert WhitelistError();
        }

        uint256 newTokenId = _tokenId++;
        stakedAmount[newTokenId] = amount;
        stakes[staker] = currentStake;
        lastStakeTimestamp = block.timestamp;

        _safeMint(staker, newTokenId);

        address payable newAccount = payable(IERC6551Registry(_registry).createAccount(_implementation, bytes32(abi.encode(0)), block.chainid, address(this), newTokenId));
        if(AccountV3TBD(newAccount).owner() != staker) revert OwnerMismatch();

        IERC20Metadata(config.escrowToken).safeTransferFrom(msg.sender, newAccount, amount);

        emit Stake(staker, newAccount, newTokenId, amount);
    }
}
