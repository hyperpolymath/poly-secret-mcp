// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell

/// HashiCorp Vault adapter for secret management
/// Uses vault CLI for operations

open Adapter

let vaultAddr = ref(Deno.Env.getWithDefault("VAULT_ADDR", "http://127.0.0.1:8200"))
let connected = ref(false)

let name = "vault"
let description = "HashiCorp Vault secrets management adapter"

let runVaultCmd = async (args: array<string>): (int, string, string) => {
  await Deno.Command.run("vault", args)
}

let connect = async () => {
  let (code, _, _) = await runVaultCmd(["status", "-format=json"])
  // Code 0 = unsealed, 1 = error, 2 = sealed but reachable
  if code == 0 || code == 2 {
    connected := true
  } else {
    Exn.raiseError("Failed to connect to Vault")
  }
}

let disconnect = async () => {
  connected := false
}

let isConnected = async () => connected.contents

// Read a secret
let readHandler = async (args: dict<JSON.t>): JSON.t => {
  let path = switch Dict.get(args, "path") {
  | Some(JSON.String(p)) => p
  | _ => Exn.raiseError("path parameter is required")
  }
  let field = switch Dict.get(args, "field") {
  | Some(JSON.String(f)) => Some(f)
  | _ => None
  }

  let cmdArgs = ["kv", "get", "-format=json"]
  switch field {
  | Some(f) => Array.push(cmdArgs, `-field=${f}`)
  | None => ()
  }
  Array.push(cmdArgs, path)

  let (code, stdout, stderr) = await runVaultCmd(cmdArgs)
  if code == 0 {
    try {
      JSON.parseExn(stdout)
    } catch {
    | _ => JSON.Encode.object(Dict.fromArray([("value", JSON.Encode.string(String.trim(stdout)))]))
    }
  } else {
    Exn.raiseError(stderr)
  }
}

// Write a secret
let writeHandler = async (args: dict<JSON.t>): JSON.t => {
  let path = switch Dict.get(args, "path") {
  | Some(JSON.String(p)) => p
  | _ => Exn.raiseError("path parameter is required")
  }
  // Accept data as "key1=value1 key2=value2" string or array of "key=value" strings
  let dataPairs = switch Dict.get(args, "data") {
  | Some(JSON.String(d)) => String.split(d, " ")
  | Some(JSON.Array(arr)) => arr->Array.filterMap(x => switch x { | JSON.String(v) => Some(v) | _ => None })
  | _ => Exn.raiseError("data parameter is required (string 'key=val key2=val2' or array)")
  }

  let cmdArgs = ["kv", "put", "-format=json", path]
  Array.forEach(dataPairs, pair => {
    Array.push(cmdArgs, pair)
  })

  let (code, stdout, stderr) = await runVaultCmd(cmdArgs)
  if code == 0 {
    try {
      JSON.parseExn(stdout)
    } catch {
    | _ => JSON.Encode.object(Dict.fromArray([("success", JSON.Encode.bool(true))]))
    }
  } else {
    Exn.raiseError(stderr)
  }
}

// Delete a secret
let deleteHandler = async (args: dict<JSON.t>): JSON.t => {
  let path = switch Dict.get(args, "path") {
  | Some(JSON.String(p)) => p
  | _ => Exn.raiseError("path parameter is required")
  }
  let versions = switch Dict.get(args, "versions") {
  | Some(JSON.Array(v)) => Some(v->Array.filterMap(x => switch x { | JSON.Number(n) => Some(Float.toInt(n)) | _ => None }))
  | _ => None
  }

  let cmdArgs = switch versions {
  | Some(v) => ["kv", "delete", "-versions=" ++ Array.join(v->Array.map(n => Int.toString(n)), ","), path]
  | None => ["kv", "delete", path]
  }

  let (code, _, stderr) = await runVaultCmd(cmdArgs)
  if code == 0 {
    JSON.Encode.object(Dict.fromArray([("success", JSON.Encode.bool(true))]))
  } else {
    Exn.raiseError(stderr)
  }
}

// List secrets at a path
let listHandler = async (args: dict<JSON.t>): JSON.t => {
  let path = switch Dict.get(args, "path") {
  | Some(JSON.String(p)) => p
  | _ => Exn.raiseError("path parameter is required")
  }

  let (code, stdout, stderr) = await runVaultCmd(["kv", "list", "-format=json", path])
  if code == 0 {
    try {
      JSON.parseExn(stdout)
    } catch {
    | _ => JSON.Encode.object(Dict.fromArray([("keys", JSON.Encode.string(stdout))]))
    }
  } else {
    Exn.raiseError(stderr)
  }
}

