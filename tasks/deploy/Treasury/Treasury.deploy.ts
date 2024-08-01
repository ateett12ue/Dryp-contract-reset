import { HardhatRuntimeEnvironment, TaskArguments } from "hardhat/types";
import {
  CONTRACT_NAME,
  DEFAULT_ENV,
  DEPLOY_TREASURY_CONTRACT,
  VERIFY_TREASURY_CONTRACT,
  EXCHANGE_TOKEN,
  INITIALIZE_TREASURY_CONTRACT,
  GET_TREASURY_DETAILS,
  MINT_DRYP_WITH_USDT,
  UPDATE_TREASURY_CONTRACT,
  CALCULATE_REDEMPTION_VALUE
} from "../../constants";
import { task } from "hardhat/config";
import {
  ContractType,
  recordAllDeployments,
  saveDeployments,
  getDeployments,
  IDeploymentAdapters,
  verifyProxy
} from "../../utils";
import {TREASURY_TOKENS} from "./constants"
import {TreasuryAbi} from "./TreasuryAbi"
import {BigNumber} from "bignumber.js"
import {PoolAbi} from "./PoolAbi"
const contractName: string = CONTRACT_NAME.Treasury;
const contractType = ContractType.Intializable;
import {GetDollarValue} from "../../utils"
interface tokenAsset {
  address: string;
  name: string;
  decimal: number;
}

task(DEPLOY_TREASURY_CONTRACT)
  .addFlag("verify", "pass true to verify the contract")
  .setAction(async function (
    _taskArguments: TaskArguments,
    _hre: HardhatRuntimeEnvironment
  ) {
    let env = process.env.ENV;
    if (!env) env = DEFAULT_ENV;

    const network = await _hre.getChainId();

    console.log(`Deploying ${contractName} Contract on chainId ${network}....`);

    
    const treasuryManager = "0xBec33ce33afdAF5604CCDF2c4b575238C5FBD23d";
    const deployments = getDeployments(contractType) as IDeploymentAdapters;
    
    let drypToken = "0xA4ea74A4880cF488D2361cbB6f065d2030F0bB7E";
    // for (let i = 0; i < deployments[env][network].length; i++) {
    //   if (deployments[env][network][i].name === "DrypProxy") {
    //     drypToken = deployments[env][network][i].address;
    //     break;
    //   }
    // }
    const drypPool = "0xe5a2F24fd643A7d1a64406e3E688055692DEFDa2";
    const factory = await _hre.ethers.getContractFactory("Treasury");
    const factoryProxy = await _hre.upgrades.deployProxy(
      factory,
      [drypToken,
        drypPool,
        treasuryManager,
        EXCHANGE_TOKEN["11155111"].usdt.address,],
      {
        initializer: "initialize",
      }
    );
    await factoryProxy.waitForDeployment();
    console.log(
      "Treasury Proxy deployed to:",
      factoryProxy.target.toString()
    );

    const deploymentProxy = await recordAllDeployments(
      env,
      network,
      ContractType.Proxy,
      CONTRACT_NAME.TreasuryProxy,
      factoryProxy.target.toString()
    );

    await saveDeployments(ContractType.Proxy, deploymentProxy);

    const implementationAddr =
      await _hre.upgrades.erc1967.getImplementationAddress(
        factoryProxy.target.toString()
      );
    console.log("Factory Imp deployed to:", implementationAddr);
    const deploymentImp = await recordAllDeployments(
      env,
      network,
      contractType,
      contractName,
      implementationAddr
    );
    await saveDeployments(contractType, deploymentImp);
    if (_taskArguments.verify === true) {
      await _hre.run(VERIFY_TREASURY_CONTRACT);
    }
  });

task(VERIFY_TREASURY_CONTRACT).setAction(async function (
  _taskArguments: TaskArguments,
  _hre: HardhatRuntimeEnvironment
) {
  let env = process.env.ENV;
  if (!env) env = DEFAULT_ENV;

  const network = await _hre.getChainId();

  const deployments = getDeployments(ContractType.Proxy) as IDeploymentAdapters;
  let address;
  for (let i = 0; i < deployments[env][network].length; i++) {
    if (deployments[env][network][i].name === CONTRACT_NAME.TreasuryProxy) {
      address = deployments[env][network][i].address;
      break;
    }
  }
  console.log(`Verifying ${contractName} Contract....`, address);
  await verifyProxy(String(address), _hre);

  console.log(`Verified ${contractName} contract address `, address);
});

