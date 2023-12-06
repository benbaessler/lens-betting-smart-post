// import { useState } from "react";
import { useLensSmartPost } from "../context/LensSmartPostContext";
import { uiConfig } from "../utils/constants";

export const Events = () => {
  const { betsCreated, loading } = useLensSmartPost();

  const parsedEvents = betsCreated.sort((a, b) => {
    const blockNumberA = parseInt(a.blockNumber, 10);
    const blockNumberB = parseInt(b.blockNumber, 10);
    return blockNumberB - blockNumberA;
  });

  return (
    <>
      {/* {address && (
        <div className="my-3">
          <input
            type="checkbox"
            className="mr-3"
            id="filterCheckbox"
            checked={filterOwnEvents}
            onChange={(e) => setFilterOwnEvents(e.target.checked)}
          />
          <label htmlFor="filterCheckbox">
            Filter only events from my address
          </label>
        </div>
      )} */}
      {loading && <div className="spinner" />}
      {parsedEvents.map((event, index) => (
        <div key={index} className="border p-3 rounded-xl mt-3 w-[500px]">
          <div className="inline-content">from</div>
          <div className="inline-content">{event.args.profileId}</div>
          <div className="header-text inline-content">
            <a href={`${uiConfig.blockExplorerLink}${event.transactionHash}`}>
              Link
            </a>
          </div>
        </div>
      ))}
    </>
  );
};
