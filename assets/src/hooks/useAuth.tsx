import {
  createContext,
  type ReactNode,
  useContext,
  useEffect,
  useState,
} from "react";
import { ApiError, api } from "../services/api";
import { auth } from "../services/auth";
import type { User } from "../types";

export interface AuthContext {
  isLoggedIn: boolean;
  currentUser?: User;
  logout(): void;
  completeLogin(user: User, sessionToken: string): void;
}

const AuthContext = createContext<AuthContext>({
  isLoggedIn: !!auth.sessionToken,
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

  const logout = () => {
    auth.sessionToken = null;
    setCurrentUser(undefined);
    setIsLoggedIn(false);
  };

  const maybeLogout = (error: ApiError) => {
    if (error instanceof ApiError && error.response.status === 401) {
      logout();
    }
  };

  const value = {
    isLoggedIn,
    currentUser,
    logout,
    completeLogin: (user: User, sessionToken: string) => {
      auth.sessionToken = sessionToken;
      setCurrentUser(user);
      setIsLoggedIn(true);
    },
  };

  // biome-ignore lint/correctness/useExhaustiveDependencies(maybeLogout): suppress dependency maybeLogout
  // biome-ignore lint/correctness/useExhaustiveDependencies(currentUser): suppress dependency currentUser
  // biome-ignore lint/correctness/useExhaustiveDependencies(isLoggedIn): suppress dependency isLoggedIn
  useEffect(() => {
    if (!isLoggedIn) return;
    if (!auth.sessionToken) {
      setIsLoggedIn(false);
    }

    if (currentUser) return;
    api
      .get<MeRequest, MeResponse>("/auth/me")
      .then(setCurrentUser)
      .catch(maybeLogout);
  }, []);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};
