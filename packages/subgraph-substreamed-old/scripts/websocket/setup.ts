import WS from "ws";

import { InnerSocket, InnerSocketCallbacks, ReadyState } from "./types";

export function setupWS(
  uri: string,
  callbacks: InnerSocketCallbacks,
  protocols?: string | string[]
): InnerSocket {
  const ws = new WS(uri, protocols, {
    headers: {
      "User-Agent": "NodeJS-WS-agent"
    }
  });

  ws.on("open", () => {
    callbacks.onOpen();
  });
  ws.on("message", (data: WS.Data) => {
    // eslint-disable-next-line @typescript-eslint/no-base-to-string
    callbacks.onMessage(data.toString());
  });
  ws.on("error", error => {
    callbacks.onError(error);
  });
  ws.on("close", (_event, reason) => {
    callbacks.onClose(new Error(`${_event}: ${reason.toString()}`));
  });

  return {
    get readyState(): ReadyState {
      switch (ws.readyState) {
        case WS.CONNECTING:
          return ReadyState.CONNECTING;
        case WS.OPEN:
          return ReadyState.OPEN;
        case WS.CLOSING:
          return ReadyState.CLOSING;
        case WS.CLOSED:
        default:
          return ReadyState.CLOSED;
      }
    },

    disconnect(): void {
      if (
        ws == null ||
        ws.readyState === WS.CLOSING ||
        ws.readyState === WS.CLOSED
      )
        return;
      ws.removeAllListeners();
      ws.close();
    },

    send(data: string): void {
      ws.send(data);
    }
  };
}