task(INITIALIZE_TREASURY_CONTRACT).setAction(async function (
  _taskArguments: TaskArguments,
  _hre: HardhatRuntimeEnvironment
) {
  let env = process.env.ENV;
  if (!env) env = DEFAULT_ENV;
  const network = await _hre.getChainId();
  console.log(`network`, network);
  const ethers = _hre.ethers;
  const rpc = process.env.SEPOLIA_URL;
  console.log(`rpc`, rpc);
  const provider = new ethers.JsonRpcProvider(rpc)

  const signer = new ethers.Wallet(String(process.env.PRIVATE_KEY), provider);
  
  let assets: Array<string> = []
  let decimals = []
  let allocatPercentage = []
  let price = []
  let amounts: Array<string> = []
  const totalDryp = 1000;
  const tokens = TREASURY_TOKENS[network];
  for (const token in tokens) {
    if (tokens.hasOwnProperty(token)) {
      const details = tokens[token];
      const allocatedValue = totalDryp * details.allocatedPercentage/100;
      const amount = allocatedValue / details.price;
      assets.push(details.address);
      decimals.push(details.decimals);
      allocatPercentage.push(details.allocatedPercentage);
      price.push(details.price);
      amounts.push(String((amount*10**details.decimals).toFixed(0)))
    }
  }
      console.log(`----------`);
      console.log(`Address: ${assets}`);
      console.log(`Decimals: ${decimals}`);
      console.log(`Allocated Percentage: ${allocatPercentage}`);
      console.log(`Price: ${price}`);
      console.log(`Amounts: ${amounts}`);
      console.log(`----------`);

  const approvalAbi = [
    "function approve(address spender, uint256 amount) public returns (bool)",
    "function allowance(address owner, uint256 spender) public view returns (uint256)"
  ];

  const contractAddress = "0x4c6ADD5Ed63564C148934FD87Baee6B961982DdE";
  const spenderAddress = process.env.OWNER;
  for(let i=0; i< assets.length; i++)
  {
    const tokenContract = new ethers.Contract(assets[i], approvalAbi, signer);
    const tx = await tokenContract.approve(contractAddress, amounts[i]);
    console.log(`Approval for ${assets[i]} transaction hash: ${tx.hash}`);
    const receipt = await tx.wait();
    console.log("Transaction confirmed", assets[i]);
  }

  console.log(`contractAddress`, contractAddress);
  
  const contract = new ethers.Contract(contractAddress, [
    "function startTreasury(address[] calldata _assets, uint8[] calldata _decimals, uint16[] calldata _allocatPercentage, uint32[] calldata _price, uint256[] calldata _amounts) external payable"
  ], signer);

  const tx = await contract.startTreasury(assets, decimals, allocatPercentage, price, amounts);
  console.log(`transaction hash: ${tx.hash}`);
  const receipt = await tx.wait();
  console.log("Transaction confirmed",receipt);

  console.log(`Treasury started with transaction hash: ${tx.hash}`);
});


