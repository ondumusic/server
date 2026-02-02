export class ClientError extends Error {
  response?: Response;
  aborted?: boolean;

  constructor(params: {
    message: string;
    response?: Response;
    aborted?: boolean;
  }) {
    super(params.message);
    this.name = "ClientError";
    this.response = params.response;
    this.aborted = params.aborted;
    Object.setPrototypeOf(this, ClientError.prototype);
  }
}
