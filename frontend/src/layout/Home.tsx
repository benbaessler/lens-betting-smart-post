import { ConnectKitButton } from "connectkit";
import "../styles/Action.css";
import { useLogin, useProfiles } from "@lens-protocol/react-web";
import { Actions } from "./Act";
import { Events } from "./Events";
import { useLensHelloWorld } from "../context/LensHellowWorldContext";
import { Create } from "./Create";
import { useState } from "react";

export const Home = () => {
  const [activeSection, setActiveSection] = useState<string>("create");
  const { address, handle, clear, disconnect } = useLensHelloWorld();

  const { data: profiles } = useProfiles({
    where: {
      ownedBy: [address as string],
    },
  });
  const { execute: executeLogin } = useLogin();

  const showNoLensProfiles =
    address && !handle && profiles && profiles.length === 0;
  const showSignInWithLens =
    address && !handle && profiles && profiles.length > 0;
  const showConnect = !address || !handle;

  return (
    <div className="container">
      <h1>Lens Hello World Open Action</h1>
      <div className="button-row">
        <button
          className={`button ${activeSection === "create" ? "active" : ""}`}
          onClick={() => setActiveSection("create")}
        >
          Create
        </button>
        <button
          className={`button ${activeSection === "actions" ? "active" : ""}`}
          onClick={() => setActiveSection("actions")}
        >
          Actions
        </button>
        <button
          className={`button ${activeSection === "events" ? "active" : ""}`}
          onClick={() => setActiveSection("events")}
        >
          Events
        </button>
      </div>
      {showConnect && <ConnectKitButton />}
      {showNoLensProfiles && <p>No Lens Profiles found for this address</p>}
      {showSignInWithLens &&
        profiles.map((profile, index) => (
          <button
            key={index}
            className="profile-button"
            onClick={() => executeLogin({ address, profileId: profile.id })}
          >
            Sign in with {profile.handle?.localName}.lens
          </button>
        ))}
      {handle && (
        <>
          <p className="logged-in-text">Logged in as {handle}.lens</p>
          <button
            className="disconnect-button"
            onClick={() => {
              clear();
              disconnect();
            }}
          >
            Disconnect
          </button>
        </>
      )}
      {activeSection === "create" && <Create />}
      {activeSection === "actions" && <Actions />}
      {activeSection === "events" && <Events />}
    </div>
  );
};
