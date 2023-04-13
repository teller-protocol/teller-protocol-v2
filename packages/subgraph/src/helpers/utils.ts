import { BigInt } from "@graphprotocol/graph-ts";

export function addToArray<T>(
  array: T[],
  item: T,
  // eslint-disable-next-line @typescript-eslint/no-inferrable-types
  unique: boolean = true
): T[] {
  const arr = array.slice();
  if (unique && arr.includes(item)) return arr;
  arr.push(item);
  return arr;
}

export function removeFromArray<T>(array: T[], item: T): T[] {
  const arr = array.slice();
  const index = arr.indexOf(item);
  if (index != -1) arr.splice(index, 1);
  return arr;
}

export function camelize(str: string): string {
  const strNoSpace = str.split(" ").join("");
  return strNoSpace.charAt(0).toLowerCase() + strNoSpace.slice(1);
}

export function safeDiv(a: BigInt, b: BigInt): BigInt {
  return b.isZero() ? BigInt.zero() : a.div(b);
}
