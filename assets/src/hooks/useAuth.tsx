import {
  createContext,
  type PropsWithChildren,
  useContext,
  useEffect,
  useState,
} from "react";
import { authApi, ClientError } from "../api";
import { Loading } from "../components/Loading";
import { repo } from "../library";
import { auth } from "../services/auth";
import type { User } from "../types";

interface AuthState {
  isLoggedIn: boolean;
  currentUser?: User;
}

export type AuthContext = AuthState & {
  logout(): void;
  completeLogin(user: User, sessionToken: string): void;
};

const AuthContext = createContext<AuthContext>({
  isLoggedIn: !!auth.sessionToken,
  currentUser: undefined,
  logout: () => {},
  completeLogin: (_user: User, _sessionToken: string) => {},
});

export function useAuth() {
  return useContext(AuthContext);
}

export const AuthProvider = ({ children }: PropsWithChildren) => {
  const [isFetching, setIsFetching] = useState<boolean>(true);
  const [state, setState] = useState<AuthState>({
    isLoggedIn: !!auth.sessionToken,
    currentUser: undefined,
  });

  const updateState = () => {
    setIsFetching(false);
    setState({
      isLoggedIn: auth.isLoggedIn,
      currentUser: auth.currentUser,
    });
  };

  const logout = async () => {
    authApi.logout();
    auth.logout();
    await repo.teardown();
    localStorage.clear();
    updateState();
  };

  const value = {
    ...state,
    logout,
    completeLogin: (user: User, sessionToken: string) => {
      auth.sessionToken = sessionToken;
      auth.currentUser = user;
      updateState();
    },
  };

  // This useEffect should only render once on mount so we can ignore the dependencies.
  // biome-ignore lint/correctness/useExhaustiveDependencies(updateState): suppress dependency updateState
  // biome-ignore lint/correctness/useExhaustiveDependencies(logout): suppress dependency logout
  useEffect(() => {
    // Without a session token we cannot do anything else here.
    if (!auth.sessionToken) {
      logout();
      return;
    }

    // Get user details from the API
    authApi
      .getCurrentUser()
      .then((user) => {
        auth.currentUser = user;
        updateState();
      })
      .catch((error: ClientError) => {
        const abortedError = error instanceof ClientError && error.aborted;
        const unauthorizedError =
          error instanceof ClientError && error.response?.status === 401;

        if (unauthorizedError && !abortedError) {
          logout();
        } else {
          setIsFetching(false);
        }
      });
  }, []);

  if (isFetching) {
    return <Loading />;
  }

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};
