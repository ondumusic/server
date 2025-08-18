class AuthService {
  get sessionToken(): string | null {
    return localStorage.sessionToken;
  }

  set sessionToken(sessionToken: string | null) {
    localStorage.sessionToken = sessionToken;
  }
}

export const auth = new AuthService();
