import { HardhatRuntimeEnvironment, TaskArguments } from "hardhat/types";
import {
  CONTRACT_NAME,
  DEFAULT_ENV,
  DEPLOY_TREASURY_CONTRACT,
  VERIFY_TREASURY_CONTRACT,
  EXCHANGE_TOKEN,
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
import ERC1967Proxy from "@openzeppelin/contracts/build/contracts/ERC1967Proxy.json";

const contractName: string = CONTRACT_NAME.Treasury;
const contractType = ContractType.Intializable;

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
