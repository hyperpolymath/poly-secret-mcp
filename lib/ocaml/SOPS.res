// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell

/// SOPS adapter for encrypted file management
/// Mozilla SOPS - Secrets OPerationS

open Adapter

let connected = ref(false)

let name = "sops"
let description = "Mozilla SOPS encrypted secrets"

let runSopsCmd = async (args: array<string>): (int, string, string) => {
  await Deno.Command.run("sops", args)
}

let connect = async () => {
  let (code, _, _) = await runSopsCmd(["--version"])
  if code == 0 {
    connected := true
  } else {
    Exn.raiseError("SOPS CLI not found")
  }
}

let disconnect = async () => {
  connected := false
}

let isConnected = async () => connected.contents

// Decrypt a file
let decryptHandler = async (args: dict<JSON.t>): JSON.t => {
  let file = switch Dict.get(args, "file") {
  | Some(JSON.String(f)) => f
  | _ => Exn.raiseError("file parameter is required")
  }
  let outputType = switch Dict.get(args, "outputType") {
  | Some(JSON.String(o)) => Some(o)
  | _ => None
  }

  let cmdArgs = ["--decrypt"]
  switch outputType {
  | Some(t) => Array.push(cmdArgs, `--output-type=${t}`)
  | None => ()
  }
  Array.push(cmdArgs, file)

  let (code, stdout, stderr) = await runSopsCmd(cmdArgs)
  if code == 0 {
    try {
      JSON.parseExn(stdout)
    } catch {
    | _ => JSON.Encode.object(Dict.fromArray([("content", JSON.Encode.string(stdout))]))
    }
  } else {
    Exn.raiseError(stderr)
  }
}

// Encrypt a file
let encryptHandler = async (args: dict<JSON.t>): JSON.t => {
  let file = switch Dict.get(args, "file") {
  | Some(JSON.String(f)) => f
  | _ => Exn.raiseError("file parameter is required")
  }
  let inPlace = switch Dict.get(args, "inPlace") {
  | Some(JSON.Boolean(b)) => b
  | _ => false
  }

  let cmdArgs = ["--encrypt"]
  if inPlace {
    Array.push(cmdArgs, "--in-place")
  }
  Array.push(cmdArgs, file)

  let (code, stdout, stderr) = await runSopsCmd(cmdArgs)
  JSON.Encode.object(Dict.fromArray([
    ("success", JSON.Encode.bool(code == 0)),
    ("output", JSON.Encode.string(stdout)),
    ("error", JSON.Encode.string(stderr)),
  ]))
}

// Edit a value in encrypted file
let setHandler = async (args: dict<JSON.t>): JSON.t => {
  let file = switch Dict.get(args, "file") {
  | Some(JSON.String(f)) => f
  | _ => Exn.raiseError("file parameter is required")
  }
  let key = switch Dict.get(args, "key") {
  | Some(JSON.String(k)) => k
  | _ => Exn.raiseError("key parameter is required")
  }
  let value = switch Dict.get(args, "value") {
  | Some(JSON.String(v)) => v
  | _ => Exn.raiseError("value parameter is required")
  }

  let (code, stdout, stderr) = await runSopsCmd(["--set", `["${key}"] "${value}"`, file])
  JSON.Encode.object(Dict.fromArray([
    ("success", JSON.Encode.bool(code == 0)),
    ("key", JSON.Encode.string(key)),
    ("output", JSON.Encode.string(stdout)),
    ("error", JSON.Encode.string(stderr)),
  ]))
}

// Rotate encryption keys
let rotateHandler = async (args: dict<JSON.t>): JSON.t => {
  let file = switch Dict.get(args, "file") {
  | Some(JSON.String(f)) => f
  | _ => Exn.raiseError("file parameter is required")
  }

  let (code, stdout, stderr) = await runSopsCmd(["--rotate", "--in-place", file])
  JSON.Encode.object(Dict.fromArray([
    ("success", JSON.Encode.bool(code == 0)),
    ("output", JSON.Encode.string(stdout)),
    ("error", JSON.Encode.string(stderr)),
  ]))
}

