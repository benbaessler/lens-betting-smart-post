// LensHelloWorldContext.tsx
import React, { useContext } from "react";
import { BetCreatedEventFormatted, LoginData, PostCreatedEventFormatted } from "../utils/types";

interface LensSmartPostContextState {
  profileId?: number;
  handle?: string;
  address?: `0x${string}`;
  posts: PostCreatedEventFormatted[];
  betsCreated: BetCreatedEventFormatted[];
  refresh: () => void;
  clear: () => void;
  loading: boolean;
  disconnect: () => void;
  connect: (loginData: LoginData) => void;
}

const LensSmartPostContext = React.createContext<LensSmartPostContextState>({
  clear: () => {},
  posts: [],
  betsCreated: [],
  refresh: () => {},
  loading: false,
  disconnect: () => {},
  connect: () => {},
});

export const useLensSmartPost = (): LensSmartPostContextState => {
  return useContext(LensSmartPostContext);
};

export default LensSmartPostContext;
