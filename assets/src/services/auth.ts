class AuthService {
  #tokenName = "sessionToken";

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
}

export const auth = new AuthService();