// Get file metadata
let metadataHandler = async (args: dict<JSON.t>): JSON.t => {
  let file = switch Dict.get(args, "file") {
  | Some(JSON.String(f)) => f
  | _ => Exn.raiseError("file parameter is required")
  }

  // Decrypt to JSON and extract sops metadata
  let (code, stdout, stderr) = await runSopsCmd(["--decrypt", "--output-type=json", file])
  if code == 0 {
    try {
      let parsed = JSON.parseExn(stdout)
      // Return just the sops metadata if present
      switch Js.Json.decodeObject(parsed) {
      | Some(obj) =>
        switch Js.Dict.get(obj, "sops") {
        | Some(sops) => sops
        | None => parsed
        }
      | None => parsed
      }
    } catch {
    | _ => JSON.Encode.object(Dict.fromArray([("raw", JSON.Encode.string(stdout))]))
    }
  } else {
    Exn.raiseError(stderr)
  }
}

// Update keys (add/remove recipients)
let updateKeysHandler = async (args: dict<JSON.t>): JSON.t => {
  let file = switch Dict.get(args, "file") {
  | Some(JSON.String(f)) => f
  | _ => Exn.raiseError("file parameter is required")
  }

  let (code, stdout, stderr) = await runSopsCmd(["updatekeys", file])
  JSON.Encode.object(Dict.fromArray([
    ("success", JSON.Encode.bool(code == 0)),
    ("output", JSON.Encode.string(stdout)),
    ("error", JSON.Encode.string(stderr)),
  ]))
}

// Get version
let versionHandler = async (_args: dict<JSON.t>): JSON.t => {
  let (code, stdout, stderr) = await runSopsCmd(["--version"])
  JSON.Encode.object(Dict.fromArray([
    ("success", JSON.Encode.bool(code == 0)),
    ("version", JSON.Encode.string(String.trim(stdout))),
    ("error", JSON.Encode.string(stderr)),
  ]))
}

let tools: dict<toolDef> = Dict.fromArray([
  ("sops_decrypt", {
    description: "Decrypt a SOPS-encrypted file",
    params: Dict.fromArray([
      ("file", stringParam(~description="Path to encrypted file")),
      ("outputType", stringParam(~description="Output format (json, yaml, dotenv, binary)")),
    ]),
    handler: decryptHandler,
  }),
  ("sops_encrypt", {
    description: "Encrypt a file with SOPS",
    params: Dict.fromArray([
      ("file", stringParam(~description="Path to file to encrypt")),
      ("inPlace", boolParam(~description="Encrypt in place")),
    ]),
    handler: encryptHandler,
  }),
  ("sops_set", {
    description: "Set a value in encrypted file",
    params: Dict.fromArray([
      ("file", stringParam(~description="Path to encrypted file")),
      ("key", stringParam(~description="Key path to set")),
      ("value", stringParam(~description="Value to set")),
    ]),
    handler: setHandler,
  }),
  ("sops_rotate", {
    description: "Rotate encryption keys",
    params: Dict.fromArray([
      ("file", stringParam(~description="Path to encrypted file")),
    ]),
    handler: rotateHandler,
  }),
  ("sops_metadata", {
    description: "Get SOPS metadata from file",
    params: Dict.fromArray([
      ("file", stringParam(~description="Path to encrypted file")),
    ]),
    handler: metadataHandler,
  }),
  ("sops_updatekeys", {
    description: "Update keys for a file",
    params: Dict.fromArray([
      ("file", stringParam(~description="Path to encrypted file")),
    ]),
    handler: updateKeysHandler,
  }),
  ("sops_version", {
    description: "Show SOPS version",
    params: Dict.make(),
    handler: versionHandler,
  }),
])
