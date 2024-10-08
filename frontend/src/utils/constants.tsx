export const network: string = "mumbai"; // options: 'polygon', 'mumbai'

// mode flag sets whether to fetch smart post instances from Lens API or querying directly from contract events
// Mumbai open actions are always indexed on the Lens API, Polygon actions need to be allowlisted on the API (though they are permisionless on-chain)
// To request allowlist for Polygon actions, you can submit a PR to https://github.com/lens-protocol/open-actions-directory
export const mode: string = "events"; // options: 'api', 'events'
export const ipfsGateway = "https://ipfs.io/ipfs/";
export const arweaveGateway = "https://arweave.net/";

interface UiConfig {
  openActionContractAddress: `0x${string}`;
  openActionContractStartBlock: number;
  lensHubProxyAddress: `0x${string}`;
  collectActionContractAddress: `0x${string}`;
  simpleCollectModuleContractAddress: `0x${string}`;
  blockExplorerLink: string;
  rpc: string;
}

export const uiConfig: UiConfig =
  network === "polygon"
    ? {
        openActionContractAddress: "0xc8e3fc432ef2ed91981fc598e34ad7f4fa880049",
        openActionContractStartBlock: 50547287,
        lensHubProxyAddress: "0xDb46d1Dc155634FbC732f92E853b10B288AD5a1d",
        collectActionContractAddress:
          "0x0D90C58cBe787CD70B5Effe94Ce58185D72143fB",
        simpleCollectModuleContractAddress:
          "0x060f5448ae8aCF0Bc06D040400c6A89F45b488bb",
        blockExplorerLink: "https://polygonscan.com/tx/",
        rpc: `https://polygon-mainnet.g.alchemy.com/v2/${
          import.meta.env.VITE_ALCHEMY_POLYGON_API_KEY
        }`,
      }
    : {
        openActionContractAddress: "0x03fa0DCFDCFff5faC6303B7D8570905EE3195c15",
        openActionContractStartBlock: 43215182,
        lensHubProxyAddress: "0x4fbffF20302F3326B20052ab9C217C44F6480900",
        collectActionContractAddress:
          "0x4FdAae7fC16Ef41eAE8d8f6578d575C9d64722f2",
        simpleCollectModuleContractAddress:
          "0x345Cc3A3F9127DE2C69819C2E07bB748dE6E45ee",
        blockExplorerLink: "https://mumbai.polygonscan.com/tx/",
        rpc: `https://polygon-mumbai.g.alchemy.com/v2/${
          import.meta.env.VITE_ALCHEMY_MUMBAI_API_KEY
        }`,
      };
