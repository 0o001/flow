//@flow

export var a: $TEMPORARY$number<'a'> = 42;

export var b: $TEMPORARY$number<1,1> = 42;

export const c = {['a' + 'b']: 42}

export const d = [...c];

export const e = (d += d);

export const f = class { }