task(GET_TREASURY_DETAILS).setAction(async function (
  _taskArguments: TaskArguments,
  _hre: HardhatRuntimeEnvironment
) {
  let env = process.env.ENV;
  if (!env) env = DEFAULT_ENV;
  const network = await _hre.getChainId();
  console.log(`network`, network);
  const ethers = _hre.ethers;
  const rpc = process.env.SEPOLIA_URL;
  console.log(`rpc`, rpc);
  const provider = new ethers.JsonRpcProvider(rpc)
  
  const contractAddress = "0x2321362De9777fA03591b3eBDa28E589C1d8cb29";

  const treasuryContract = new ethers.Contract(contractAddress, TreasuryAbi, provider);

  const signer = new ethers.Wallet(String(process.env.PRIVATE_KEY), provider);
  const treasuryContractSigner = new ethers.Contract(contractAddress, TreasuryAbi, signer);
  
  console.log("--------------")
  const treasuryStarted = await treasuryContract.isTreasuryStarted();
  console.log("treasuryStarted", treasuryStarted);
  console.log("--------------")
  const allAssets = await treasuryContract.getAllAssets(); // portfolio
  console.log("allAssets", allAssets);
  console.log("--------------")
  const allMintingAssets = await treasuryContract.getAllMinitingAssets();
  // portfolio
  console.log("allMintingAssets", allMintingAssets);
  console.log("--------------")
  const tokens = TREASURY_TOKENS[network];
  const assets: Array<tokenAsset> = [];
  for (const token in tokens) {
    if (tokens.hasOwnProperty(token)) {
      const details = tokens[token];
      let d = {
        address: details.address,
        name: token,
        decimal: details.decimals
      }
      assets.push(d)
    }
  }
  console.log("--------------")
  
  const redeemConfigA = [];
  const unredeemConfigA = [];
  const totalValueLocked = [];
  const totalValueLockedInUsdt = [];
  for(let i=0; i< assets.length; i++)
  {
    const balance = await treasuryContractSigner.checkBalance(assets[i].address);
    console.log(`balance of ${assets[i].name} : ${balance}`)
    totalValueLocked.push(balance);
    console.log("--------------");
    const balanceInUsdt = await treasuryContract._toUnitsPrice(assets[i].decimal, balance);
    console.log(`balance of ${assets[i].name} in Usdt: ${balanceInUsdt}`)
    totalValueLockedInUsdt.push(balanceInUsdt);
    console.log("--------------");
    const redeemConfigs = await treasuryContract.getRedeemAssetConfig(assets[i].address);
    console.log("configs redeem", redeemConfigs);
    redeemConfigA.push(redeemConfigs);
    console.log("--------------");
    const unredeemConfigs = await treasuryContract.getUnRedeemAssetConfig(assets[i].address);
    console.log("configs unredeem", unredeemConfigs);
    unredeemConfigA.push(unredeemConfigs);
    console.log("--------------");
    console.log("--------------");
  }

  let total = 0;
  const usdtDec = 6;
  console.log("--------------")
  for(let i=0; i< allAssets.length; i++)
    {
      const assetAddress = allAssets[i];
      if(!redeemConfigA[i][0])
      {
          continue;
      }
      let assetDecimal = redeemConfigA[i][1];
      const totalAssetLocked = totalValueLocked[i];
      if(usdtDec != assetDecimal)
      {
        const unitPriceInUsdt = totalValueLockedInUsdt[i];
        total += unitPriceInUsdt*redeemConfigA[i][3];
      }
      else
      {
        const totalDollarValue = totalAssetLocked[i];
        total += totalDollarValue;
      }
    }
  console.log("total",total)
  console.log("--------------")
  console.log("--------------")

  const totalValueLockedRd = await treasuryContract.totalValueLockedInRedeemBasket();
  console.log("total Value Locked Redeem", totalValueLockedRd)
  console.log("--------------")

  const totalValueLockedURD = await treasuryContract.totalValueLockedInNonRedeemBasket();
  console.log("total Value Locked UnRedeem", totalValueLockedURD)
  console.log("--------------")

  const totalValueLockedInRev = await treasuryContract.totalValueLockedInRevenue();
  console.log("total Value Locked In Revenue", totalValueLockedInRev)
  console.log("--------------")

});

