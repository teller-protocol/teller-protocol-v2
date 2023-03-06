export function addToArray<T>(
  array: T[],
  item: T,
  // eslint-disable-next-line @typescript-eslint/no-inferrable-types
  unique: boolean = true
): T[] {
  if (unique && array.includes(item)) return array;
  array.push(item);
  return array;
}

export function removeFromArray<T>(array: T[], item: T): T[] {
  const index = array.indexOf(item);
  if (index != -1) array.splice(index, 1);
  return array;
}
