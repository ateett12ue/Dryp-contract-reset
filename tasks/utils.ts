/* eslint-disable no-unused-vars */
import fs from "fs";
import { HardhatRuntimeEnvironment } from "hardhat/types";
export enum ContractType {
  None,
  Intializable,
  Token,
  TokenPool,
  Treasury,
  Proxy,
}

export interface IDeployment {
  [env: string]: {
    [chainId: string]: {
      [contractName: string]: string;
    };
  };
}

export interface IDeploymentAdapters {
  [env: string]: {
    [chainId: string]: Array<{
      name: string;
      address: string;
    }>;
  };
}

const getFilePath = (contractType: ContractType): string => {
  const path = "deployment/deployments.json";
  return path;
};

export async function recordAllDeployments(
  env: string,
  network: string,
  contractType: ContractType,
  contractName: string,
  address: string
): Promise<IDeployment | IDeploymentAdapters> {
  const path = getFilePath(contractType);
  const deployment = JSON.parse(fs.readFileSync(path, "utf-8"));
  if (contractType === ContractType.None) {
    const deployments: IDeployment = deployment;

    if (!deployments[env]) {
      deployments[env] = {};
    }

    if (!deployments[env][network]) {
      deployments[env][network] = {};
    }

    deployments[env][network][contractName] = address;
    return deployments;
  } else {
    const deployments: IDeploymentAdapters = deployment;
    if (!deployments[env]) {
      deployments[env] = {};
    }

    if (!deployments[env][network]) {
      deployments[env][network] = [];
    }

    const length = deployments[env][network].length;

    let index = length;
    for (let i = 0; i < length; i++) {
      if (deployments[env][network][i].name === contractName) {
        index = i;
        break;
      }
    }

    deployments[env][network][index] = {
      name: contractName,
      address,
    };

    return deployments;
  }
}

export async function saveDeployments(
  contractType: ContractType,
  deployment: IDeployment | IDeploymentAdapters
) {
  const path = getFilePath(contractType);
  fs.writeFileSync(path, JSON.stringify(deployment));
}

export function getDeployments(
  contractType: ContractType
): IDeployment | IDeploymentAdapters {
  const path = getFilePath(contractType);
  const deployment = JSON.parse(fs.readFileSync(path, "utf-8"));

  if (contractType === ContractType.None) {
    const deployments: IDeployment = deployment;
    return deployments;
  } else {
    const deployments: IDeploymentAdapters = deployment;
    return deployments;
  }
}

export async function verifyProxy(
  proxyAddr: string,
  hre: HardhatRuntimeEnvironment
) {
  const implementationAddr =
    await hre.upgrades.erc1967.getImplementationAddress(proxyAddr);
  console.log("Contract Verification Started", implementationAddr);
  try {
    await hre.run("verify:verify", {
      address: implementationAddr,
    });
  } catch (err) {
    console.error(err);
  }
  console.log("Contract Verification Ended");
}
