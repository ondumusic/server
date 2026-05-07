import type { User } from "../types";
import { client, type RequestOptions } from "./client";

type LoginResult =
  | {
      ok: false;
      fields: {
        [key: string]: {
          message: string;
        };
      };
    }
  | {
      ok: true;
      currentUser: User;
      sessionToken: string;
    };

type SignupResult =
  | {
      ok: false;
      fields: {
        [key: string]: {
          message: string;
        };
      };
    }
  | {
      ok: true;
      currentUser: User;
      sessionToken: string;
    };

type PlayTokenResult =
  | {
      ok: false;
    }
  | {
      ok: true;
      playToken: string;
    };

type LogoutResponse = {
  ok: true;
};

export const authApi = {
  login(username?: string, password?: string, opts?: RequestOptions) {
    return client.post<
      {
        username?: string;
        password?: string;
      },
      LoginResult
    >(
      "/auth/login",
      {
        username,
        password,
      },
      opts,
    );
  },

  signup(
    username?: string,
    password?: string,
    passwordConfirmation?: string,
    opts?: RequestOptions,
  ) {
    return client.post<
      {
        username?: string;
        password?: string;
        passwordConfirmation?: string;
      },
      SignupResult
    >(
      "/auth/signup",
      {
        username,
        password,
        passwordConfirmation,
      },
      opts,
    );
  },

  getCurrentUser(opts?: RequestOptions) {
    return client.get<undefined, User>(`/auth/me`, opts);
  },

  logout(opts?: RequestOptions) {
    return client.delete<undefined, LogoutResponse>(`/auth/session`, opts);
  },

  getPlayToken(opts?: RequestOptions) {
    return client.get<undefined, PlayTokenResult>(`/auth/playtoken`, opts);
  },
};
