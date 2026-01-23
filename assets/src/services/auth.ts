import type { User } from "../types";

class AuthService {
  #tokenName = "sessionToken";
  #currentUser?: User = undefined;

  get sessionToken(): string | null {
    return localStorage.getItem(this.#tokenName);
  }

  set sessionToken(sessionToken: string | null) {
    if (sessionToken === null) {
      localStorage.removeItem(this.#tokenName);
    } else {
      localStorage.setItem(this.#tokenName, sessionToken);
    }
  }

  get isLoggedIn(): boolean {
    return !!(this.sessionToken && this.currentUser);
  }

  get currentUser(): User | undefined {
    return this.#currentUser;
  }

  set currentUser(currentUser: User | undefined) {
    this.#currentUser = currentUser;
  }

  logout() {
    this.#currentUser = undefined;
    this.sessionToken = null;
  }
}

export const auth = new AuthService();
