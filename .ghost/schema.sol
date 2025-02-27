struct Deal {
    address id;
    @many(Stake.dealId) stakes;

    address sponsor;
    address arbitrator;
    address escrowToken;
    address stakersWhitelist;
    address claimsWhitelist;
    string escrowSymbol;
    uint8 escrowDecimals;
    string name;
    string symbol;
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
    bool transferable;
    bool timeBasedClosing;

    // calculated
    uint8 state;
    uint256 totalStaked;

    // metadata
    uint32 createdAt;
    bytes32 txHash;

    // stake metadata
    uint32 lastStakeTime;
    bytes32 lastStakeTxHash;
}

struct Stake {
    string id;
    @belongsTo(Deal.id) dealId;

    address owner;
    address tba;
    uint256 staked;
    uint256 claimed;
    uint256 tokenId;

    uint32 createdAt;
    bytes32 txHash;
}