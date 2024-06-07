// Code generated by protoc-gen-as. DO NOT EDIT.
// Versions:
//   protoc-gen-as v1.3.0

import { Writer, Reader } from "as-proto/assembly";

export class lendergroup_Paused {
  static encode(message: lendergroup_Paused, writer: Writer): void {
    writer.uint32(10);
    writer.string(message.evtTxHash);

    writer.uint32(16);
    writer.uint32(message.evtIndex);

    writer.uint32(24);
    writer.uint64(message.evtBlockTime);

    writer.uint32(32);
    writer.uint64(message.evtBlockNumber);

    writer.uint32(42);
    writer.string(message.evtAddress);

    writer.uint32(50);
    writer.bytes(message.account);
  }

  static decode(reader: Reader, length: i32): lendergroup_Paused {
    const end: usize = length < 0 ? reader.end : reader.ptr + length;
    const message = new lendergroup_Paused();

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
          message.evtBlockTime = reader.uint64();
          break;

        case 4:
          message.evtBlockNumber = reader.uint64();
          break;

        case 5:
          message.evtAddress = reader.string();
          break;

        case 6:
          message.account = reader.bytes();
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
  evtBlockTime: u64;
  evtBlockNumber: u64;
  evtAddress: string;
  account: Uint8Array;

  constructor(
    evtTxHash: string = "",
    evtIndex: u32 = 0,
    evtBlockTime: u64 = 0,
    evtBlockNumber: u64 = 0,
    evtAddress: string = "",
    account: Uint8Array = new Uint8Array(0)
  ) {
    this.evtTxHash = evtTxHash;
    this.evtIndex = evtIndex;
    this.evtBlockTime = evtBlockTime;
    this.evtBlockNumber = evtBlockNumber;
    this.evtAddress = evtAddress;
    this.account = account;
  }
}
