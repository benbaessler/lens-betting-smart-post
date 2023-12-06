import { useState } from "react";
import { useLensSmartPost } from "../context/LensSmartPostContext";
import {
  encodeAbiParameters,
  encodeFunctionData,
  zeroAddress,
  parseEther,
} from "viem";
import { uiConfig } from "../utils/constants";
import { lensHubAbi } from "../utils/lensHubAbi";
import { useWalletClient } from "wagmi";
import { publicClient } from "../main";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";

export const Create = () => {
  const { address, profileId, refresh } = useLensSmartPost();
  const { data: walletClient } = useWalletClient();
  const [createState, setCreateState] = useState<string | undefined>();
  const [freeCollect, setFreeCollect] = useState<boolean>(false);
  const [txHash, setTxHash] = useState<string | undefined>();

  const [uri, setURI] = useState<string>("");
  const [challengedProfileId, setChallengedProfileId] = useState<string>("");
  const [jurorProfileId, setJurorProfileId] = useState<string>("");
  const [amount, setAmount] = useState<string>("");
  const [deadline, setDeadline] = useState<string>("");

  const createPost = async () => {
    console.log(parseEther(amount));

    // request token allowance from user for BigInt(amount) of WMATIC
    // this is needed because the open action contract will transfer the amount from the user

    const encodedInitData = encodeAbiParameters(
      [
        { type: "uint256" },
        { type: "uint256" },
        { type: "address" },
        { type: "uint256" },
        { type: "uint256" },
      ],
      [
        BigInt(challengedProfileId),
        BigInt(jurorProfileId),
        // WMATIC on Mumbai
        "0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889",
        BigInt(parseEther(amount)),
        BigInt(deadline),
      ]
    );

    const actionModulesInitDatas = [encodedInitData];
    const actionModules = [uiConfig.openActionContractAddress];
    if (freeCollect) {
      const baseFeeCollectModuleTypes = [
        { type: "uint160" },
        { type: "uint96" },
        { type: "address" },
        { type: "uint16" },
        { type: "bool" },
        { type: "uint72" },
        { type: "address" },
      ];

      const encodedBaseFeeCollectModuleInitData = encodeAbiParameters(
        baseFeeCollectModuleTypes,
        [0, 0, zeroAddress, 0, false, 0, zeroAddress]
      );

      const encodedCollectActionInitData = encodeAbiParameters(
        [{ type: "address" }, { type: "bytes" }],
        [
          uiConfig.simpleCollectModuleContractAddress,
          encodedBaseFeeCollectModuleInitData,
        ]
      );
      actionModulesInitDatas.push(encodedCollectActionInitData);
      actionModules.push(uiConfig.collectActionContractAddress);
    }

    // Post parameters
    const args = {
      profileId: BigInt(profileId!),
      contentURI: uri,
      actionModules,
      actionModulesInitDatas,
      referenceModule:
        "0x0000000000000000000000000000000000000000" as `0x${string}`,
      referenceModuleInitData: "0x01" as `0x${string}`,
    };

    const calldata = encodeFunctionData({
      abi: lensHubAbi,
      functionName: "post",
      args: [args],
    });

    setCreateState("PENDING IN WALLET");
    try {
      const hash = await walletClient!.sendTransaction({
        to: uiConfig.lensHubProxyAddress,
        account: address,
        data: calldata,
      });
      setCreateState("PENDING IN MEMPOOL");
      setTxHash(hash);
      const result = await publicClient({
        chainId: 80001,
      }).waitForTransactionReceipt({ hash });
      if (result.status === "success") {
        setCreateState("SUCCESS");
        refresh();
      } else {
        setCreateState("CREATE TXN REVERTED");
      }
    } catch (e) {
      setCreateState(`ERROR: ${e instanceof Error ? e.message : String(e)}`);
    }
  };

  return (
    <>
      <div className="pb-4">
        {address && profileId && (
          <div className="flex flex-1 flex-col">
            <div className="flex flex-1 flex-col">
              <p className="my-2">Content URI (link to content for the post)</p>
              <Input
                type="text"
                value={uri}
                placeholder="URI"
                onChange={(e) => setURI(e.target.value)}
              />
              <p className="my-2">Challenged user</p>
              <Input
                placeholder="lens/user"
                type="number"
                value={challengedProfileId}
                onChange={(e) => setChallengedProfileId(e.target.value)}
              />
              <p className="my-2">Judge (will decide the outcome of the bet)</p>
              <Input
                placeholder="lens/judge"
                type="number"
                value={jurorProfileId}
                onChange={(e) => setJurorProfileId(e.target.value)}
              />
              <p className="my-2">Bet amount</p>
              <Input
                placeholder="Amount"
                type="number"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
              />
              <p className="my-2">Deadline (Unix timestamp)</p>
              <Input
                placeholder="Timestamp"
                type="number"
                value={deadline}
                onChange={(e) => setDeadline(e.target.value)}
              />
              <div className="my-3 mx-auto">
                <input
                  type="checkbox"
                  id="filterCheckbox"
                  className="mr-3 cursor-pointer"
                  checked={freeCollect}
                  onChange={(e) => setFreeCollect(e.target.checked)}
                />
                <label htmlFor="filterCheckbox">Enable free collects</label>
              </div>
              <Button className="mt-3" onClick={createPost}>
                Create
              </Button>
            </div>
            {createState && <p className="create-state-text">{createState}</p>}
            {txHash && (
              <a
                href={`${uiConfig.blockExplorerLink}${txHash}`}
                className="block-explorer-link"
                target="_blank"
              >
                Block Explorer Link
              </a>
            )}
            <Button
              variant={"outline"}
              className="my-3"
              onClick={() => {
                setTxHash(undefined);
                setChallengedProfileId("");
                setJurorProfileId("");
                setAmount("");
                setDeadline("");
                setURI("");
                setCreateState(undefined);
              }}
            >
              Clear
            </Button>
          </div>
        )}
      </div>
    </>
  );
};
