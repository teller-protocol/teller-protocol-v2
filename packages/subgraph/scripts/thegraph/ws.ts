import { makeSocket, Socket, WsTask } from "../websocket/Socket";
import { SocketEmitter } from "../websocket/SocketEmitter";

export const create = async (url: string, name?: string): Promise<Socket> => {
  const emitter = new SocketEmitter();
  const socket = makeSocket(url, {
    emitter,
    healthCheck(): Promise<void> {
      return Promise.resolve(undefined);
    },
    onQueueSpaceCB(
      uri: string
    ): Promise<WsTask<unknown> | boolean | undefined> {
      return Promise.resolve(undefined);
    },
    protocols: ["graphql-transport-ws"]
  });
  await socket.connect();

  await socket.send({ type: "connection_init" });

  return socket;
};
