// Code generated by protoc-gen-as. DO NOT EDIT.
// Versions:
//   protoc-gen-as v1.3.0

import { Writer, Reader } from "as-proto/assembly";
import { Timestamp } from "../../google/protobuf/Timestamp";

export class fac_BeaconUpgraded {
  static encode(message: fac_BeaconUpgraded, writer: Writer): void {
    writer.uint32(10);
    writer.string(message.evtTxHash);

    writer.uint32(16);
    writer.uint32(message.evtIndex);

    const evtBlockTime = message.evtBlockTime;
    if (evtBlockTime !== null) {
      writer.uint32(26);
      writer.fork();
      Timestamp.encode(evtBlockTime, writer);
      writer.ldelim();
    }

    writer.uint32(32);
    writer.uint64(message.evtBlockNumber);

    writer.uint32(42);
    writer.bytes(message.beacon);
  }

  static decode(reader: Reader, length: i32): fac_BeaconUpgraded {
    const end: usize = length < 0 ? reader.end : reader.ptr + length;
    const message = new fac_BeaconUpgraded();

    while (reader.ptr < end) {
      const tag = reader.uint32();
      switch (tag >>> 3) {
        case 1:
          message.evtTxHash = reader.string();
          break;

        case 2:
          message.evtIndex = reader.uint32();
          break;

        case 3:
          message.evtBlockTime = Timestamp.decode(reader, reader.uint32());
          break;

        case 4:
          message.evtBlockNumber = reader.uint64();
          break;

        case 5:
          message.beacon = reader.bytes();
          break;

        default:
          reader.skipType(tag & 7);
          break;
      }
    }

    return message;
  }

  evtTxHash: string;
  evtIndex: u32;
  evtBlockTime: Timestamp | null;
  evtBlockNumber: u64;
  beacon: Uint8Array;

  constructor(
    evtTxHash: string = "",
    evtIndex: u32 = 0,
    evtBlockTime: Timestamp | null = null,
    evtBlockNumber: u64 = 0,
    beacon: Uint8Array = new Uint8Array(0)
  ) {
    this.evtTxHash = evtTxHash;
    this.evtIndex = evtIndex;
    this.evtBlockTime = evtBlockTime;
    this.evtBlockNumber = evtBlockNumber;
    this.beacon = beacon;
  }
}
