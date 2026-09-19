import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import { InMemoryAckStore, mintAcknowledgement, scopeHashFor } from '../src/disclosure.js'

describe('acknowledgements', () => {
  it('round-trips an ack once', async () => {
    const store = new InMemoryAckStore()
    const ack = mintAcknowledgement(['personal'], 'CA')
    await store.put(ack)
    assert.equal((await store.take(ack.id))?.id, ack.id)
  })

  it('is single-use', async () => {
    const store = new InMemoryAckStore()
    const ack = mintAcknowledgement(['personal'], 'CA')
    await store.put(ack)
    await store.take(ack.id)
    assert.equal(await store.take(ack.id), undefined)
  })

  it('refuses an expired ack', async () => {
    const store = new InMemoryAckStore()
    const ack = { ...mintAcknowledgement(['personal'], 'CA'), expiresAt: Date.now() - 1 }
    await store.put(ack)
    assert.equal(await store.take(ack.id), undefined)
  })

  it('returns undefined for an unknown id', async () => {
    assert.equal(await new InMemoryAckStore().take('nope'), undefined)
  })

  it('scopes by product set and country, order-independently', () => {
    assert.equal(scopeHashFor(['personal', 'auto_refi'], 'CA'), scopeHashFor(['auto_refi', 'personal'], 'CA'))
    assert.notEqual(scopeHashFor(['personal'], 'CA'), scopeHashFor(['personal'], 'US'))
    assert.notEqual(scopeHashFor(['personal'], 'CA'), scopeHashFor(['business'], 'CA'))
  })
})

describe('outbound guard', () => {
  it('blocks a forbidden field that reached the client by another path', async () => {
    const { GuardedPrequalClient } = await import('../src/upstream/client.js')
    const { FixturePrequalClient } = await import('../src/upstream/fixture.js')
    const { PolicyError } = await import('../src/policy.js')
    const guarded = new GuardedPrequalClient(new FixturePrequalClient())
    const answers = { loanTypes: ['personal'], country: 'CA', business: { nested: { ssn: 'x' } } } as never
    await assert.rejects(() => guarded.preview(answers), PolicyError)
    await assert.rejects(
      () => guarded.submit(answers, { consent: true, disclosureVersion: 'v', acknowledgedAt: 0, clientSubmissionId: 'id' }),
      PolicyError,
    )
  })
})
