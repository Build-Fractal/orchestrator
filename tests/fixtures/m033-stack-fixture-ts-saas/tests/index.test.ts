import { describe, it, expect } from 'vitest';
import { hello } from '../src/index';

describe('hello', () => {
  it('returns world', () => {
    expect(hello()).toBe('world');
  });
});
