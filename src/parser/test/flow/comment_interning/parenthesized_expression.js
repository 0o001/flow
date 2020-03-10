var i = 0;

function foo() {}

/* Nested leading 1 */ ( /* Nested leading 2 */ i /* Nested trailing 1 */ ) /* Nested trailing 2 */;

/* Leading array */ ([]) /* Trailing array */;

/* Leading assign */ (i = 1) /* Trailing assign */;

/* Leading binary */ (1 + 2) /* Trailing binary */;

/* Leading call */ (foo()) /* Trailing call */

/* Leading class */ (class C {}) /* Trailing class */;

/* Leading conditional */ (true ? 1 : 2) /* Trailing conditional */;

/* Leading identifier */ (i) /* Trailing identifier */;

/* Leading literal */ (1) /* Trailing literal */;

/* Leading logical */ (false || true) /* Trailing logical */;

/* Leading member */ (i.isNaN) /* Trailing member */;

/* Leading new */ (new C()) /* Trailing new */;

/* Leading object */ ({}) /* Trailing object */;

/* Leading optional call */ (i?.isNaN()) /* Trailing optional call */;

/* Leading optional member */ (i?.isNaN) /* Trailing optional member */;

/* Leading template literal */ (`template`) /* Trailing template literal */;

/* Leading tagged template */ (tag`template`) /* Trailing tagged template */;

/* Leading this */ (this) /* Trailing this */;

/* Leading unary */ (+1) /* Trailing unary */;

/* Leading update */ (i++) /* Trailing update */;

function metaProperty() {
    /* Leading meta property */ (new.target) /* Trailing meta property */;
}

function* generator() {
    /* Leading yield */ (yield 1) /* Trailing yield */
}
