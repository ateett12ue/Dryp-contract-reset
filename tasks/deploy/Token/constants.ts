export const TREASURY_TOKENS: {
  [chainId: string]: {
    [token: string]: {
      address: string;
      decimals: number;
      allocatedPercentage: number;
      price: number;
    };
  };
} = {
  "11155111": {
    aave: {
      address: "0x88541670E55cC00bEEFD87eB59EDd1b7C511AC9a",
      decimals: 18,
      allocatedPercentage: 0.25,
      price: 100,
    },
    wbtc: {
      address: "0x29f2D40B0605204364af54EC677bD022dA425d03",
      decimals: 8,
      allocatedPercentage: 0.25,
      price: 60000,
    },
    link: {
      address: "0xf8Fb3713D459D7C1018BD0A49D19b4C44290EBE5",
      decimals: 18,
      allocatedPercentage: 0.25,
      price: 10,
    },
    dai: {
      address: "0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357",
      decimals: 18,
      allocatedPercentage: 0.25,
      price: 1,
    },
  },
};
