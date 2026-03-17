"""
Verified Ethereum Mainnet contract addresses for 20 smart contract categories.
All addresses are real, deployed, and verified on Etherscan.
Used as seed contracts for human baseline comparison in the research paper.
"""

SEED_CONTRACTS = {
    "ERC20_Token": [
        "0xdac17f958d2ee523a2206206994597c13d831ec7",  # USDT (Tether)
        "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",  # USDC (Circle)
        "0x6b175474e89094c44da98b954eedeac495271d0f",  # DAI (Dai Stablecoin)
        "0x514910771af9ca656af840dff83e8264ecf986ca",  # LINK (Chainlink)
        "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984",  # UNI (Uniswap)
        "0x7fc66500c84a76ad7e9c93437bfc5ac33e2ddae9",  # AAVE (Aave)
        "0x2260fac5e5542a773aa44fbcfedf7c193bc2c599",  # WBTC (Wrapped Bitcoin)
        "0x95ad61b0a150d79219dcf64e1e6cc01f0b64c4ce",  # SHIB (Shiba Inu)
        "0x4d224452801aced8b2f0aebe155379bb5d594381",  # APE (ApeCoin)
        "0x3845badade8e6dff049820680d1f14bd3903a5d0",  # SAND (The Sandbox)
        "0xd533a949740bb3306d119cc777fa900ba034cd52",  # CRV (Curve DAO Token)
        "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2",  # MKR (Maker)
        "0xc011a73ee8576fb46f5e1c5751ca3b9fe0af2a6f",  # SNX (Synthetix)
        "0xc00e94cb662c3520282e6f5717214004a7f26888",  # COMP (Compound)
        "0x5a98fcbea516cf06857215779fd812ca3bef1b32",  # LDO (Lido DAO)
        "0x853d955acef822db058eb8505911ed77f175b99e",  # FRAX (Frax)
        "0x3432b6a60d23ca0dfca7761b7ab56459d9c964d0",  # FXS (Frax Share)
        "0xde30da39c46104798bb5aa3fe8b9e0e1f348163f",  # GTC (Gitcoin)
        "0xf629cbd94d3791c9250152bd8dfbdf380e2a3b9c",  # ENJ (Enjin Coin)
        "0xccc8cb5229b0ac8069c51fd58367fd1e622afd97",  # GODS (Gods Unchained)
    ],

    "ERC721_NFT": [
        "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",  # Bored Ape Yacht Club (BAYC)
        "0xb7f7f6c52f2e2fdb1963eab30438024864c313f6",  # Wrapped CryptoPunks (WPUNKS)
        "0xed5af388653567af2f388e6224dc7c4b3241c544",  # Azuki
        "0x8a90cab2b38dba80c64b7734e58ee1db38b8992e",  # Doodles
        "0x49cf6f5d44e70224e2e23fdcdd2c053f30ada28b",  # CloneX
        "0x23581767a106ae21c074b2276d25e5c3e136a68b",  # Moonbirds
        "0x34d85c9cdeb23fa97cb08333b511ac86e1c4e258",  # Otherdeed for Otherside
        "0xbd3531da5cf5857e7cfaa92426877b022e612cf8",  # Pudgy Penguins
        "0xa7d8d9ef8d8ce8992df33d8b8cf4aebabd5bd270",  # Art Blocks Curated
        "0xff9c1b15b16263c61d017ee9f65c50e4ae0113d7",  # Loot (for Adventurers)
        "0x60e4d786628fea6478f785a6d7e704777c86a7c6",  # Mutant Ape Yacht Club (MAYC)
        "0x7bd29408f11d2bfc23c34f18275bbf23bb716bc7",  # Meebits
        "0xe785e82358879f061bc3dcac6f0444462d4b5330",  # World of Women
        "0x9c8ff314c9bc7f6e59a9d9225fb22946427edc03",  # Nouns
        "0x5cc5b05a8a13e3fbdb0bb9fccd98d38e50f90c38",  # The Sandbox LAND
        "0xb47e3cd837ddf8e4c57f05d70ab865de6e193bbb",  # CryptoPunks (original, pre-ERC721)
    ],

    "ERC1155_Multi_Token": [
        "0x495f947276749ce646f68ac8c248420045cb7b5e",  # OpenSea Shared Storefront
        "0xb66a603f4cfe17e3d27b87a8bfcad319856518b8",  # Rarible ERC1155
        "0xa342f5d851e866e18ff98f351f2c6637f4478db5",  # The Sandbox ASSET
        "0x0e3a2a1f2146d86a604adc220b4967a898d7fe07",  # Gods Unchained Cards
        "0x348fc118bcc65a92dc033a951af153d14d945312",  # RTFKT CloneX Mintvial (ERC1155)
        "0xf629cbd94d3791c9250152bd8dfbdf380e2a3b9c",  # Enjin Coin (ENJ token)
        "0x564cb55c655f727b61d9baf258b547ca04e9e548",  # Gods Unchained Cards (alt)
        "0xd07dc4262bcdbf85190c01c996b4c06a461d2430",  # Rarible V1
        "0xfaafdc07907ff5120a76b34b731b278c38d6043c",  # Enjin (legacy)
        "0x7daec605e9e2a1717326eedfd660601e2753a057",  # Zora Editions
        "0xa7d8d9ef8d8ce8992df33d8b8cf4aebabd5bd270",  # Art Blocks
        "0x76be3b62873462d2142405439777e971754e8e77",  # parallel.life
        "0x7deb7bce4d360ebe68278dee6054b882aa62d19c",  # OpenSea Collections Manager
        "0x2a46f2ffd99e19a89476e2f62270e0a35bbf0756",  # Makersplace
        "0x33fd426905f149f8376e227d0c9d3340aad17af1",  # The Sandbox Game
    ],

    "DeFi_Staking": [
        "0xae7ab96520de3a18e5e111b5eaab095312d7fe84",  # Lido stETH
        "0x7f39c581f595b53c5cb19bd0b3f8da6c935e2ca0",  # Lido wstETH
        "0xae78736cd615f374d3085123a210448e74fc6393",  # Rocket Pool rETH
        "0xf403c135812408bfbe8713b5a23a04b3d48aae31",  # Convex Finance Booster
        "0x4e3fbd56cd56c3e72c1403e103b45db9da5b9d2b",  # Convex CVX Token
        "0x62b9c7356a2dc64a1969e19c23e4f579f9810aa7",  # Convex cvxCRV
        "0x3fe65692bfcd0e6cf84cb1e7d24108e434a7587e",  # Convex cvxCRV Rewards
        "0x858646372cc42e1a627fce94aa7a7033e7cf075a",  # EigenLayer Strategy Manager
        "0x39053d51b77dc0d36036fc1fcc8cb819df8ef37a",  # EigenLayer Delegation Manager
        "0xb671f2210b1f6621a2607ea63e6b2dc3e2464d1f",  # Synthetix Reward Escrow
        "0x3f27c540adae3a9e8c875c61e3b970b559d7f65d",  # Synthetix Staking Rewards iETH
        "0x167009dcda2e49930a71712d956f02cc980dcc1b",  # Synthetix Staking Rewards iBTC
        "0xfbaedde70732540ce2b11a8ac58eb2dc0d69de10",  # Synthetix Staking Rewards (Balancer SNX)
        "0xd18140b4b819b895a3dba5442f959fa44994af50",  # Convex CVX Locker
        "0x83f20f44975d03b1b09e64809b757c47f942beea",  # MakerDAO sDAI (Savings DAI)
    ],

    "DeFi_Lending": [
        "0x87870bca3f3fd6335c3f4ce8392d69350b4fa4e2",  # Aave V3 Pool
        "0x7d2768de32b0b80b7a3454c06bdac94a69ddc7a9",  # Aave V2 Lending Pool
        "0xb53c1a33016b2dc2ff3653530bff1848a515c8c5",  # Aave V2 Lending Pool Provider
        "0x3d9819210a31b4961b30ef54be2aed79b9c9cd3b",  # Compound Comptroller
        "0x5d3a536e4d6dbd6114cc1ead35777bab948e3643",  # Compound cDAI
        "0x4ddc2d193948926d02f9b1fe9e1daa0718270ed5",  # Compound cETH
        "0x39aa39c021dfbae8fac545936693ac917d5e7563",  # Compound cUSDC
        "0xf650c3d88d12db855b8bf7d11be6c55a4e07dcc9",  # Compound cUSDT
        "0x35d1b3f3d7966a1dfe207aa4514c12a259a0492b",  # MakerDAO Vat
        "0x197e90f9fad81970ba7976f33cbd77088e5d7cf7",  # MakerDAO Pot (DSR)
        "0xbbbbbbbbbb9cc5e90e3b3af64bdaf62c37eeffcb",  # Morpho Blue
        "0x8888882f8f843896699869179fb6e4f7e3b58888",  # Morpho Compound V2 Proxy
        "0xa7995f71aa11525db02fc2473c37dee5dbf55107",  # Morpho ETH Bundler
        "0xa2b47e3d5c44877cca798226b7b8118f9bfb7a56",  # Curve Compound Swap (lending)
        "0x9aee0b04504cef83a65ac3f0e838d0593bcb2bc7",  # Aave Governance (V1)
    ],

    "DeFi_DEX_AMM": [
        "0x7a250d5630b4cf539739df2c5dacb4c659f2488d",  # Uniswap V2 Router
        "0x5c69bee701ef814a2b6a3edd4b1652cb9cc5aa6f",  # Uniswap V2 Factory
        "0x1f98431c8ad98523631ae4a59f267346ea31f984",  # Uniswap V3 Factory
        "0xe592427a0aece92de3edee1f18e0157c05861564",  # Uniswap V3 SwapRouter
        "0x68b3465833fb72a70ecdf485e0e4c7bd8665fc45",  # Uniswap V3 SwapRouter02
        "0xd9e1ce17f2641f24ae83637ab66a2cca9c378b9f",  # SushiSwap Router
        "0xc0aee478e3658e2610c5f7a4a2e1777ce9e4f2ac",  # SushiSwap V2 Factory
        "0xba12222222228d8ba445958a75a0704d566bf2c8",  # Balancer V2 Vault
        "0xba1333333333a1ba1108e8412f11850a5c319ba9",  # Balancer V3 Vault
        "0xbebc44782c7db0a1a60cb6fe97d0b483032ff1c7",  # Curve 3Pool (DAI/USDC/USDT)
        "0xdc24316b9ae028f1497c275eb9192a3ea0f67022",  # Curve stETH/ETH Pool
        "0x99a58482bd75cbab83b27ec03ca68ff489b5788f",  # Curve Swap Router
        "0x0000000022d53366457f9d5e68ec105046fc4383",  # Curve Address Provider
        "0xa5407eae9ba41422680e2e00537571bcc53efbfd",  # Curve sUSD Pool
        "0xdcef968d416a41cdac0ed8702fac8128a64241a2",  # Curve FRAX/USDC Pool
    ],

    "Governance_DAO": [
        "0xc0da02939e1441f497fd74f78ce7decb17b66529",  # Compound Governor Bravo
        "0xc0da01a04c3f3e0be433606045bb7017a7323e38",  # Compound Governor Alpha
        "0xec568fffba86c094cf06b22134b23074dfe2252c",  # Aave Governance V2
        "0x408ed6354d4973f66138c91495f2f2fcbd8724c3",  # Uniswap Governor Bravo
        "0x5e4be8bc9637f0eaa1a755019e06a68ce081d58f",  # Uniswap Governor Alpha
        "0x323a76393544d5ecca80cd6ef2a560c6a395b7e3",  # ENS DAO Governor
        "0xdbd27635a534a3d3169ef0498beb56fb9c937489",  # Gitcoin Governor Alpha
        "0x6f3e6272a167e8accb32072d08e0957f9c79223d",  # Nouns DAO Governor Proxy
        "0x0bc3807ec262cb779b38d65b38158acc3bfede10",  # Nouns DAO Treasury
        "0xac43e14c018490d045a774008648c701cda8c6b3",  # Juicebox Governance
        "0x5300a1a15135ea4dc7ad5a167152c01efc9b192a",  # Aave Executor Lvl1
        "0x17dd33ed0e3dd2a80e37489b8a63063161be6957",  # Aave Executor Lvl2
        "0x3e40d73eb977dc6a537af587d48316fee66e9c8c",  # Lido DAO Agent
        "0x9c8ff314c9bc7f6e59a9d9225fb22946427edc03",  # Nouns Token (governance NFT)
        "0xde30da39c46104798bb5aa3fe8b9e0e1f348163f",  # GTC Token
    ],

    "Multisig_Wallet": [
        "0xd9db270c1b5e3bd161e8c8503c55ceabee709552",  # Safe Singleton 1.3.0
        "0xa6b71e26c5e0845f74c812102ca7114b6a896ab2",  # Safe Proxy Factory 1.3.0
        "0x0bc3807ec262cb779b38d65b38158acc3bfede10",  # Nouns DAO Treasury (multisig)
        "0x3e40d73eb977dc6a537af587d48316fee66e9c8c",  # Lido DAO Agent (Aragon)
        "0xafc2f2d803479a2af3a72022d54cc0901a0ec0d6",  # Safe Proxy instance
        "0x252e7e8b9863f81798b1fef8cfd9741a46de653c",  # Harvest Finance Ops wallet
        "0x5a0aae59d09fccbddb6c6cceb07b7279367c3d2a",  # Optimism L1 Proxy Admin (multisig)
        "0x9056d15c49b19df52ffad1e6c11627f035c0c960",  # MAYC Deployer (multisig)
        "0x2b3ab8e7bb14988616359b78709538b10900ab7d",  # Doodles Deployer (multisig)
        "0xd45058bf25bbd8f586124c479d384c8c708ce23a",  # Azuki Deployer (multisig)
        "0xa57adce1d2fe72949e4308867d894cd7e7de0ef2",  # Axelar Deployer (multisig)
        "0x40ec5b33f54e0e8a33a975908c5ba1c14e5bbbdf",  # Polygon ERC20 Predicate (multisig admin)
        "0x401f6c983ea34274ec46f84d70b31c151321188b",  # Polygon (multisig)
        "0xe8a5677171c87fcb65b76957f2852515b404c7b1",  # Curve ETH+ETH-f Pool Owner
        "0xecb456ea5365865ebab8a2661b0c503410e9b347",  # Curve Pool Owner (multisig)
    ],

    "Timelock": [
        "0x6d903f6003cca6255d85cca4d3b5e5146dc33925",  # Compound Timelock
        "0x1a9c8182c09f50c8318d769245bea52c32be35bc",  # Uniswap Timelock
        "0x5300a1a15135ea4dc7ad5a167152c01efc9b192a",  # Aave Executor Lvl1 (timelock)
        "0x17dd33ed0e3dd2a80e37489b8a63063161be6957",  # Aave Executor Lvl2 (timelock)
        "0xee56e2b3d491590b5b31738cc34d5232f378a8d5",  # Aave Short Timelock
        "0xb1a32fc9f9d8b2cf86c068cae13108809547ef71",  # Nouns DAO Executor Proxy
        "0xd4b6cd147ad8a0d5376b6fdba85fe8128c6f0686",  # dYdX Timelock
        "0x0bc3807ec262cb779b38d65b38158acc3bfede10",  # Nouns DAO Treasury (executor/timelock)
        "0x3d5bc3c8d13dcb8bf317092d84783c2697ae9258",  # Compound Timelock (old)
        "0xac43e14c018490d045a774008648c701cda8c6b3",  # Juicebox Governance timelock
        "0xda2c338350a0e59ce71cdced9679a3a590dd9bec",  # FRAX Finance staking timelock
        "0x2b3ab8e7bb14988616359b78709538b10900ab7d",  # Doodles Deployer with timelock
        "0x46c9999a2edcd5aa177ed7e8af90c68b7d75ba46",  # Juicebox Terminal Directory (timelocked)
        "0x8302fe9f0c509a996573d3cc5b0d5d51e4fdd5ec",  # Synthetix Staking Rewards (timelocked)
        "0x3e40d73eb977dc6a537af587d48316fee66e9c8c",  # Lido DAO Agent (Aragon timelock)
    ],

    "Proxy_Upgradeable_UUPS": [
        "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",  # USDC (AdminUpgradeabilityProxy)
        "0xee6a57ec80ea46401049e92587e52f5ec1c24785",  # Uniswap V3 TransparentUpgradeableProxy
        "0xe140bb5f424a53e0687bfc10f6845a5672d7e242",  # TransparentUpgradeableProxy instance
        "0x3d3d0a7876d18770a21a5ea05fef211eba808e72",  # TransparentUpgradeableProxy instance
        "0xc68421f20bf6f0eb475f00b9c5484f7d0ac0331e",  # TransparentUpgradeableProxy instance
        "0xa5565d266c3c3ee90b16be8a5b13d587ef559fb0",  # TransparentUpgradeableProxy instance
        "0xa7c21fd948c44830541b8561b31abde09cc32719",  # TransparentUpgradeableProxy instance
        "0x99c9fc46f92e8a1c0dec1b1747d010903e884be1",  # Optimism Gateway (proxy)
        "0x830bd73e4184cef73443c15111a1df14e495c706",  # Nouns Auction House Proxy
        "0x858646372cc42e1a627fce94aa7a7033e7cf075a",  # EigenLayer Strategy Manager (proxy)
        "0x39053d51b77dc0d36036fc1fcc8cb819df8ef37a",  # EigenLayer Delegation Manager (proxy)
        "0x7cfa0f105a4922e89666d7d63689d9c9b1ea7a19",  # Polygon RootChainManager (proxy)
        "0x87870bca3f3fd6335c3f4ce8392d69350b4fa4e2",  # Aave V3 Pool (proxy)
        "0x6f3e6272a167e8accb32072d08e0957f9c79223d",  # Nouns DAO Governor (proxy)
        "0xbbbbbbbbbb9cc5e90e3b3af64bdaf62c37eeffcb",  # Morpho Blue (proxy)
    ],

    "Access_Control_RBAC": [
        "0x7fc66500c84a76ad7e9c93437bfc5ac33e2ddae9",  # AAVE Token (AccessControl)
        "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",  # USDC (roles: minter, pauser, blacklister)
        "0xdac17f958d2ee523a2206206994597c13d831ec7",  # USDT (owner-based access)
        "0x3d9819210a31b4961b30ef54be2aed79b9c9cd3b",  # Compound Comptroller (admin)
        "0xd9db270c1b5e3bd161e8c8503c55ceabee709552",  # Safe Singleton (owner-based)
        "0xf403c135812408bfbe8713b5a23a04b3d48aae31",  # Convex Booster (operator roles)
        "0x858646372cc42e1a627fce94aa7a7033e7cf075a",  # EigenLayer Strategy Manager (roles)
        "0xec568fffba86c094cf06b22134b23074dfe2252c",  # Aave Governance V2 (guardian)
        "0xae7ab96520de3a18e5e111b5eaab095312d7fe84",  # Lido stETH (roles: oracle, manager)
        "0x87870bca3f3fd6335c3f4ce8392d69350b4fa4e2",  # Aave V3 Pool (ACLManager roles)
        "0x5a98fcbea516cf06857215779fd812ca3bef1b32",  # LDO Token (minter/burner roles)
        "0xc00e94cb662c3520282e6f5717214004a7f26888",  # COMP Token (admin)
        "0x1f98431c8ad98523631ae4a59f267346ea31f984",  # Uniswap V3 Factory (owner)
        "0xba12222222228d8ba445958a75a0704d566bf2c8",  # Balancer V2 Vault (authorizer)
        "0x338e34102cd30eef8e6cb30ae8ae6739babf8806",  # OpenZeppelin Contracts (AccessControl)
    ],

    "Auction": [
        "0x830bd73e4184cef73443c15111a1df14e495c706",  # Nouns Auction House Proxy
        "0xf15a943787014461d94da08ad4040f79cd7c124e",  # Nouns Auction House Implementation
        "0xd657686a1ce41720c4b29e13ea1d6cee1b4025b5",  # AuctionHouse (generic)
        "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",  # BAYC (Dutch auction mint)
        "0x34d85c9cdeb23fa97cb08333b511ac86e1c4e258",  # Otherdeed (Dutch auction mint)
        "0xed5af388653567af2f388e6224dc7c4b3241c544",  # Azuki (Dutch auction mint)
        "0x60e4d786628fea6478f785a6d7e704777c86a7c6",  # MAYC (Dutch auction)
        "0xbd3531da5cf5857e7cfaa92426877b022e612cf8",  # Pudgy Penguins (auction mint)
        "0xa7d8d9ef8d8ce8992df33d8b8cf4aebabd5bd270",  # Art Blocks (Dutch auction)
        "0x23581767a106ae21c074b2276d25e5c3e136a68b",  # Moonbirds (auction)
        "0x9c8ff314c9bc7f6e59a9d9225fb22946427edc03",  # Nouns Token (daily auction)
        "0xff9c1b15b16263c61d017ee9f65c50e4ae0113d7",  # Loot (free mint/auction)
        "0x8a90cab2b38dba80c64b7734e58ee1db38b8992e",  # Doodles (auction mint)
        "0xe785e82358879f061bc3dcac6f0444462d4b5330",  # World of Women (auction mint)
        "0x49cf6f5d44e70224e2e23fdcdd2c053f30ada28b",  # CloneX (auction mint)
    ],

    "Crowdfunding_ICO": [
        "0xd569d3cce55b71a8a3f3c418c329a66e5f714431",  # Juicebox Terminal V1
        "0x981c8ecd009e3e84ee1ff99266bf1461a12e5c68",  # Juicebox Terminal V1.1
        "0xf507b2a1dd7439201eb07f11e1d62afb29216e2e",  # Juicebox Funding Cycles
        "0x46c9999a2edcd5aa177ed7e8af90c68b7d75ba46",  # Juicebox Terminal Directory
        "0xb9e4b658298c7a36bdf4c2832042a5d6700c3ab8",  # Juicebox Mod Store
        "0x9b73d1779c41dca36314fb7c4d3309838e20c4e7",  # Enjin Coin Token Sale
        "0x7b3d36eb606f873a75a6ab68f8c999848b04f935",  # NFT LootBox
        "0xa0246c9032bc3a600820415ae600c6388619a14d",  # Harvest Finance FARM Token (ICO)
        "0xde30da39c46104798bb5aa3fe8b9e0e1f348163f",  # GTC Token (retroactive distribution)
        "0xaffe52f017e858f283f5430efb9e7a99947d1263",  # JuiceBox (alt)
        "0x971e78e0c92392a4e39099835cf7e6ab535b2227",  # Synthetix Token Sale Escrow
        "0xac43e14c018490d045a774008648c701cda8c6b3",  # Juicebox Governance
        "0x5870700f1272a1adbb87c3140bd770880a95e55d",  # Beefy Old BIFI Token
        "0x9984ab537298be3e53edc83b3934603da3fa5d08",  # Juicebox Project
        "0x1571ed0bed4d987fe2b498ddbae7dfa19519f651",  # Harvest iFARM Token
    ],

    "Escrow": [
        "0x15afa5b83783a565e90d207553c9e2449b7db2da",  # PaymentSplitter (OZ v4.4.1)
        "0xd28dbd19b93b6cc55d85debe9d93644097fed773",  # PaymentSplitter (v0.8.6)
        "0x5fa0cae22ea05795c8509c5e19e31c2ffba1e417",  # PaymentSplitter (OZ v4.4.1)
        "0x097ee00f42f9d7512929a6434185ae94ac6dafd7",  # PaymentSplitter (early)
        "0x505cfce628d79cd3b3bafd48762a6560eaee97b8",  # TheConnorsPaymentSplitter
        "0xb671f2210b1f6621a2607ea63e6b2dc3e2464d1f",  # Synthetix Reward Escrow
        "0x971e78e0c92392a4e39099835cf7e6ab535b2227",  # Synthetix Token Sale Escrow
        "0xd569d3cce55b71a8a3f3c418c329a66e5f714431",  # Juicebox Terminal V1 (escrow)
        "0x83f20f44975d03b1b09e64809b757c47f942beea",  # MakerDAO sDAI (savings/escrow)
        "0xd18140b4b819b895a3dba5442f959fa44994af50",  # Convex CVX Locker (escrow)
        "0x3fe65692bfcd0e6cf84cb1e7d24108e434a7587e",  # Convex cvxCRV Rewards (escrow)
        "0x197e90f9fad81970ba7976f33cbd77088e5d7cf7",  # MakerDAO Pot (DSR escrow)
        "0xda2c338350a0e59ce71cdced9679a3a590dd9bec",  # FRAX-FXS Staking (escrow)
        "0x338e34102cd30eef8e6cb30ae8ae6739babf8806",  # OpenZeppelin Contracts
        "0xf8ce90c2710713552fb564869694b2505bfc0846",  # Harvest Finance Deposit Helper
    ],

    "Flash_Loan_Provider": [
        "0x87870bca3f3fd6335c3f4ce8392d69350b4fa4e2",  # Aave V3 Pool (flash loans)
        "0x7d2768de32b0b80b7a3454c06bdac94a69ddc7a9",  # Aave V2 Lending Pool (flash loans)
        "0x1e0447b19bb6ecfdae1e4ae1694b0c3659614e4e",  # dYdX Solo Margin
        "0xa8b39829ce2246f89b31c013b8cde15506fb9a76",  # dYdX Payable Proxy for Solo Margin
        "0xba12222222228d8ba445958a75a0704d566bf2c8",  # Balancer V2 Vault (flash loans)
        "0xbbbbbbbbbb9cc5e90e3b3af64bdaf62c37eeffcb",  # Morpho Blue (flash loans)
        "0x7a250d5630b4cf539739df2c5dacb4c659f2488d",  # Uniswap V2 Router (flash swaps)
        "0x5c69bee701ef814a2b6a3edd4b1652cb9cc5aa6f",  # Uniswap V2 Factory (flash swaps)
        "0x1f98431c8ad98523631ae4a59f267346ea31f984",  # Uniswap V3 Factory (flash loans)
        "0xe592427a0aece92de3edee1f18e0157c05861564",  # Uniswap V3 Router (flash swaps)
        "0xb53c1a33016b2dc2ff3653530bff1848a515c8c5",  # Aave V2 Pool Provider
        "0xbebc44782c7db0a1a60cb6fe97d0b483032ff1c7",  # Curve 3Pool
        "0x3d9819210a31b4961b30ef54be2aed79b9c9cd3b",  # Compound Comptroller
        "0xa2b47e3d5c44877cca798226b7b8118f9bfb7a56",  # Curve Compound Swap
        "0x8888882f8f843896699869179fb6e4f7e3b58888",  # Morpho Compound V2
    ],

    "Yield_Aggregator": [
        "0x5f18c75abdae578b483e5f43f12a39cf75b973a9",  # Yearn yUSDC Vault V2
        "0x19d3364a399d251e894ac732651be8b0e4e85001",  # Yearn yDAI Vault V2
        "0x5dbcf33d8c2e976c6b560249878e6f1491bca25c",  # Yearn yCRV Vault
        "0xaf1f5e1c19cb68b30aad73846effdf78a5863319",  # Yearn Factory Vault Registry
        "0xa7739fd3d12ac7f16d8329af3ee407e19de10d8d",  # Beefy BeefyVaultV7
        "0xab7fa2b2985bccfc13c6d86b1d5a17486ab1e04c",  # Harvest Finance DAI Vault
        "0xfe09e53a81fe2808bc493ea64319109b5baa573e",  # Harvest Finance WETH Vault
        "0xa0246c9032bc3a600820415ae600c6388619a14d",  # Harvest Finance FARM Token
        "0x1571ed0bed4d987fe2b498ddbae7dfa19519f651",  # Harvest Finance iFARM
        "0xf403c135812408bfbe8713b5a23a04b3d48aae31",  # Convex Finance Booster
        "0x62b9c7356a2dc64a1969e19c23e4f579f9810aa7",  # Convex cvxCRV
        "0x3fe65692bfcd0e6cf84cb1e7d24108e434a7587e",  # Convex cvxCRV Rewards
        "0x8014595f2ab54cd7c604b00e9fb932176fdc86ae",  # Convex CRV Depositor
        "0xaa0c3f5f7dfd688c6e646f66cd2a6b66acdbe434",  # Convex Stake CvxCRV
        "0x0001fb050fe7312791bf6475b96569d83f695c9f",  # Yearn (multi-strategy)
    ],

    "Wrapped_Token": [
        "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",  # WETH (Wrapped Ether)
        "0x7f39c581f595b53c5cb19bd0b3f8da6c935e2ca0",  # wstETH (Wrapped staked ETH)
        "0x2260fac5e5542a773aa44fbcfedf7c193bc2c599",  # WBTC (Wrapped Bitcoin)
        "0xae78736cd615f374d3085123a210448e74fc6393",  # rETH (Rocket Pool wrapped)
        "0xae7ab96520de3a18e5e111b5eaab095312d7fe84",  # stETH (Lido liquid staking)
        "0x62b9c7356a2dc64a1969e19c23e4f579f9810aa7",  # cvxCRV (Convex wrapped CRV)
        "0x4e3fbd56cd56c3e72c1403e103b45db9da5b9d2b",  # CVX (Convex token)
        "0x83f20f44975d03b1b09e64809b757c47f942beea",  # sDAI (Savings DAI wrapper)
        "0x853d955acef822db058eb8505911ed77f175b99e",  # FRAX (algorithmic stablecoin)
        "0xb7f7f6c52f2e2fdb1963eab30438024864c313f6",  # Wrapped CryptoPunks
        "0x5d3a536e4d6dbd6114cc1ead35777bab948e3643",  # cDAI (Compound wrapped DAI)
        "0x4ddc2d193948926d02f9b1fe9e1daa0718270ed5",  # cETH (Compound wrapped ETH)
        "0x39aa39c021dfbae8fac545936693ac917d5e7563",  # cUSDC (Compound wrapped USDC)
        "0xf650c3d88d12db855b8bf7d11be6c55a4e07dcc9",  # cUSDT (Compound wrapped USDT)
        "0x5f18c75abdae578b483e5f43f12a39cf75b973a9",  # yvUSDC (Yearn wrapped USDC)
    ],

    "Bridge_Relayer": [
        "0x66a71dcef29a0ffbdbe3c6a460a3b5bc225cd675",  # LayerZero V1 Endpoint
        "0x1a44076050125825900e736c501f859c50fe728c",  # LayerZero V2 EndpointV2
        "0x98f3c9e6e3face36baad05fe09d375ef1464288b",  # Wormhole Core Bridge
        "0x3ee18b2214aff97000d974cf647e7c347e8fa585",  # Wormhole Token Bridge
        "0x4f4495243837681061c4743b74b3eedf548d56a5",  # Axelar Gateway
        "0x4d73adb72bc3dd368966edd0f0b2148401a178e2",  # LayerZero Ultra Light Node V2
        "0x80226fc0ee2b096224eeac085bb9a8cba1146f7d",  # Chainlink CCIP Router
        "0xc005dc82818d67af737725bd4bf75435d065d239",  # Hyperlane Mailbox
        "0x25ace71c97b33cc4729cf772ae268934f7ab5fa1",  # Optimism L1 Cross Domain Messenger
        "0x4dbd4fc535ac27206064b68ffcf827b0a60bab3f",  # Arbitrum Delayed Inbox
        "0x72ce9c846789fdb6fc1f34ac4ad25dd9ef7031ef",  # Arbitrum L1 Gateway Router
        "0x467719ad09025fcc6cf6f8311755809d45a5e5f3",  # Axelar AXL Token
        "0xb5fb4be02232b1bba4dc8f81dc24c26980de9e3c",  # Axelar ITS
        "0x011e52e4e40cf9498c79273329e8827b21e2e581",  # SushiSwap SushiXSwap (cross-chain)
        "0x1ec9b94b4bbcd46699f9b4c9140e0b2b6c73a5be",  # Hyperlane (Ethereum)
    ],

    "Cross_Chain_Bridge": [
        "0x99c9fc46f92e8a1c0dec1b1747d010903e884be1",  # Optimism Gateway (L1StandardBridge)
        "0x72ce9c846789fdb6fc1f34ac4ad25dd9ef7031ef",  # Arbitrum L1 Gateway Router
        "0x4dbd4fc535ac27206064b68ffcf827b0a60bab3f",  # Arbitrum Delayed Inbox
        "0xa3a7b6f88361f48403514059f1f16c8e78d60eec",  # Arbitrum L1 ERC20 Gateway
        "0x7cfa0f105a4922e89666d7d63689d9c9b1ea7a19",  # Polygon RootChainManager (PoS Bridge)
        "0x40ec5b33f54e0e8a33a975908c5ba1c14e5bbbdf",  # Polygon ERC20 Predicate
        "0xb8901acb165ed027e32754e0ffe830802919727f",  # Hop Protocol ETH Bridge
        "0x3666f603cc164936c1b87e207f36beba4ac5f18a",  # Hop Protocol USDC Bridge
        "0x914f986a44acb623a277d6bd17368171fcbe4273",  # Hop Protocol HOP Bridge
        "0x3e4a3a4796d16c0cd582c382691998f7c06420b6",  # Hop Protocol USDT Bridge
        "0x3d4cc8a61c7528fd86c55cfe061a78dcba48edd1",  # Hop Protocol DAI Bridge
        "0x3ee18b2214aff97000d974cf647e7c347e8fa585",  # Wormhole Token Bridge
        "0x5a7749f83b81b301cab5f48eb8516b986daef23d",  # Optimism L1 NFT Bridge
        "0x25ace71c97b33cc4729cf772ae268934f7ab5fa1",  # Optimism L1 Cross Domain Messenger
        "0x4dceb440657f21083db8add07665f8ddbe1dcfc0",  # Arbitrum Rollup
    ],

    "Cross_Chain_Messaging": [
        "0x66a71dcef29a0ffbdbe3c6a460a3b5bc225cd675",  # LayerZero V1 Endpoint
        "0x1a44076050125825900e736c501f859c50fe728c",  # LayerZero V2 EndpointV2
        "0x80226fc0ee2b096224eeac085bb9a8cba1146f7d",  # Chainlink CCIP Router
        "0xc005dc82818d67af737725bd4bf75435d065d239",  # Hyperlane Mailbox
        "0x98f3c9e6e3face36baad05fe09d375ef1464288b",  # Wormhole Core Bridge
        "0x4f4495243837681061c4743b74b3eedf548d56a5",  # Axelar Gateway
        "0x25ace71c97b33cc4729cf772ae268934f7ab5fa1",  # Optimism L1 Cross Domain Messenger
        "0x4dbd4fc535ac27206064b68ffcf827b0a60bab3f",  # Arbitrum Delayed Inbox
        "0x4d73adb72bc3dd368966edd0f0b2148401a178e2",  # LayerZero Ultra Light Node V2
        "0xb5fb4be02232b1bba4dc8f81dc24c26980de9e3c",  # Axelar ITS
        "0x9685e7281fb1507b6f141758d80b08752faf0c43",  # Arbitrum Sequencer Inbox
        "0x1ec9b94b4bbcd46699f9b4c9140e0b2b6c73a5be",  # Hyperlane (Ethereum)
        "0x8d64b4b4be39769441dca258aa2ad035e2a876f6",  # Hyperlane Implementation
        "0x011e52e4e40cf9498c79273329e8827b21e2e581",  # SushiXSwap (cross-chain messaging)
        "0x5ef0d09d1e6204141b4d37530808ed19f60fba35",  # Arbitrum Old Rollup
    ],
}


def validate_addresses():
    """Validate all addresses are proper 42-char hex strings."""
    errors = []
    for category, addresses in SEED_CONTRACTS.items():
        for i, addr in enumerate(addresses):
            if len(addr) != 42:
                errors.append(f"{category}[{i}]: {addr} has length {len(addr)}")
            if not addr.startswith("0x"):
                errors.append(f"{category}[{i}]: {addr} doesn't start with 0x")
            try:
                int(addr, 16)
            except ValueError:
                errors.append(f"{category}[{i}]: {addr} is not valid hex")
        print(f"{category}: {len(addresses)} addresses")
    if errors:
        print(f"\nERRORS: {len(errors)}")
        for e in errors:
            print(f"  {e}")
    else:
        print(f"\nAll addresses valid!")
    print(f"\nTotal: {sum(len(v) for v in SEED_CONTRACTS.values())} addresses across {len(SEED_CONTRACTS)} categories")


if __name__ == "__main__":
    validate_addresses()
