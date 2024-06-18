import { Cleaner } from "cleaners";
import * as uuid from "uuid";

import { Logger } from "../utils/logger";

import Deferred from "./Deferred";
import { setupWS } from "./setup";
import { SocketEmitter, SocketEvent } from "./SocketEmitter";
import { pushUpdate, removeIdFromQueue } from "./socketQueue";
import { InnerSocket, InnerSocketCallbacks, ReadyState } from "./types";

const TIMER_SLACK = 500;
const KEEP_ALIVE_MS = 50000; // interval at which we keep the connection alive
const WAKE_UP_MS = 5000; // interval at which we wakeUp and potentially onQueueSpace

const CONNECTION_ID = uuid.v4();

export type OnFailHandler = (error: Error) => void;

export type Message = Record<string, any>;

export interface WsTask<T> {
  message: Message;
  deferred: Deferred<T>;
  cleaner?: Cleaner<T>;
}

export interface WsSubscription<T> {
  message: Message;
  cb: (value: T, unsubscribe: () => void) => void;
  cleaner?: Cleaner<T>;
}

interface WsSubscriptionWithUnsubscribe<T> extends WsSubscription<T> {
  unsubscribe: () => void;
}

export interface Socket {
  readyState: ReadyState;
  connect: () => Promise<void>;
  disconnect: () => void;
  submitTask: <T>(task: WsTask<T>) => void;
  send: <T>(message: Message) => Promise<T>;
  onQueueSpace: (cb: OnQueueSpaceCB) => void;
  subscribe: <T>(subscription: WsSubscription<T>) => void;
  isConnected: () => boolean;
}

export type OnQueueSpaceCB = (
  uri: string
) => Promise<WsTask<unknown> | boolean | undefined>;

interface SocketConfig {
  queueSize?: number;
  timeout?: number;
  emitter: SocketEmitter;
  healthCheck: () => Promise<void>; // function for heartbeat, should submit task itself
  onQueueSpaceCB: OnQueueSpaceCB;
  protocols?: string | string[];
  logger?: Logger;
}

interface WsMessage<T> {
  task: WsTask<T>;
  startTime: number;
}

interface Subscriptions<T> {
  [key: string]: WsSubscriptionWithUnsubscribe<T>;
}

interface PendingMessages<T> {
  [key: string]: WsMessage<T>;
}

