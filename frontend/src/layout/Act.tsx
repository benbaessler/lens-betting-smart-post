import { Button } from "@/components/ui/button";
import {
  Post,
  Comment,
  Quote,
  usePublications,
} from "@lens-protocol/react-web";
import { useState } from "react";
import { encodeAbiParameters, encodeFunctionData, zeroAddress } from "viem";
import { useWalletClient } from "wagmi";
import { useLensSmartPost } from "../context/LensSmartPostContext";
import { publicClient } from "../main";
import { mode, uiConfig } from "../utils/constants";
import { lensHubAbi } from "../utils/lensHubAbi";
import { Publication } from "@lens-protocol/widgets-react";

export type ActionPost = Post | Comment | Quote;

const ActionBox = ({
  post,
  address,
  profileId,
  refresh,
}: {
  post: Post | Comment | Quote;
  address?: `0x${string}`;
  profileId?: number;
  refresh: () => void;
}) => {
  const [createState, setCreateState] = useState<string | undefined>();
  const [txHash, setTxHash] = useState<string | undefined>();
  const { data: walletClient } = useWalletClient();

  const executeSmartPost = async (post: Post | Comment | Quote) => {
    const encodedActionData = encodeAbiParameters([], []);

    const args = {
      publicationActedProfileId: BigInt(parseInt(post.by.id, 16) || 0),
      publicationActedId: BigInt(post.id.split("-")[1]),
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

  const executeCollect = async (post: Post | Comment | Quote) => {
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
      publicationActedProfileId: BigInt(parseInt(post.by.id, 16) || 0),
      publicationActedId: BigInt(post.id),
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
        <h1>{post.txHash}</h1>
        <Publication publicationId={post.id} />
        {profileId && (
          <Button className="mt-3" onClick={() => executeSmartPost(post)}>
            Accept bet
          </Button>
        )}
        {profileId &&
          post.openActionModules
            ?.map((module) => module.contract.address)
            .includes(uiConfig.collectActionContractAddress) && (
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
  const { address, profileId, refresh, loading } = useLensSmartPost();
  //const profileIdString = profileId ? "0x" + profileId.toString(16) : "0x0";
  const { data } = usePublications({
    where: {
      //from: [profileIdString as ProfileId],
      withOpenActions: [{ address: uiConfig.openActionContractAddress }],
    },
  });
  const activePosts = mode === "api" ? [] : data;

  const filteredPosts = (activePosts || []) as ActionPost[];
  // if (filteredPosts) {
  //   console.log(filteredPosts, parseInt(filteredPosts[0].by.id, 16).toString());
  // }

  // let filteredPosts =
  //   filterOwnPosts && data
  //     ? data.filter(
  //         (post) =>
  //           parseInt(post.by.id, 16).toString() === profileId?.toString()
  //       )
  //     : activePosts;

  // filteredPosts = activePosts!.sort((a, b) => Number(a.createdAt) - Number(b.createdAt));

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
