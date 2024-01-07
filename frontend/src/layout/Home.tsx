import "../styles/Action.css";
import { useLogin, useProfile, useProfiles } from "@lens-protocol/react-web";
import { Actions } from "./Act";
import { useLensSmartPost } from "../context/LensSmartPostContext";
import { Create } from "./Create";
import { useEffect, useState } from "react";
import { LoginData } from "../utils/types";
import { Button } from "@/components/ui/button";
import { useWeb3Modal } from "@web3modal/wagmi/react";
import { PenLine, Rows, LogIn, Unplug } from "lucide-react";
import { network } from "@/utils/constants";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";

export const Home = () => {
  const [activeSection, setActiveSection] = useState<string>("create");
  const { address, handle, connect, disconnect } = useLensSmartPost();
  const { open } = useWeb3Modal();
  const { execute: executeLogin, data: loginData } = useLogin();
  const [connected, setConnected] = useState(false);

  useEffect(() => {
    setConnected(true);
  }, []);

  useEffect(() => {
    if (loginData) {
      connect(loginData as LoginData);
    }
  }, [connect, loginData]);

  async function logIn({ address, profileId }) {
    try {
      await executeLogin({ address, profileId });
      if (!loginData) return;
      connect({ ...loginData } as LoginData);
    } catch (err) {
      console.log("err: ", err);
    }
  }

  if (!connected) return null;
  return (
    <Profiles
      address={address}
      activeSection={activeSection}
      setActiveSection={setActiveSection}
      handle={handle}
      executeLogin={logIn}
      open={open}
      disconnect={disconnect}
    />
  );
};

function Profiles({
  address,
  activeSection,
  setActiveSection,
  handle,
  executeLogin,
  open,
  disconnect,
}) {
  const { data: profiles } = useProfiles({
    where: {
      ownedBy: [address || ""],
    },
  });

  const { data: profile } = useProfile({
    forHandle: handle,
  });

  const showNoLensProfiles =
    address && !handle && profiles && profiles.length === 0;
  const showSignInWithLens =
    address && !handle && profiles && profiles.length > 0;

  return (
    <div className="flex flex-1 justify-center items-center flex-col">
      <Button variant="outline">
        <Avatar className="mr-2 h-5 w-5">
          <AvatarImage
            src={profile?.metadata?.coverPicture?.optimized?.uri || "none"}
          />
          <AvatarFallback>{profile?.handle?.fullHandle}</AvatarFallback>
        </Avatar>
        {profile?.handle?.fullHandle}
      </Button>

      <div className="mt-20">
        <h1 className="text-5xl font-geist-black">Betting Smart Post</h1>
      </div>
      <div className="mt-6 mb-6">
        <Button
          variant={activeSection === "create" ? "default" : "secondary"}
          onClick={() => setActiveSection("create")}
          className="px-10 mx-2"
        >
          <PenLine className="mr-2 h-4 w-4" />
          Create Smart Post
        </Button>
        <Button
          variant={activeSection === "actions" ? "default" : "secondary"}
          onClick={() => setActiveSection("actions")}
          className="px-10 mx-2"
        >
          <Rows className="mr-2 h-4 w-4" />
          View Smart Posts
        </Button>
        {/* <Button
          variant={activeSection === "events" ? "default" : "secondary"}
          onClick={() => setActiveSection("events")}
          className="px-10 mx-2"
        >
          <Activity className="mr-2 h-4 w-4" />
          Events
        </Button> */}
      </div>
      <Button
        variant="outline"
        className="my-4"
        onClick={() => {
          if (address) disconnect();
          else open();
        }}
      >
        <Unplug className="mr-2 h-4 w-4" />
        {address ? "Disconnect" : "Connect Wallet"}
      </Button>
      {showNoLensProfiles && <p>No Lens Profiles found for this address</p>}
      {showNoLensProfiles && network === "mumbai" && (
        <p>
          Create test profile @{" "}
          <a href="https://testnet.hey.xyz/" target="_blank">
            https://testnet.hey.xyz/
          </a>
        </p>
      )}
      {showSignInWithLens && (
        <>
          {profiles?.map((profile) => 
            <Button
              variant="outline"
              className="my-4"
              onClick={() => executeLogin({ address, profileId: profile.id })}
            >
              <LogIn className="mr-2 h-4 w-4" />
              Sign in with {profile.handle?.fullHandle}
            </Button>
          )}
        </>
        
      )}
      {activeSection === "create" && <Create />}
      {activeSection === "actions" && <Actions />}
      {/* {activeSection === "events" && <Events />} */}
    </div>
  );
}
