import { Logger } from "../utils/logger";
import { makeSocket, Socket, WsTask } from "../websocket/Socket";
import { SocketEmitter, SocketEvent } from "../websocket/SocketEmitter";

interface IConfig {
  emitter?: SocketEmitter;
  logger?: Logger;
}
export const create = async (
  url: string,
  config?: IConfig
): Promise<Socket> => {
  const emitter = config?.emitter ?? new SocketEmitter();
  const socket = makeSocket(url, {
    emitter,
    healthCheck: async (): Promise<void> => {
      await socket
        .send({ type: "ping" })
        .catch(() => config?.logger?.log("health check failed"));
    },
    onQueueSpaceCB(
      uri: string
    ): Promise<WsTask<unknown> | boolean | undefined> {
      return Promise.resolve(undefined);
    },
    protocols: ["graphql-transport-ws"],
    logger: config?.logger
  });
  await socket.connect();

  const sendConnectionInit = async (): Promise<void> => {
    await socket.send({ type: "connection_init" });
  };

  emitter.on(SocketEvent.CONNECTION_CLOSE, () => {
    config?.logger?.log("connection closed, reconnecting...");
    void socket.connect().then(() => {
      config?.logger?.log("reconnected");
      void sendConnectionInit();
    });
  });

  await sendConnectionInit();

  return socket;
};