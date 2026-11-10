// Calendar arithmetic shared by Hoon date packing and aura printing.
export function isLeap(year) {
  return year % 4n === 0n && (year % 100n !== 0n || year % 400n === 0n);
}

export function monthLengths(year) {
  return [
    31n, isLeap(year) ? 29n : 28n, 31n, 30n, 31n, 30n,
    31n, 31n, 30n, 31n, 30n, 31n,
  ];
}

// Hoon +yall. Removing complete 400-year eras leaves fewer than 400 years to
// walk, and preserves year zero's leap day at the start of every era.
export function civilFromDays(totalDays) {
  const era = totalDays / 146_097n;
  let days = totalDays % 146_097n;
  let year = era * 400n;

  while (days >= (isLeap(year) ? 366n : 365n)) {
    days -= isLeap(year) ? 366n : 365n;
    year += 1n;
  }

  let month = 1n;
  for (const length of monthLengths(year)) {
    if (days < length) break;
    days -= length;
    month += 1n;
  }
  return [year, month, days + 1n];
}
