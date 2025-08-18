import {
  createContext,
  type ReactNode,
  useContext,
  useEffect,
  useState,
} from "react";
import { api } from "../services/api";
import { auth } from "../services/auth";
import type { User } from "../types";

export interface AuthContext {
  isLoggedIn: boolean;
  currentUser?: User;
  logout(): void;
  completeLogin(user: User, sessionToken: string): void;
}

const AuthContext = createContext<AuthContext>({
  isLoggedIn: false,
  currentUser: undefined,
  logout: () => {},
  completeLogin: (_user: User, _sessionToken: string) => {},
});

export function useAuth() {
  return useContext(AuthContext);
}

type MeRequest = undefined;
type MeResponse = User;

interface Props {
  children: ReactNode;
}

export const AuthProvider = ({ children }: Props) => {
  const [currentUser, setCurrentUser] = useState<User>();
  const [isLoggedIn, setIsLoggedIn] = useState<boolean>(!!auth.sessionToken);

  const value = {
    isLoggedIn,
    currentUser,
    logout: () => {
      auth.sessionToken = null;
      setCurrentUser(undefined);
      setIsLoggedIn(false);
    },
    completeLogin: (user: User, sessionToken: string) => {
      auth.sessionToken = sessionToken;
      setCurrentUser(user);
      setIsLoggedIn(true);
    },
  };

  useEffect(() => {
    if (!isLoggedIn) return;
    if (!auth.sessionToken) {
      setIsLoggedIn(false);
    }

    if (currentUser) return;
    api.get<MeRequest, MeResponse>("/auth/me").then((currentUser) => {
      setCurrentUser(currentUser);
    });
  }, [currentUser, isLoggedIn]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};
