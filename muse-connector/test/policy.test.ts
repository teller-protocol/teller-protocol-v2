import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import { assertAmountWithinProductCap, assertNoForbiddenFields, assertSupportedCountry, normalizeCountry, PolicyError } from '../src/policy.js'

describe('forbidden fields', () => {
  it('accepts a clean answer set', () => {
    assert.doesNotThrow(() =>
      assertNoForbiddenFields({ loanTypes: ['personal'], country: 'CA', credit: 'good', birthYear: 1990 }),
    )
  })

  for (const field of ['ssn', 'routingNumber', 'accountNumber', 'driverLicenseNumber', 'birthDate']) {
    it(`refuses ${field} at the top level`, () => {
      assert.throws(() => assertNoForbiddenFields({ [field]: 'x' }), (err: unknown) => {
        assert.ok(err instanceof PolicyError)
        assert.equal(err.code, 'forbidden_field')
        return true
      })
    })
  }

  it('refuses a forbidden field nested inside another object', () => {
    assert.throws(
      () => assertNoForbiddenFields({ business: { detail: { ssn: '123-45-6789' } } }),
      PolicyError,
    )
  })

  it('refuses a forbidden field inside an array', () => {
    assert.throws(() => assertNoForbiddenFields({ applicants: [{ ok: 1 }, { routingNumber: '021000021' }] }), PolicyError)
  })

  it('matches case-insensitively', () => {
    assert.throws(() => assertNoForbiddenFields({ SSN: 'x' }), PolicyError)
    assert.throws(() => assertNoForbiddenFields({ AccountNumber: 'x' }), PolicyError)
  })

  it('refuses whole detail blocks by name', () => {
    assert.throws(() => assertNoForbiddenFields({ usShortTermDetail: {} }), PolicyError)
    assert.throws(() => assertNoForbiddenFields({ usHelocDetail: {} }), PolicyError)
  })
})

describe('country gate', () => {
  it('normalizes names and codes', () => {
    assert.equal(normalizeCountry('United States'), 'US')
    assert.equal(normalizeCountry('usa'), 'US')
    assert.equal(normalizeCountry('Canada'), 'CA')
    assert.equal(normalizeCountry('gb'), 'GB')
    assert.equal(normalizeCountry('  '), undefined)
  })

  it('accepts supported countries', () => {
    assert.equal(assertSupportedCountry('United States', ['US', 'CA']), 'US')
  })

  it('rejects unsupported countries with a clear code', () => {
    assert.throws(() => assertSupportedCountry('GB', ['US', 'CA']), (err: unknown) => {
      assert.ok(err instanceof PolicyError)
      assert.equal(err.code, 'country_not_supported')
      return true
    })
  })
})

describe('amount caps', () => {
  it('allows an amount under the product ceiling', () => {
    assert.doesNotThrow(() => assertAmountWithinProductCap(['personal'], 25_000))
  })

  it('rejects an amount above every selected product ceiling', () => {
    assert.throws(() => assertAmountWithinProductCap(['personal'], 90_000), (err: unknown) => {
      assert.ok(err instanceof PolicyError)
      assert.equal(err.code, 'amount_above_cap')
      return true
    })
  })

  it('uses the highest ceiling when several products are selected', () => {
    assert.doesNotThrow(() => assertAmountWithinProductCap(['personal', 'home_purchase'], 900_000))
  })

  it('rejects a non-positive amount', () => {
    assert.throws(() => assertAmountWithinProductCap(['personal'], -1), PolicyError)
  })

  it('ignores an omitted amount', () => {
    assert.doesNotThrow(() => assertAmountWithinProductCap(['personal'], undefined))
  })
})
