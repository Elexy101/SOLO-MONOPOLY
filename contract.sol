// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract SoloMonopoly {
    // Token Info - packed into single storage slot
    string public constant name = "Solo Monopoly";
    string public constant symbol = "SMONO";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    // Storage optimizations
    mapping(address => uint256) public balanceOf;
    mapping(address => Player) public players;
    mapping(uint256 => address) public nftOwnerOf;

    // Events - unchanged
    event Transfer(address indexed from, address indexed to, uint256 value);
    event GameStarted(address player);
    event DiceRolled(address player, uint256 roll, uint256 newPosition);
    event ProfitLanded(address player, uint256 reward);
    event LossLanded(address player, uint256 penalty);
    event NFTMinted(address player, uint256 tokenId);

    // Game Configs - using smaller units (will multiply by 1e18 when needed)
    uint256 private constant INITIAL_TOKENS = 500;
    uint256 private constant NFT_THRESHOLD = 1000;
    uint256 private constant BOARD_SIZE = 16;
    uint256 private constant MAX_NFT_SUPPLY = 5000;

    enum TileType { NEUTRAL, PROFIT, LOSS }

    // Optimized structs
    struct Tile {
        TileType tileType;
        int32 value; // Reduced from int256
        string name;
    }

    struct Player {
        uint8 position; // Reduced from uint256 (since BOARD_SIZE is 16)
        bool hasStarted;
        bool hasMintedNFT;
    }

    // Board storage - initialized on first use
    Tile[BOARD_SIZE] private board;
    bool private boardInitialized;
    uint256 public nftSupply;

    constructor() {
        // Only initialize the starting tile
        board[0] = Tile(TileType.NEUTRAL, 0, "Start");
    }

    function startGame() external {
        require(!players[msg.sender].hasStarted, "Already playing");

        // Initialize board on first game if needed
        if (!boardInitialized) {
            _initializeBoard();
            boardInitialized = true;
        }

        _mint(msg.sender, INITIAL_TOKENS * 1e18);

        players[msg.sender] = Player({
            position: 0,
            hasStarted: true,
            hasMintedNFT: false
        });
        emit GameStarted(msg.sender);
    }

    function rollDice() external {
        Player storage player = players[msg.sender];
        require(player.hasStarted, "Start game first");

        uint256 roll = _random() % 6 + 1;
        player.position = uint8((player.position + roll) % BOARD_SIZE);

        emit DiceRolled(msg.sender, roll, player.position);
        _handleLanding(msg.sender, player.position);
    }

    function mintNFT() external {
        Player storage player = players[msg.sender];
        require(player.hasStarted, "Start game first");
        require(!player.hasMintedNFT, "Already minted NFT");
        require(balanceOf[msg.sender] >= NFT_THRESHOLD * 1e18, "Balance not high enough");
        require(nftSupply < MAX_NFT_SUPPLY, "Max NFT supply reached");

        uint256 tokenId = ++nftSupply;
        nftOwnerOf[tokenId] = msg.sender;
        player.hasMintedNFT = true;

        emit NFTMinted(msg.sender, tokenId);
    }

    function _handleLanding(address playerAddr, uint8 position) internal {
        Tile memory tile = board[position];

        if (tile.tileType == TileType.PROFIT) {
            uint256 reward = uint256(uint32(tile.value)) * 1e18;
            _mint(playerAddr, reward);
            emit ProfitLanded(playerAddr, reward);
        } else if (tile.tileType == TileType.LOSS) {
            uint256 penalty = uint256(uint32(-tile.value)) * 1e18;
            if (balanceOf[playerAddr] >= penalty) {
                balanceOf[playerAddr] -= penalty;
                totalSupply -= penalty;
                emit Transfer(playerAddr, address(0), penalty);
                emit LossLanded(playerAddr, penalty);
            } else {
                emit LossLanded(playerAddr, balanceOf[playerAddr]);
                totalSupply -= balanceOf[playerAddr];
                balanceOf[playerAddr] = 0;
            }
        }
    }

    function _initializeBoard() private {
        board[1] = Tile(TileType.PROFIT, 50, "Airbnb Boost");
        board[2] = Tile(TileType.LOSS, -20, "Lost Wallet");
        board[3] = Tile(TileType.NEUTRAL, 0, "Park");
        board[4] = Tile(TileType.PROFIT, 100, "Crypto Jackpot");
        board[5] = Tile(TileType.LOSS, -50, "Car Repair");
        board[6] = Tile(TileType.PROFIT, 75, "Freelance Gig");
        board[7] = Tile(TileType.LOSS, -30, "Stolen Phone");
        board[8] = Tile(TileType.NEUTRAL, 0, "Relax Zone");
        board[9] = Tile(TileType.PROFIT, 60, "E-Commerce Win");
        board[10] = Tile(TileType.LOSS, -40, "Overdue Rent");
        board[11] = Tile(TileType.PROFIT, 90, "Angel Investment");
        board[12] = Tile(TileType.LOSS, -25, "Bad Trade");
        board[13] = Tile(TileType.PROFIT, 30, "Gift Bonus");
        board[14] = Tile(TileType.LOSS, -10, "Late Fee");
        board[15] = Tile(TileType.NEUTRAL, 0, "Chill Spot");
    }

    function _mint(address to, uint256 value) private {
        totalSupply += value;
        balanceOf[to] += value;
        emit Transfer(address(0), to, value);
    }

    function _random() private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao,
            msg.sender
        )));
    }

    // View functions
    function getTile(uint256 position) external view returns (string memory, TileType, int256) {
        require(position < BOARD_SIZE, "Invalid tile");
        Tile memory t = board[position];
        return (t.name, t.tileType, int256(t.value) * 1e18);
    }

    function getPlayerPosition(address player) external view returns (uint256) {
        return players[player].position;
    }

    function getNFTBalance(address player) external view returns (bool) {
        return players[player].hasMintedNFT;
    }
}
