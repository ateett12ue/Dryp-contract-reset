export const NATIVE = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
export const DEFAULT_ENV = "testnet";

export const DEPLOY_ERC20_APPROVAL_ADAPTER = "DEPLOY_ERC20_APPROVAL_ADAPTER";
export const VERIFY_ERC20_APPROVAL_ADAPTER = "VERIFY_ERC20_APPROVAL_ADAPTER";
export const DEPLOY_ERC20_TRANSFER_ADAPTER = "DEPLOY_ERC20_TRANSFER_ADAPTER";
export const VERIFY_ERC20_TRANSFER_ADAPTER = "VERIFY_ERC20_TRANSFER_ADAPTER";
export const DEPLOY_SAMPLE = "DEPLOY_SAMPLE";
export const VERIFY_SAMPLE = "VERIFY_SAMPLE";
export const DEPLOY_TREASURY_CONTRACT = "DEPLOY_TREASURY_CONTRACT";
export const VERIFY_TREASURY_CONTRACT = "VERIFY_TREASURY_CONTRACT";
export const DEPLOY_TOKEN_CONTRACT = "DEPLOY_TOKEN_CONTRACT";
export const VERIFY_DEPLOY_TOKEN_CONTRACT = "VERIFY_DEPLOY_TOKEN_CONTRACT";
export const WHITELIST_TREASURY_CONTRACT = "WHITELIST_TREASURY_CONTRACT";
export const INITIALIZE_TREASURY_CONTRACT = "INITIALIZE_TREASURY_CONTRACT";
export const GET_TREASURY_DETAILS = "GET_TREASURY_DETAILS";
export const MINT_DRYP_WITH_USDT = "MINT_DRYP_WITH_USDT";
export const UPDATE_TREASURY_CONTRACT = "UPDATE_TREASURY_CONTRACT";
export const CALCULATE_REDEMPTION_VALUE = "CALCULATE_REDEMPTION_VALUE";
export const WNATIVE: { [network: string]: { [chainId: string]: string } } = {
  testnet: {
    "11155111": "0xf550605cb56fbba5c0f0e01174cf4e707ce0c9ca",
  },
  mainnet: {
    "1": "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
  },
};

export const CONTRACT_NAME: { [key: string]: string } = {
  Treasury: "Treasury",
  TreasuryProxy: "TreasuryProxy",
  Token: "Dryp",
  TokenProxy: "DrypProxy",
};

export const EXCHANGE_TOKEN: {
  [chainId: string]: {
    [token: string]: {
      address: string;
      megaPool: string;
      decimals: number;
      maxAllowed: number;
      symbol: string;
      priceInUsdt: number;
    };
  };
} = {
  "11155111": {
    usdt: {
      address: "0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0",
      megaPool: "0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0",
      decimals: 6,
      maxAllowed: 100000,
      symbol: "USDT",
      priceInUsdt: 1,
    },
    usdc: {
      address: "0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8",
      megaPool: "0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8",
      decimals: 6,
      maxAllowed: 100000,
      symbol: "USDC",
      priceInUsdt: 1,
    },
  },
};