export function makeSocket(uri: string, config: SocketConfig): Socket {
  let socket: InnerSocket | null;
  const { emitter, logger, queueSize = 50 } = config;
  // console.log("makeSocket connects to", uri);
  const version = "";
  const socketQueueId = uuid.v4();
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const subscriptions: Subscriptions<any> = {};
  let onQueueSpace = config.onQueueSpaceCB;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  let pendingMessages: PendingMessages<any> = {};
  let lastKeepAlive = Date.now() + KEEP_ALIVE_MS;
  let lastWakeUp = 0;
  let connected = false;
  let cancelConnect = false;
  const timeout: number = 1000 * (config.timeout ?? 30);
  let error: Error | undefined;
  let timer: NodeJS.Timeout;

  const handleError = (e: Error): void => {
    if (error == null) error = e;
    if (connected && socket != null && socket.readyState === ReadyState.OPEN)
      disconnect();
    else cancelConnect = true;
    console.error("handled error!", e);
  };

  const disconnect = (): void => {
    console.warn("disconnecting from socket", uri);
    clearTimeout(timer);
    connected = false;
    if (socket != null) socket.disconnect();
    removeIdFromQueue(socketQueueId);
  };

  const onSocketClose = (_err?: Error): void => {
    if (_err) handleError(_err);
    const err = error ?? new Error("Socket close");
    console.warn(`onSocketClose due to ${err.message} with server ${uri}`);
    clearTimeout(timer);
    connected = false;
    socket = null;
    cancelConnect = false;
    for (const message of Object.values(pendingMessages)) {
      try {
        message.task.deferred.reject(err);
      } catch (e) {
        if (e instanceof Error) {
          console.error(e.message);
        }
      }
    }
    pendingMessages = {};
    try {
      emitter.emit(SocketEvent.CONNECTION_CLOSE, uri, err);
    } catch (e) {
      if (e instanceof Error) {
        console.error(e.message);
      }
    }
  };

  const onSocketConnect = (): void => {
    config?.logger?.log(`onSocketConnect with server ${uri}`);
    if (cancelConnect) {
      if (socket != null) socket.disconnect();
      return;
    }
    connected = true;
    lastKeepAlive = Date.now();
    try {
      emitter.emit(SocketEvent.CONNECTION_OPEN, uri);
    } catch (e) {
      if (e instanceof Error) {
        handleError(e);
      }
    }
    for (const [id, message] of Object.entries(pendingMessages)) {
      transmitMessage(id, message);
    }

    wakeUp();
    cancelConnect = false;
  };

  const wakeUp = (): void => {
    // console.log(`wakeUp socket with server ${uri}`);
    pushUpdate({
      id: socketQueueId,
      updateFunc: () => {
        doWakeUp().catch(err => {
          throw new Error(`wake up error from: ${err.message}`);
        });
      }
    });
  };

  const doWakeUp = async (): Promise<void> => {
    // console.log(`doWakeUp socket with server ${uri}`);
    lastWakeUp = Date.now();
    if (connected && version != null) {
      while (Object.keys(pendingMessages).length < queueSize) {
        const task = await onQueueSpace?.(uri);
        if (task == null) break;
        if (typeof task === "boolean") {
          if (task) continue;
          break;
        }
        submitTask(task);
      }
    }
  };

  // add any exception, since the passed in template parameter needs to be re-assigned
  const subscribe = <T>(subscription: WsSubscription<T>): void => {
    const id = uuid.v4();

    if (socket != null && socket.readyState === ReadyState.OPEN && connected) {
      subscriptions[id] = {
        ...subscription,
        unsubscribe: (): void => {
          socket?.send(JSON.stringify({ id, type: "complete" }));
        }
      };

      const message = { id, ...subscription.message };
      socket.send(JSON.stringify(message));
    }
  };

  // add any exception, since the passed in template parameter needs to be re-assigned
  const submitTask = <T>(task: WsTask<T>): void => {
    const id =
      task.message.type === "connection_init" ? CONNECTION_ID : uuid.v4();
    const message = { task, startTime: Date.now() };
    pendingMessages[id] = message;
    transmitMessage(id, message);
  };

  const submitTaskAsync = <T>(message: Message): Promise<T> => {
    const deferred = new Deferred<T>();
    submitTask({ message, deferred });
    return deferred.promise;
  };

  const transmitMessage = <T>(id: string, pending: WsMessage<T>): void => {
    const now = Date.now();
    if (
      socket != null &&
      socket.readyState === ReadyState.OPEN &&
      connected &&
      !cancelConnect
    ) {
      if (id in subscriptions && pending.task.message.type === "complete") {
        // eslint-disable-next-line @typescript-eslint/no-dynamic-delete
        delete subscriptions[id];
        // eslint-disable-next-line @typescript-eslint/no-dynamic-delete
        delete pendingMessages[id];
      }

      pending.startTime = now;
      const message = {
        id,
        ...pending.task.message
      };
      // console.log(`transmitMessage with server ${uri}`, message);
      socket.send(JSON.stringify(message));
    }
  };

  const onTimer = (): void => {
    // console.log(
    //   `socket timer with server ${uri} expired, check if healthCheck needed`
    // );
    const now = Date.now() - TIMER_SLACK;
    if (lastKeepAlive + KEEP_ALIVE_MS < now) {
      // console.log(`submitting healthCheck to server ${uri}`);
      lastKeepAlive = now;
      config
        .healthCheck()
        .then(() => {
          emitter.emit(SocketEvent.CONNECTION_TIMER, uri, now);
        })
        .catch((e: Error) => handleError(e));
    }

    for (const [id, message] of Object.entries(pendingMessages)) {
      if (message.startTime + timeout < now) {
        try {
          message.task.deferred.reject(new Error("Timeout"));
        } catch (e) {
          if (e instanceof Error) {
            console.error(e.message);
          }
        }
        // eslint-disable-next-line @typescript-eslint/no-dynamic-delete
        delete pendingMessages[id];
      }
    }
    wakeUp();
    setupTimer();
  };

  const setupTimer = (): void => {
    // console.log(`setupTimer with server ${uri}`);
    let nextWakeUp = lastWakeUp + WAKE_UP_MS;
    for (const message of Object.values(pendingMessages)) {
      const to = message.startTime + timeout;
      if (to < nextWakeUp) nextWakeUp = to;
    }

    const now = Date.now() - TIMER_SLACK;
    const delay = nextWakeUp < now ? 0 : nextWakeUp - now;
    timer = setTimeout(() => onTimer(), delay);
  };

  const onMessage = (messageJson: string): void => {
    try {
      const json = JSON.parse(messageJson);
      // check if this is a connection_ack message and if so, set the connection id
      if (json.type === "connection_ack") {
        json.id = CONNECTION_ID;
      }
      if (json.id != null) {
        const id: string = json.id.toString();
        for (const cId of Object.keys(subscriptions)) {
          if (id === cId) {
            const subscription = subscriptions[id];
            if (subscription == null) {
              throw new Error(`cannot find subscription for ${id}`);
            }
            try {
              const value = subscription.cleaner
                ? subscription.cleaner(json)
                : json;
              subscription.cb(value, subscription.unsubscribe);
            } catch (error) {
              console.error({ uri, error, json, subscription });
              throw error;
            }
            return;
          }
        }
        const message = pendingMessages[id];
        if (message == null) {
          throw new Error(`Bad response id in ${messageJson}`);
        }
        // eslint-disable-next-line @typescript-eslint/no-dynamic-delete
        delete pendingMessages[id];
        const { error } = json;
        try {
          if (error != null) {
            const errorMessage =
              error.message != null ? error.message : error.connected;
            throw new Error(errorMessage);
          }
          const value = message.task.cleaner
            ? message.task.cleaner(json)
            : json;
          message.task.deferred.resolve(value);
        } catch (error) {
          console.error({ uri, error, json, message });
          message.task.deferred.reject(error);
        }
      }
    } catch (e) {
      if (e instanceof Error) {
        handleError(e);
      }
    }
    wakeUp();
  };

  setupTimer();

  // return a Socket
  return {
    get readyState(): ReadyState {
      return socket?.readyState ?? ReadyState.CLOSED;
    },

    async connect() {
      socket?.disconnect();

      return await new Promise<void>(resolve => {
        const cbs: InnerSocketCallbacks = {
          onOpen: () => {
            onSocketConnect();
            resolve();
          },
          onMessage: onMessage,
          onError: _error => {
            error = _error;
          },
          onClose: onSocketClose
        };

        socket = setupWS(uri, cbs, config.protocols);
      });
    },

    disconnect() {
      socket?.disconnect();
      socket = null;
      disconnect();
    },

    isConnected(): boolean {
      return socket?.readyState === ReadyState.OPEN;
    },

    submitTask,
    send: submitTaskAsync,

    onQueueSpace(cb: OnQueueSpaceCB): void {
      onQueueSpace = cb;
    },

    subscribe
  };
}
