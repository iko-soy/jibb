const dec = (value) => {
  if (value === 0n) throw new Error('decrement underflow');
  return value - 1n;
};
const add = ([left, right]) => left + right;

export const cases = [
  {
    name: 'tail-countdown',
    source: `
      (rec ((loop (lam n
        (if (eq n 0)
          42
          (app loop (app (native dec) n))))))
        loop)
    `,
    natives: { dec },
    arguments: [1_000n],
    expected: 42n,
  },
  {
    name: 'tail-sum',
    source: `
      (rec ((loop (lam state
        (let n (slot 2 state)
          (let total (slot 3 state)
            (if (eq n 0)
              total
              (app loop
                (cons (app (native dec) n)
                      (app (native add) (cons total n))))))))))
        loop)
    `,
    natives: { dec, add },
    arguments: [[1_000n, 0n]],
    expected: 500_500n,
  },
  {
    name: 'record-edit',
    source: '(edit 6 (cons 1 (cons 2 3)) 42)',
    natives: {},
    arguments: [],
    expected: [1n, [42n, 3n]],
  },
];
