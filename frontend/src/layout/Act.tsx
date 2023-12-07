import { Button } from "@/components/ui/button";
import {
  PublicationId,
  usePublication,
  useProfile,
  ProfileId,
} from "@lens-protocol/react-web";
import { useState } from "react";
import {
  encodeAbiParameters,
  encodeFunctionData,
  zeroAddress,
  formatUnits,
} from "viem";
import { useWalletClient, useContractRead } from "wagmi";
import { useLensSmartPost } from "../context/LensSmartPostContext";
import { publicClient } from "../main";
import { mode, uiConfig } from "../utils/constants";
import { lensHubAbi } from "../utils/lensHubAbi";
import { PostCreatedEventFormatted } from "../utils/types";
import { numberToHex } from "@/lib/utils";
import { smartPostAbi } from "@/utils/smartPostAbi";

const ActionBox = ({
  post,
  address,
  profileId,
  refresh,
}: {
  post: PostCreatedEventFormatted;
  address?: `0x${string}`;
  profileId?: number;
  refresh: () => void;
}) => {
  const [createState, setCreateState] = useState<string | undefined>();
  const [txHash, setTxHash] = useState<string | undefined>();

  const bet = useContractRead({
    address: uiConfig.openActionContractAddress,
    abi: smartPostAbi,
    functionName: "bets",
    args: [post.args.postParams.profileId, post.args.pubId],
  }).data;

  const { data: publication } = usePublication({
    forId: `${numberToHex(
      parseInt(post.args.postParams.profileId)
    )}-${numberToHex(parseInt(post.args.pubId))}` as PublicationId,
  });

  const { data: userProfile } = useProfile({
    forProfileId: numberToHex(bet![1]) as ProfileId,
  });
  const { data: judgeProfile } = useProfile({
    forProfileId: numberToHex(bet![2]) as ProfileId,
  });

  const { data: walletClient } = useWalletClient();

  const executeSmartPost = async (post: PostCreatedEventFormatted) => {
    const encodedActionData = encodeAbiParameters([], []);

    const args = {
      publicationActedProfileId: BigInt(post.args.postParams.profileId || 0),
      publicationActedId: BigInt(post.args.pubId),
      actorProfileId: BigInt(profileId || 0),
      referrerProfileIds: [],
      referrerPubIds: [],
      actionModuleAddress: uiConfig.openActionContractAddress,
      actionModuleData: encodedActionData as `0x${string}`,
    };

    const calldata = encodeFunctionData({
      abi: lensHubAbi,
      functionName: "act",
      args: [args],
    });

    setCreateState("PENDING IN WALLET");
    try {
      const hash = await walletClient!.sendTransaction({
        to: uiConfig.lensHubProxyAddress,
        account: address,
        data: calldata as `0x${string}`,
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

  const executeCollect = async (post: PostCreatedEventFormatted) => {
    const baseFeeCollectModuleTypes = [
      { type: "address" },
      { type: "uint256" },
    ];

    const encodedBaseFeeCollectModuleInitData = encodeAbiParameters(
      baseFeeCollectModuleTypes,
      [zeroAddress, 0]
    );

    const encodedCollectActionData = encodeAbiParameters(
      [{ type: "address" }, { type: "bytes" }],
      [address!, encodedBaseFeeCollectModuleInitData]
    );

    const args = {
      publicationActedProfileId: BigInt(post.args.postParams.profileId || 0),
      publicationActedId: BigInt(post.args.pubId),
      actorProfileId: BigInt(profileId || 0),
      referrerProfileIds: [],
      referrerPubIds: [],
      actionModuleAddress: uiConfig.collectActionContractAddress,
      actionModuleData: encodedCollectActionData as `0x${string}`,
    };

    const calldata = encodeFunctionData({
      abi: lensHubAbi,
      functionName: "act",
      args: [args],
    });

    setCreateState("PENDING IN WALLET");
    try {
      const hash = await walletClient!.sendTransaction({
        to: uiConfig.lensHubProxyAddress,
        account: address,
        data: calldata as `0x${string}`,
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
      <div className="flex flex-col border rounded-xl px-5 py-3 mb-3 justify-center">
        <span>By: {publication?.by.handle?.fullHandle}</span>
        <span>To: {userProfile?.handle?.fullHandle}</span>
        <span>To: {judgeProfile?.handle?.fullHandle}</span>
        <span>Amount: {formatUnits(bet![4], 18).toString()} WMATIC</span>
        <span>Judge: </span>
        {profileId && (
          <Button className="mt-3" onClick={() => executeSmartPost(post)}>
            Accept bet
          </Button>
        )}
        {profileId &&
          post.args.postParams.actionModules.includes(
            uiConfig.collectActionContractAddress
          ) && (
            <Button className="mt-3" onClick={() => executeCollect(post)}>
              Collect Post
            </Button>
          )}
        {createState && (
          <p className="mt-2 text-primary create-state-text">{createState}</p>
        )}
        {txHash && (
          <a
            href={`${uiConfig.blockExplorerLink}${txHash}`}
            target="_blank"
            className="block-explorer-link"
          >
            Block Explorer Link
          </a>
        )}
      </div>
    </>
  );
};

export const Actions = () => {
  const [filterOwnPosts, setFilterOwnPosts] = useState(false);
  const { address, profileId, refresh, loading, posts } = useLensSmartPost();
  const activePosts = mode === "api" ? [] : posts;

  let filteredPosts = filterOwnPosts
    ? activePosts.filter(
        (post) => post.args.postParams.profileId === profileId?.toString()
      )
    : activePosts;

  filteredPosts = filteredPosts.sort((a, b) => {
    const blockNumberA = parseInt(a.blockNumber, 10);
    const blockNumberB = parseInt(b.blockNumber, 10);
    return blockNumberB - blockNumberA;
  });

  return (
    <>
      {address && profileId && (
        <div className="my-3">
          <input
            type="checkbox"
            id="filterCheckbox"
            className="mr-3"
            checked={filterOwnPosts}
            onChange={(e) => setFilterOwnPosts(e.target.checked)}
          />
          <label htmlFor="filterCheckbox">
            Filter only posts from my profile
          </label>
        </div>
      )}
      {loading && <div className="spinner" />}
      {filteredPosts.length === 0 ? (
        <p>None</p>
      ) : (
        filteredPosts.map((post, index) => (
          <ActionBox
            key={index}
            post={post}
            address={address}
            profileId={profileId}
            refresh={refresh}
          />
        ))
      )}
    </>
  );
};
