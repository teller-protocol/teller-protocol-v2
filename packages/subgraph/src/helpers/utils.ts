import { BigDecimal, BigInt, Entity } from "@graphprotocol/graph-ts";

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
  return b.isZero() ? b : a.div(b);
}

export function safeDivBD(a: BigDecimal, b: BigDecimal): BigDecimal {
  return b.digits.plus(b.exp).isZero() ? b : a.div(b);
}

export function calcStdDevAndMeanFromEntities(
  entities: Entity[],
  key: string
): BigDecimal[] {
  const mean = calcMean(entities, key);

  const variance = calcVariance(entities, key, mean);
  const stdDev = sqrtBD(variance);

  return [stdDev, mean];
}

function sqrtBD(x: BigDecimal): BigDecimal {
  let z = BigDecimal.fromString("1");
  for (let i = 0; i < 50; i++) {
    z = x
      .div(z)
      .plus(z)
      .div(BigDecimal.fromString("2"));
  }
  return z;
}

export function calcMean(entities: Entity[], key: string): BigDecimal {
  let sum = BigDecimal.zero();
  for (let i = 0; i < entities.length; i++) {
    if (!entities[i].isSet(key)) continue;
    const value = new BigDecimal(entities[i].getBigInt(key));
    sum = sum.plus(value);
  }
  const length = BigDecimal.fromString(entities.length.toString());
  return safeDivBD(sum, length);
}

export function calcVariance(
  entities: Entity[],
  key: string,
  mean: BigDecimal
): BigDecimal {
  let sum = BigDecimal.zero();
  for (let i = 0; i < entities.length; i++) {
    const value = entities[i].isSet(key)
      ? new BigDecimal(entities[i].getBigInt(key))
      : BigDecimal.zero();
    const diff = value.minus(mean);
    sum = sum.plus(diff.times(diff));
  }
  const length = BigDecimal.fromString(entities.length.toString());
  return safeDivBD(sum, length);
}

export function calcWeightedDeviation(
  mean: BigDecimal,
  stdDev: BigDecimal,
  weight: BigDecimal,
  value: BigInt | null
): BigDecimal {
  const val = value ? new BigDecimal(value) : BigDecimal.zero();
  const diff = val.minus(mean);
  const deviation = safeDivBD(diff, stdDev);
  return deviation.times(weight);
}
