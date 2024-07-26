import { HardhatRuntimeEnvironment, TaskArguments } from "hardhat/types";
import {
  CONTRACT_NAME,
  DEFAULT_ENV,
  DEPLOY_TOKEN_CONTRACT,
  VERIFY_DEPLOY_TOKEN_CONTRACT,
} from "../../constants";
import { task } from "hardhat/config";
import {
  ContractType,
  recordAllDeployments,
  saveDeployments,
  getDeployments,
  IDeploymentAdapters,
  verifyProxy,
} from "../../utils";

const contractName: string = CONTRACT_NAME.Token;
const contractType = ContractType.Intializable;

task(DEPLOY_TOKEN_CONTRACT)
  .addFlag("verify", "pass true to verify the contract")
  .setAction(async function (
    _taskArguments: TaskArguments,
    _hre: HardhatRuntimeEnvironment
  ) {
    let env = process.env.ENV;
    if (!env) env = DEFAULT_ENV;
    const network = await _hre.getChainId();

    console.log(`Deploying ${contractName} Contract on chainId ${network}....`);
    const Dryp = await _hre.ethers.getContractFactory("Dryp");
    const drypTokenProxy = await _hre.upgrades.deployProxy(
      Dryp,
      ["DRYP", "dryp"],
      {
        initializer: "initialize",
      }
    );
    // const drypToken = await factory.deploy();
    await drypTokenProxy.waitForDeployment();
    console.log(
      "Dryp Token Proxy deployed to:",
      drypTokenProxy.target.toString()
    );

    // const { abi } = await _hre.artifacts.readArtifact("Dryp");
    // const iface = new _hre.ethers.utils.Interface(abi);
    // const callInitialize = iface.encodeFunctionData("initialize", [
    //   "DRYP",
    //   "dryp",
    // ]);
    // console.log("Dryp Initialize", callInitialize);
    // const Proxy = await _hre.ethers.getContractFactory(
    //   ERC1967Proxy.abi,
    //   ERC1967Proxy.bytecode
    // );
    // const proxy = await Proxy.deploy(drypToken.address, callInitialize);
    // console.log("Proxy deployed to:", proxy.address);

    const deploymentProxy = await recordAllDeployments(
      env,
      network,
      ContractType.Proxy,
      CONTRACT_NAME.TokenProxy,
      drypTokenProxy.target.toString()
    );
    // console.log(await upgrades.erc1967.getImplementationAddress(proxyAddress));

    await saveDeployments(ContractType.Proxy, deploymentProxy);

    const implementationAddr =
      await _hre.upgrades.erc1967.getImplementationAddress(
        drypTokenProxy.target.toString()
      );
    console.log("Dryp Token Imp deployed to:", implementationAddr);
    const deploymentImp = await recordAllDeployments(
      env,
      network,
      contractType,
      contractName,
      implementationAddr
    );

    await saveDeployments(contractType, deploymentImp);

    if (_taskArguments.verify === true) {
      await _hre.run(VERIFY_DEPLOY_TOKEN_CONTRACT);
    }

    // console.log(`${contractName} contract deployed at`, drypToken.address);
    // console.log(`_taskArguments`, _taskArguments);
    // if (_taskArguments.verify === true) {
    //   await _hre.run(VERIFY_DEPLOY_TOKEN_CONTRACT);
    // }
  });

task(VERIFY_DEPLOY_TOKEN_CONTRACT).setAction(async function (
  _taskArguments: TaskArguments,
  _hre: HardhatRuntimeEnvironment
) {
  let env = process.env.ENV;
  if (!env) env = DEFAULT_ENV;

  const network = await _hre.getChainId();

  const deployments = getDeployments(ContractType.Proxy) as IDeploymentAdapters;
  let address;
  for (let i = 0; i < deployments[env][network].length; i++) {
    if (deployments[env][network][i].name === CONTRACT_NAME.TokenProxy) {
      address = deployments[env][network][i].address;
      break;
    }
  }
  console.log(`Verifying ${contractName} Contract....`, address);
  await verifyProxy(String(address), _hre);

  console.log(`Verified ${contractName} contract address `, address);
});
