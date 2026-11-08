const decimal = /(?:0|[1-9][0-9]{0,2}(?:\.[0-9]{3})*)/;

module.exports = grammar({
  name: 'jibb',

  externals: $ => [
    $._indent,
    $._dedent,
    $._newline,
    $.comment,
    $._space,
    $._tight,
    $._ship,
    $._duration,
  ],

  extras: $ => [
    / +/,
    $.comment,
    $.trailing_comment,
  ],

  conflicts: $ => [
    [$._mold, $._closed_mold],
    [$.wing, $.field],
    [$.wing, $._closed_field],
    [$.wing, $._closed_field, $._open_field],
    [$.wing, $.field, $._closed_field, $._open_field],
    [$.field, $._closed_field],
    [$.field, $._open_field],
    [$.field, $._closed_field, $._open_field],
    [$.tuple],
    [$.constructor, $.sample],
    [$._operand, $.open_group],
    [$._operand, $._open_operand],
    [$._mold, $._open_mold],
    [$._head_prefix, $.gate],
    [$._head_prefix, $.cast],
    [$.sample_binding, $.sample_face],
    [$._closed_field, $._open_field],
    [$.change, $._closed_edit],
    [$._operand, $._open_application_call],
    [$._closed_call, $._operand],
    [$._closed_call, $.open_group],
    [$._closed_call, $.open_list],
    [$._closed_call, $._open_application_call],
  ],

  rules: {
    source_file: $ => seq(
      repeat($._newline),
      repeat(seq($.import, $._newline)),
      repeat(seq($.definition, $._newline)),
    ),

    trailing_comment: _ => /::[^\n\t\r\x00-\x08\x0b-\x1f\x7f]*/,

    import: $ => choice(
      seq('/-', field('name', $.name)),
      seq('/%', field('mark', alias(/%[a-z][a-z0-9-]*/, $.term))),
      seq('/=', field('name', $.name), field('path', $.module_path)),
    ),

    definition: $ => choice(
      $.mold_definition,
      $.value_definition,
    ),

    mold_definition: $ => seq(
      '+$',
      field('name', $.name),
      optional(field('generic', $.generic)),
      choice(field('mold', $._mold), field('cases', $._cases)),
    ),

    value_definition: $ => seq(
      '++',
      field('name', $.name),
      field('value', choice($._expression, $._body)),
    ),

    generic: $ => seq('|$', '[', repeat1($.type_variable), ']'),

    _cases: $ => seq(
      $._indent,
      $._mold,
      repeat(seq($._newline, $._mold)),
      $._dedent,
    ),

    _body: $ => seq($._indent, $._rest, $._dedent),

    _rest: $ => seq(
      repeat(seq($.definition, $._newline)),
      $._last,
    ),

    _last: $ => choice(
      $._expression,
      $.rest_head,
      $.rest_branch,
    ),

    rest_head: $ => seq($._head, $._newline, $._rest),

    _head: $ => choice(
      seq($._head_prefix, optional(seq($._space, $._head))),
      $._trace_head,
    ),

    _head_prefix: $ => choice(
      seq('|=', $._space, field('sample', $.sample)),
      seq('^-', $._space, field('mold', $._closed_mold)),
    ),

    _trace_head: $ => seq('~&', $._space, field('value', $._closed_expression)),

    rest_branch: $ => seq(
      '?-',
      $._space,
      field('subject', $._closed_expression),
      $._newline,
      $.arm,
      repeat(seq($._newline, $.arm)),
    ),

    _expression: $ => choice($._rune, $.call),

    call: $ => seq($._operand, repeat(seq($._space, $._operand))),

    _closed_call: $ => prec.right(seq(
      $._closed_operand,
      repeat(seq($._space, $._closed_operand)),
    )),

    _closed_expression: $ => choice(
      alias($._closed_call, $.call),
      alias($._closed_gate, $.gate),
      alias($._closed_cast, $.cast),
    ),

    _closed_gate: $ => seq(
      '|=',
      $._space,
      field('sample', $.sample),
      $._space,
      field('body', $._closed_expression),
    ),

    _closed_cast: $ => seq(
      '^-',
      $._space,
      field('mold', $._closed_mold),
      $._space,
      field('value', $._closed_expression),
    ),

    _rune: $ => choice(
      $.gate,
      $.cast,
      $.trace,
      $.branch,
    ),

    gate: $ => seq(
      '|=',
      $._space,
      field('sample', $.sample),
      choice(
        seq($._space, field('body', $._expression)),
        field('body', $._body),
      ),
    ),

    cast: $ => seq(
      '^-',
      $._space,
      field('mold', $._mold),
      choice(
        seq($._space, field('value', $._expression)),
        field('value', $._body),
      ),
    ),

    trace: $ => seq(
      '~&',
      $._space,
      field('value', $._expression),
      field('body', $._body),
    ),

    branch: $ => seq(
      '?-',
      $._space,
      field('subject', $._expression),
      $._indent,
      $.arm,
      repeat(seq($._newline, $.arm)),
      $._dedent,
    ),

    arm: $ => seq(
      field('pattern', $.pattern),
      choice(
        seq($._space, field('value', $._expression)),
        field('value', $._body),
      ),
    ),

    _operand: $ => choice(
      $._closed_operand,
      $.open_group,
      $.open_list,
      $.open_tuple,
      $.open_change,
      alias($._open_wide_gate, $.wide_gate),
      $.open_rune_group,
    ),

    _closed_operand: $ => choice(
      $.literal,
      $.application_path,
      $.reference,
      $.change,
      $.pair,
      $.unit,
      $.group,
      $.list,
      $.tuple,
      $.wide_gate,
      $.constructor,
      $.path_literal,
      $.crash,
    ),

    reference: $ => $.wing,

    wing: $ => seq(
      $.name,
      repeat(seq(token.immediate('.'), $.name)),
    ),

    change: $ => seq(
      field('target', $.wing),
      token.immediate('('),
      repeat($.edit),
      ')',
    ),

    open_change: $ => seq(
      field('target', $.wing),
      token.immediate('('),
      choice(
        seq(
          repeat($._closed_edit),
          $._indent,
          $._edit_line,
          repeat(seq($._newline, $._edit_line)),
          $._dedent,
        ),
        seq(repeat($._closed_edit), $._open_edit),
      ),
    ),

    edit: $ => seq(
      field('field', $.wing),
      token.immediate('='),
      field('value', $._closed_operand),
    ),

    _closed_edit: $ => $.edit,

    _open_edit: $ => seq(
      field('field', $.wing),
      token.immediate('='),
      field('value', choice(
        $.open_group,
        $.open_list,
        $.open_tuple,
        $.open_change,
      )),
    ),

    _edit_line: $ => seq(
      field('field', $.wing),
      token.immediate('='),
      field('value', $._expression),
    ),

    pair: $ => seq(
      field('tag', $.name),
      token.immediate('+'),
      $._tight,
      field('value', $._closed_operand),
    ),

    unit: $ => seq(
      '`',
      $._tight,
      field('value', $._closed_operand),
    ),

    group: $ => seq('(', $._closed_expression, ')'),

    open_rune_group: $ => prec(-1, seq(
      '(',
      choice(
        $.branch,
        $.trace,
        $.open_rune_gate,
        $.open_rune_cast,
      ),
    )),

    open_rune_gate: $ => prec(-1, seq(
      '|=',
      $._space,
      field('sample', $.sample),
      field('body', $._body),
    )),

    open_rune_cast: $ => prec(-1, seq(
      '^-',
      $._space,
      field('mold', $._mold),
      field('value', $._body),
    )),

    open_group: $ => seq(
      '(',
      repeat(seq($._closed_operand, $._space)),
      choice(
        seq(
          optional($._closed_operand),
          $._indent,
          $._expression,
          repeat(seq($._newline, $._expression)),
          $._dedent,
        ),
        $._open_operand,
      ),
    ),

    _open_operand: $ => choice(
      $.open_group,
      $.open_list,
      $.open_tuple,
      $.open_change,
      alias($._open_wide_gate, $.wide_gate),
      $.open_rune_group,
    ),

    list: $ => seq(
      '~[',
      repeat(seq($._closed_operand, $._space)),
      optional($._closed_operand),
      ']',
    ),

    open_list: $ => seq(
      '~[',
      repeat(seq($._closed_operand, $._space)),
      choice(
        seq(
          optional($._closed_operand),
          $._indent,
          $._expression,
          repeat(seq($._newline, $._expression)),
          $._dedent,
        ),
        $._open_operand,
      ),
    ),

    tuple: $ => seq('[', repeat($._closed_item), ']'),

    open_tuple: $ => seq(
      '[',
      choice(
        seq(
          repeat($._closed_item),
          $._indent,
          $._item_line,
          repeat(seq($._newline, $._item_line)),
          $._dedent,
        ),
        seq(repeat($._closed_item), $._open_item),
      ),
    ),

    _closed_item: $ => choice(
      seq(
        field('face', $.name),
        token.immediate('='),
        field('value', $._closed_operand),
      ),
      $._closed_operand,
    ),

    _open_item: $ => choice(
      seq(
        field('face', $.name),
        token.immediate('='),
        field('value', $._open_operand),
      ),
      $._open_operand,
    ),

    _item_line: $ => choice(
      seq(
        field('face', $.name),
        token.immediate('='),
        field('value', $._expression),
      ),
      $._expression,
    ),

    wide_gate: $ => seq(
      '|=(',
      field('sample', $.sample),
      $._space,
      field('body', $._closed_operand),
      ')',
    ),

    _open_wide_gate: $ => seq(
      '|=(',
      field('sample', $.sample),
      $._space,
      field('body', $._open_operand),
    ),

    constructor: $ => seq('|=', $._tight, $.term),

    crash: _ => '!!',

    sample: $ => choice(
      $.sample_face,
      $.sample_pun,
      $.sample_cell,
      $.sample_binding,
      $.sample_mold_reference,
      $.aura,
      $.hole,
      $.noun,
      $.void,
      $.flag,
      $.term,
      $.loobean,
      $.null,
      $.path_mold,
      $.mold_apply,
      $.open_mold_apply,
      $.mold_function,
      $.type_variable,
    ),

    sample_binding: $ => $.name,

    sample_face: $ => seq(
      field('face', $.name),
      token.immediate('='),
      field('mold', $._mold),
    ),

    sample_pun: $ => seq('=', alias(token.immediate(/[a-z][a-z0-9-]*/), $.name)),

    sample_cell: $ => seq('[', $.sample, repeat($.sample), ']'),

    sample_mold_reference: $ => seq(
      $.name,
      repeat1(seq(token.immediate('.'), $.name)),
    ),

    _mold: $ => choice(
      $.aura,
      $.hole,
      $.noun,
      $.void,
      $.flag,
      $.null,
      $.term,
      $.loobean,
      $.mold_reference,
      $.type_variable,
      $.path_mold,
      $.mold_apply,
      $.open_mold_apply,
      $.mold_cell,
      $.open_mold_cell,
      $.mold_function,
      alias($._open_mold_function, $.mold_function),
    ),

    mold_reference: $ => $.wing,

    aura: _ => /@[a-z]*[A-Z]?/,
    hole: _ => '_',
    noun: _ => '*',
    void: _ => '!!',
    flag: _ => '?',

    mold_apply: $ => seq(
      '(',
      field('constructor', $.wing),
      field('argument', $._mold),
      repeat(field('argument', $._mold)),
      ')',
    ),

    open_mold_apply: $ => seq(
      '(',
      field('constructor', $.wing),
      repeat(field('argument', $._closed_mold)),
      choice(
        seq(
          $._indent,
          field('argument', $._mold),
          repeat(seq($._newline, field('argument', $._mold))),
          $._dedent,
        ),
        field('argument', $._open_mold),
      ),
    ),

    _closed_mold: $ => choice(
      $.aura,
      $.hole,
      $.noun,
      $.void,
      $.flag,
      $.null,
      $.term,
      $.loobean,
      $.mold_reference,
      $.type_variable,
      $.path_mold,
      $.mold_apply,
      $.mold_cell,
      $.mold_function,
    ),

    _open_mold: $ => choice(
      $.open_mold_apply,
      $.open_mold_cell,
      alias($._open_mold_function, $.mold_function),
    ),

    mold_cell: $ => seq('[', $.field, repeat($.field), ']'),

    open_mold_cell: $ => seq(
      '[',
      choice(
        seq(
          repeat($._closed_field),
          $._indent,
          $.field,
          repeat(seq($._newline, $.field)),
          $._dedent,
        ),
        seq(repeat($._closed_field), $._open_field),
      ),
    ),

    field: $ => choice(
      seq(
        field('face', $.name),
        token.immediate('='),
        field('mold', $._mold),
      ),
      $.pun,
      $._mold,
    ),

    _closed_field: $ => choice(
      seq(
        field('face', $.name),
        token.immediate('='),
        field('mold', $._closed_mold),
      ),
      $.pun,
      $._closed_mold,
    ),

    _open_field: $ => choice(
      seq(
        field('face', $.name),
        token.immediate('='),
        field('mold', $._open_mold),
      ),
      $.pun,
      $._open_mold,
    ),

    pun: $ => seq('=', alias(token.immediate(/[a-z][a-z0-9-]*/), $.name)),

    mold_function: $ => seq('$-(', field('sample', $._mold), field('product', $._mold), ')'),

    _open_mold_function: $ => seq(
      '$-(',
      field('sample', $._closed_mold),
      field('product', $._open_mold),
    ),

    pattern: $ => choice(
      $.term,
      $.number,
      $.string_literal,
      $.ship,
      $.loobean,
      $.null,
      $.wildcard,
      $.pattern_binding,
      $.pattern_cell,
    ),

    wildcard: _ => '*',
    pattern_binding: $ => $.name,
    pattern_cell: $ => seq('[', $.pattern, repeat($.pattern), ']'),

    literal: $ => choice(
      $.number,
      $.string,
      $.ship,
      $.date,
      $.duration,
      $.knot_literal,
      $.term,
      $.loobean,
      $.null,
    ),

    number: $ => choice($.decimal, $.hexadecimal, $.base32),
    decimal: _ => decimal,
    hexadecimal: _ => /0x[0-9a-fA-F]+(?:\.[0-9a-fA-F]+)*/,
    base32: _ => /0v[0-9a-v]+(?:\.[0-9a-v]+)*/,

    ship: $ => $._ship,
    date: _ => /~[0-9]+-?\.[0-9]{1,2}\.[0-9]{1,2}(?:\.\.[0-9]{1,2}\.[0-9]{1,2}\.[0-9]{1,2}(?:\.\.[0-9a-f]{4}(?:\.[0-9a-f]{4}){0,3})?)?/,
    duration: $ => $._duration,
    knot_literal: _ => /~\.[a-z0-9._~-]*/,

    term: _ => choice(
      /%(?:0|[1-9][0-9]{0,2}(?:\.[0-9]{3})*)/,
      /%[a-z][a-z0-9-]*/,
      '%&',
      '%|',
      '%$',
    ),

    loobean: _ => /%\.[yn]/,
    null: _ => '~',

    string: $ => choice(
      $.string_literal,
      seq(
        $.string_start,
        $._expression,
        repeat(seq($.string_middle, $._expression)),
        $.string_end,
      ),
    ),

    string_literal: _ => token(/"(?:\\(?:["{\\]|[0-9a-f]{2})|[^"\\{\n\t\r\x00-\x08\x0b-\x1f\x7f])*"/),
    string_start: _ => token(/"(?:\\(?:["{\\]|[0-9a-f]{2})|[^"\\{\n\t\r\x00-\x08\x0b-\x1f\x7f])*\{/),
    string_middle: _ => token(/\}(?:\\(?:["{\\]|[0-9a-f]{2})|[^"\\{\n\t\r\x00-\x08\x0b-\x1f\x7f])*\{/),
    string_end: _ => token(/\}(?:\\(?:["{\\]|[0-9a-f]{2})|[^"\\{\n\t\r\x00-\x08\x0b-\x1f\x7f])*"/),

    path_literal: $ => seq('/', optional($._path_segments)),
    _path_segments: $ => seq(
      $.knot,
      repeat(seq(token.immediate('/'), $.knot)),
    ),

    module_path: $ => seq(
      '/',
      $.knot,
      repeat(seq(token.immediate('/'), $.knot)),
    ),

    path_mold: $ => seq('/', optional($._path_mold_segments)),
    _path_mold_segments: $ => seq(
      $._path_mold_segment,
      repeat(seq(token.immediate('/'), $._path_mold_segment)),
    ),
    _path_mold_segment: $ => choice($.knot, $.typed_segment),

    typed_segment: $ => seq(
      token.immediate('['),
      $.name,
      token.immediate('='),
      $._tight,
      choice($.aura, $.hole),
      token.immediate(']'),
    ),

    application_path: $ => seq('%/', optional($._application_segments)),
    _application_segments: $ => seq(
      $._application_segment,
      repeat(seq(token.immediate('/'), $._application_segment)),
    ),
    _application_segment: $ => choice($.knot, $.application_expression_segment),
    application_expression_segment: $ => seq(
      token.immediate('('),
      choice(
        seq($._closed_expression, ')'),
        alias($._open_application_call, $.call),
      ),
    ),

    _open_application_call: $ => seq(
      repeat(seq($._closed_operand, $._space)),
      $._open_operand,
    ),

    knot: _ => /[a-z0-9._~-]+/,
    name: _ => /[a-z][a-z0-9-]*/,
    type_variable: _ => /[A-Z][a-z0-9]*/,
  },
});