// Get secret metadata
let metadataHandler = async (args: dict<JSON.t>): JSON.t => {
  let path = switch Dict.get(args, "path") {
  | Some(JSON.String(p)) => p
  | _ => Exn.raiseError("path parameter is required")
  }

  let (code, stdout, stderr) = await runVaultCmd(["kv", "metadata", "get", "-format=json", path])
  if code == 0 {
    try {
      JSON.parseExn(stdout)
    } catch {
    | _ => JSON.Encode.object(Dict.fromArray([("metadata", JSON.Encode.string(stdout))]))
    }
  } else {
    Exn.raiseError(stderr)
  }
}

// Get Vault status
let statusHandler = async (_args: dict<JSON.t>): JSON.t => {
  let (code, stdout, stderr) = await runVaultCmd(["status", "-format=json"])
  if code == 0 || code == 2 {
    try {
      JSON.parseExn(stdout)
    } catch {
    | _ => JSON.Encode.object(Dict.fromArray([("status", JSON.Encode.string(stdout))]))
    }
  } else {
    Exn.raiseError(stderr)
  }
}

// List secret engines
let enginesHandler = async (_args: dict<JSON.t>): JSON.t => {
  let (code, stdout, stderr) = await runVaultCmd(["secrets", "list", "-format=json"])
  if code == 0 {
    try {
      JSON.parseExn(stdout)
    } catch {
    | _ => JSON.Encode.object(Dict.fromArray([("engines", JSON.Encode.string(stdout))]))
    }
  } else {
    Exn.raiseError(stderr)
  }
}

// Generate dynamic credentials (database, AWS, etc.)
let generateHandler = async (args: dict<JSON.t>): JSON.t => {
  let path = switch Dict.get(args, "path") {
  | Some(JSON.String(p)) => p
  | _ => Exn.raiseError("path parameter is required")
  }

  let (code, stdout, stderr) = await runVaultCmd(["read", "-format=json", path])
  if code == 0 {
    try {
      JSON.parseExn(stdout)
    } catch {
    | _ => JSON.Encode.object(Dict.fromArray([("credentials", JSON.Encode.string(stdout))]))
    }
  } else {
    Exn.raiseError(stderr)
  }
}

let tools: dict<toolDef> = Dict.fromArray([
  ("vault_read", {
    description: "Read a secret from Vault KV store",
    params: Dict.fromArray([
      ("path", stringParam(~description="Secret path (e.g., secret/data/myapp)")),
      ("field", stringParam(~description="Specific field to retrieve (optional)")),
    ]),
    handler: readHandler,
  }),
  ("vault_write", {
    description: "Write a secret to Vault KV store",
    params: Dict.fromArray([
      ("path", stringParam(~description="Secret path (e.g., secret/data/myapp)")),
      ("data", stringParam(~description="Secret data object (JSON)")),
    ]),
    handler: writeHandler,
  }),
  ("vault_delete", {
    description: "Delete a secret from Vault",
    params: Dict.fromArray([
      ("path", stringParam(~description="Secret path")),
      ("versions", stringParam(~description="Specific versions to delete (array of numbers)")),
    ]),
    handler: deleteHandler,
  }),
  ("vault_list", {
    description: "List secrets at a path",
    params: Dict.fromArray([
      ("path", stringParam(~description="Path to list (e.g., secret/metadata/)")),
    ]),
    handler: listHandler,
  }),
  ("vault_metadata", {
    description: "Get secret metadata including versions",
    params: Dict.fromArray([
      ("path", stringParam(~description="Secret path")),
    ]),
    handler: metadataHandler,
  }),
  ("vault_status", {
    description: "Get Vault server status",
    params: Dict.make(),
    handler: statusHandler,
  }),
  ("vault_engines", {
    description: "List all secret engines",
    params: Dict.make(),
    handler: enginesHandler,
  }),
  ("vault_generate", {
    description: "Generate dynamic credentials from a secrets engine",
    params: Dict.fromArray([
      ("path", stringParam(~description="Credentials path (e.g., database/creds/myapp)")),
    ]),
    handler: generateHandler,
  }),
])
