/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * @format
 * @flow
 */

import {testCodemod} from '../../../testUtils/codemodTestUtils';
import removeExplicitlyExactObjectTypeSyntax from '../removeExplicitlyExactObjectTypeSyntax';

testCodemod(
  'removeExplicitlyExactObjectTypeSyntax',
  removeExplicitlyExactObjectTypeSyntax,
  {
    // IGNORED
    ignored: [
      {
        description: 'class',
        code: `class A {}`,
      },
      {
        description: 'interface',
        code: `interface B {}`,
      },
      {
        description: 'declare class',
        code: `declare class C {}`,
      },
      {
        description: 'declare interface',
        code: `declare interface D {}`,
      },
      {
        description: 'inexact',
        code: `type Inexact = {a: number, ...};`,
      },
      {
        description: 'default',
        code: `type Default = {a: number};`,
      },
    ],

    // TRANSFORMED
    transformed: [
      {
        description: 'type alias',
        code: `type T = {||};`,
        output: `type T = {};`,
      },
      {
        description: 'opaque type',
        code: `opaque type T: {||} = {||};`,
        output: `opaque type T: {} = {};`,
      },
      {
        description: 'function',
        code: `function test(x: {||}): {||} {}`,
        output: `function test(x: {}): {} {}`,
      },
      {
        description: 'nested',
        code: `type Nested = {|x: {||}|};`,
        output: `type Nested = {x: {}};`,
      },
      {
        description: 'generic',
        code: `type Generic<T: {||}> = T;`,
        output: `type Generic<T: {}> = T;`,
      },
      {
        description: 'opaque generic',
        code: `opaque type Generic<T: {||}> = T;`,
        output: `opaque type Generic<T: {}> = T;`,
      },
      {
        description: 'class static',
        code: `class A {
  static x: {||} = {};
}`,
        output: `class A {
  static x: {} = {};
}`,
      },
      {
        description: 'nested obj',
        code: `type T = {|
  a: number,
  b: string,
  c: {||},
  d: string,
|};`,
        output: `type T = {
  a: number,
  b: string,
  c: {},
  d: string,
};`,
      },
      {
        description: 'deeply nested obj',
        code: `type U = {|
  a: number,
  b: {||},
  c: {|x: {||}|},
  d: {|x: {|y: {||}|}|},
|};`,
        output: `type U = {
  a: number,
  b: {},
  c: {x: {}},
  d: {x: {y: {}}},
};`,
      },
    ],
  },
);
