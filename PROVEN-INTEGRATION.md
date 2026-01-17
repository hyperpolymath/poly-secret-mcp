# Proven Library Integration Plan

This document outlines how the [proven](https://github.com/hyperpolymath/proven) library's formally verified modules can be integrated into poly-secret-mcp.

## Applicable Modules

### High Priority

| Module | Use Case | Formal Guarantee |
|--------|----------|------------------|
| `SafeCapability` | Secret access control | Principle of least privilege |
| `SafeVault` | Secret lifecycle | Secure storage transitions |
| `SafeProvenance` | Audit trail | Tamper-evident access logs |

### Medium Priority

| Module | Use Case | Formal Guarantee |
|--------|----------|------------------|
| `SafeBuffer` | Secret rotation queue | Bounded pending rotations |
| `SafeStateMachine` | Secret states | Valid lifecycle transitions |
| `SafeCrypto` | Cryptographic operations | Correct algorithm usage |

## Integration Points

### 1. Secret Access Control (SafeCapability)

```
vault_kv_get → SafeCapability.checkCapability → scoped secret access
```

Capability model for secrets:
- Create capability with path pattern (e.g., `secret/data/app/*`)
- Attenuate to specific key (e.g., `secret/data/app/db-password`)
- Time-limited capabilities (auto-expire)

### 2. Secret Lifecycle (SafeVault)

```
:nonexistent → :created → :active → :rotating → :deprecated → :destroyed
```

State transitions:
- `vault_kv_put`: nonexistent → created → active
- `vault_rotate`: active → rotating → active
- `vault_kv_destroy`: * → destroyed (irreversible)

### 3. Audit Provenance (SafeProvenance)

```
secret_access → SafeProvenance.logAccess → hash-chained audit entry
```

Every secret access creates a tamper-evident audit log entry with:
- Accessor identity
- Secret path
- Access type (read/write/list)
- Timestamp
- Previous entry hash

## Backend-Specific Integrations

| Backend | Key Integration | proven Module |
|---------|-----------------|---------------|
| HashiCorp Vault | KV v2 | SafeVault |
| AWS Secrets Manager | Rotation | SafeStateMachine |
| 1Password | Access control | SafeCapability |
| Bitwarden | Audit | SafeProvenance |
| SOPS | Encryption | SafeCrypto |

## Security Properties

### Zero-Knowledge Proofs

For sensitive environments, SafeCapability supports:
```
SafeCapability.proveAccess → ZK proof of authorized access
```

No secret content is revealed during capability verification.

### Rotation Safety

SafeStateMachine ensures safe rotation:
```
old_version → rotating (both valid) → new_version (old expired)
```

No window where secret is unavailable.

## Implementation Notes

All secret operations flow through proven's capability checker:

```
request → SafeCapability.verify → execute → SafeProvenance.log
```

Unauthorized access attempts are rejected before reaching the secret store.

## Status

- [ ] Add SafeCapability for secret access control
- [ ] Implement SafeVault for secret lifecycle
- [ ] Integrate SafeProvenance for audit logging
- [ ] Add rotation state machine