task(MINT_DRYP_WITH_USDT).setAction(async function (
  _taskArguments: TaskArguments,
  _hre: HardhatRuntimeEnvironment
) {
  let env = process.env.ENV;
  if (!env) env = DEFAULT_ENV;
  const network = await _hre.getChainId();
  console.log(`network`, network);
  const ethers = _hre.ethers;
  const rpc = process.env.SEPOLIA_URL;
  console.log(`rpc`, rpc);
  const provider = new ethers.JsonRpcProvider(rpc)

  const _asset = EXCHANGE_TOKEN["11155111"].usdt.address;
  const _amount = 10000000;
  const _minimumDrypAmount = 10000000;
  

  const signer = new ethers.Wallet(String(process.env.PRIVATE_KEY), provider);
  const _recipient = signer.address;
  console.log(`_recipient`, _recipient);
  const treasury = "0x2321362De9777fA03591b3eBDa28E589C1d8cb29"
  console.log(`treasury`, treasury);
  const contract = new ethers.Contract(treasury,
    TreasuryAbi, signer);

  const isTokenAllowedForMinting = await contract.isTokenAllowedForMiniting(_asset);
  console.log(`isTokenAllowedForMinting`, isTokenAllowedForMinting);

  const _getDrypDollar = await contract._getDrypDollar(_amount, _asset);
  console.log(`_getDrypDollar`, _getDrypDollar);

  const totalValueLockedInRevB = await contract.totalValueLockedInRevenue();
  console.log("total Value Locked In Revenue before", totalValueLockedInRevB)
  console.log("--------------")
  const tx = await contract.mint(_asset, _amount, _minimumDrypAmount, _recipient);
  console.log(`transaction hash: ${tx.hash}`);
  const receipt = await tx.wait();
  console.log("Transaction confirmed",receipt.status);
  console.log("--------------")
  const totalValueLockedInRevA = await contract.totalValueLockedInRevenue();
  console.log("total Value Locked In Revenue before", totalValueLockedInRevA)
});

task("GET_DOLLAR_VALUE").setAction(async function (
  _taskArguments: TaskArguments,
  _hre: HardhatRuntimeEnvironment
) {
  let env = process.env.ENV;
  if (!env) env = DEFAULT_ENV;
  const network = await _hre.getChainId();
  console.log(`network`, network);
  const amount = await GetDollarValue("10000000","0xA4ea74A4880cF488D2361cbB6f065d2030F0bB7E",  _hre);
  console.log("amount", amount)
});


task(CALCULATE_REDEMPTION_VALUE)
  .setAction(async function (
    _taskArguments: TaskArguments,
    _hre: HardhatRuntimeEnvironment
  ) {
    let env = process.env.ENV;
    if (!env) env = DEFAULT_ENV;
    const rpc = process.env.SEPOLIA_URL;
    const ethers = _hre.ethers;
    const provider = new ethers.JsonRpcProvider(rpc);

    const treasury = "0x2321362De9777fA03591b3eBDa28E589C1d8cb29"
    console.log("treasury", treasury)
    const signer = new ethers.Wallet(String(process.env.PRIVATE_KEY), provider);
    const treasuryContract = new ethers.Contract(treasury,
      TreasuryAbi, signer);
      
    const _allAssets = await treasuryContract.getAllAssets();
    console.log("_allAssets", _allAssets)
    const amount = await GetDollarValue("10000000000000000000","0xA4ea74A4880cF488D2361cbB6f065d2030F0bB7E", _hre);
    console.log("amount", amount)
    
    const dollarValue = new BigNumber(amount).div(10**6);

    console.log("dollarValue", dollarValue.toString())
    const assetCount = _allAssets.length;
    let outputs: Array<string> = [];
    let totalUsdtValue = new BigNumber(0);

    let redeemAsset = [];

    for (let i = 0; i < assetCount; ++i) {
      let assetAddr = _allAssets[i];
      const redeemConfig = await treasuryContract.getRedeemAssetConfig(assetAddr);
      const redeemConfigs = {
        isSupported: redeemConfig[0],
        decimal:redeemConfig[1],
        amount: redeemConfig[4],
        priceInUsdt: redeemConfig[3],
        allotatedPercentange: redeemConfig[2]
      }
      redeemAsset.push(redeemConfigs)
    }
    let totalTreasuryValueInUSDT = new BigNumber(0);

    redeemAsset.forEach(token => {
      let tokenValueInUSD = new BigNumber(Number(token.amount)).mul(token.priceInUsdt).div(10 ** Number(token.decimal));
      totalTreasuryValueInUSDT = totalTreasuryValueInUSDT.plus(tokenValueInUSD);
    });

    console.log("totalTreasuryValueInUSDT", totalTreasuryValueInUSDT.toFixed(0).toString());
    console.log("dollarValue", dollarValue.toString());
    redeemAsset.forEach(token => {
      let tokenShareInUSDT = dollarValue.mul(Number(token.allotatedPercentange)/100);
      let tokenAmount = tokenShareInUSDT.mul(10 ** Number(token.decimal)).div(token.priceInUsdt);
      
      outputs.push(tokenAmount.toFixed(0).toString());
    });
    console.log("outputs", outputs);
  });