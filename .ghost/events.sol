interface Events {
    event Create(address indexed deal, address indexed sponsor, address arbitrator, address escrowToken, string name, string symbol, string image, string description);

    event Init(string social, string website, uint256 multiple, uint256 closingDelay, uint256 unstakingFee, uint256 closingTime, uint256 dealMinimum, uint256 dealMaximum, uint256 deliveryType, bool active, bool transferable, bool timeBasedClosing);
    event Setup(address escrowToken, uint256 closingDelay, uint256 unstakingFee, uint256 dealMinimum, uint256 dealMaximum, string website, string social, string image, string description, uint256 deliveryType);

    event Configure(string description, string social, string website, uint256 closingTime, uint256 dealMinimum, uint256 dealMaximum, uint256 multiple);
    event StateUpdated(uint8 state);
    event Transferable(bool transferable);
    event ArbitratorUpdated(address indexed arbitrator);
    event Claim(address indexed staker, uint256 tokenId, uint256 amount);
    event Stake(address indexed staker, address tokenBoundAccount, uint256 tokenId, uint256 amount);
    event Unstake(address indexed staker, address tokenBoundAccount, uint256 tokenId, uint256 amount);
    event Recover(address indexed staker, address tokenBoundAccount, uint256 tokenId, uint256 amount);

    event SetStakersWhitelist(address whitelist);
    event SetClaimsWhitelist(address whitelist);
}
