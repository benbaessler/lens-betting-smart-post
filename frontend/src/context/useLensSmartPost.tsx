import { ReactNode, FC, useState, useEffect, useCallback } from "react";
import { useAccount } from "wagmi";
import LensSmartPostContext from "./LensSmartPostContext";
import {
  PostCreatedEvent,
  PostCreatedEventFormatted,
  convertPostEventToSerializable,
  convertBetCreatedEventToSerializable,
  LoginData,
  BetCreatedEvent,
  BetCreatedEventFormatted,
} from "../utils/types";
import { network, uiConfig } from "../utils/constants";
import { publicClient } from "../main";
import { lensHubEventsAbi } from "../utils/lensHubEventsAbi";
import { smartPostAbi } from "../utils/smartPostAbi";
import { disconnect } from "wagmi/actions";

interface LensSmartPostProviderProps {
  children: ReactNode;
}

export const LensSmartPostProvider: FC<LensSmartPostProviderProps> = ({
  children,
}) => {
  const [betsCreated, setBetsCreated] = useState<BetCreatedEventFormatted[]>(
    []
  );
  const [handle, setHandle] = useState<string | undefined>();
  const [profileId, setProfileId] = useState<number | undefined>();
  const { address } = useAccount();
  const [posts, setPosts] = useState<PostCreatedEventFormatted[]>([]);
  const [loading, setLoading] = useState(false);
  const [loginData, setLoginData] = useState<LoginData>();

  const connect = (loginDataParam: LoginData) => {
    setLoginData(loginDataParam);
  };

  const chainId = network === "polygon" ? 137 : 80001;

  const refresh = useCallback(async () => {
    setLoading(true);

    const savedCurrentBlock = localStorage.getItem("currentBlock");
    const savedPostEvents: PostCreatedEventFormatted[] = JSON.parse(
      localStorage.getItem("postEvents") || "[]"
    );
    const savedBetCreatedEvents: BetCreatedEventFormatted[] = JSON.parse(
      localStorage.getItem("betCreatedEvents") || "[]"
    );

    if (savedPostEvents.length) {
      setPosts(savedPostEvents);
    }

    if (savedBetCreatedEvents) {
      setBetsCreated(savedBetCreatedEvents);
    }

    const startBlock = savedCurrentBlock
      ? parseInt(savedCurrentBlock)
      : uiConfig.openActionContractStartBlock;

    const currentBlock = await publicClient({
      chainId,
    }).getBlockNumber();

    console.log(currentBlock);

    const postEventsMap = new Map(
      savedPostEvents.map((event) => [event.transactionHash, event])
    );

    const betCreatedEventsMap = new Map(
      savedBetCreatedEvents.map((event) => [event.transactionHash, event])
    );

    for (let i = startBlock; i < currentBlock; i += 2000) {
      const toBlock = i + 1999 > currentBlock ? currentBlock : i + 1999;

      const postEvents = await publicClient({
        chainId: network === "polygon" ? 137 : 80001,
      }).getContractEvents({
        address: uiConfig.lensHubProxyAddress,
        abi: lensHubEventsAbi,
        eventName: "PostCreated",
        fromBlock: BigInt(i),
        toBlock: BigInt(toBlock),
      });

      const betCreatedEvents = await publicClient({
        chainId,
      }).getContractEvents({
        address: uiConfig.openActionContractAddress,
        abi: smartPostAbi,
        eventName: "BetCreated",
        fromBlock: BigInt(i),
        toBlock: BigInt(toBlock),
      });

      const postEventsParsed = postEvents as unknown as PostCreatedEvent[];
      const betCreatedEventsParsed =
        betCreatedEvents as unknown as BetCreatedEvent[];

      const filteredEvents = postEventsParsed.filter((event) => {
        return event.args.postParams.actionModules.includes(
          uiConfig.openActionContractAddress
        );
      });

      const serializablePostEvents = filteredEvents.map((event) =>
        convertPostEventToSerializable(event)
      );

      const serializableBetCreatedEvents = betCreatedEventsParsed.map((event) =>
        convertBetCreatedEventToSerializable(event)
      );

      serializablePostEvents.forEach((event) =>
        postEventsMap.set(event.transactionHash, event)
      );
      serializableBetCreatedEvents.forEach((event) =>
        betCreatedEventsMap.set(event.transactionHash, event)
      );
    }

    const allPostEvents = Array.from(postEventsMap.values());
    const allBetCreatedEvents = Array.from(betCreatedEventsMap.values());

    localStorage.setItem("currentBlock", currentBlock.toString());
    localStorage.setItem("postEvents", JSON.stringify(allPostEvents));
    localStorage.setItem("betCreatedEvents", JSON.stringify(allBetCreatedEvents));

    setPosts(allPostEvents);
    setBetsCreated(allBetCreatedEvents);
    setLoading(false);
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  useEffect(() => {
    if (loginData) {
      setHandle(loginData!.handle!.localName);
      setProfileId(parseInt(loginData!.id, 16));

      localStorage.setItem("handle", loginData!.handle!.localName);
      localStorage.setItem("profileId", loginData!.id);
      localStorage.setItem("address", loginData.ownedBy.address);
    }
  }, [loginData]);

  // Set handle and profile
  useEffect(() => {
    const storedHandle = localStorage.getItem("handle");
    const storedProfileId = localStorage.getItem("profileId");
    const storedAddress = localStorage.getItem("address");

    if (storedHandle && address === storedAddress) {
      setHandle(storedHandle);
    } else {
      setHandle(undefined);
    }

    if (storedProfileId && address === storedAddress) {
      setProfileId(parseInt(storedProfileId, 16));
    } else {
      setProfileId(undefined);
    }
  }, [address]);

  return (
    <LensSmartPostContext.Provider
      value={{
        profileId,
        handle,
        betsCreated,
        address,
        posts,
        refresh,
        clear: () => {
          setProfileId(undefined);
          setHandle(undefined);
        },
        disconnect: () => {
          disconnect();
          localStorage.removeItem("handle");
          localStorage.removeItem("profileId");
          localStorage.removeItem("address");
        },
        loading,
        connect,
      }}
    >
      {children}
    </LensSmartPostContext.Provider>
  );
};
