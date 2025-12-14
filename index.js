// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
/**
 * poly-secret-mcp - Unified MCP Server for Secrets Management
 *
 * Supported Secret Managers:
 * - HashiCorp Vault
 * - Infisical (FOSS)
 * - SOPS (Mozilla)
 * - Doppler
 * - 1Password CLI
 * - Bitwarden CLI
 * - AWS Secrets Manager
 * - Azure Key Vault
 * - Google Secret Manager
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

// Import adapters (to be implemented)
// import { vaultAdapter } from "./adapters/vault.js";
// import { infisicalAdapter } from "./adapters/infisical.js";
// import { sopsAdapter } from "./adapters/sops.js";
// import { dopplerAdapter } from "./adapters/doppler.js";
// import { onepasswordAdapter } from "./adapters/onepassword.js";

const adapters = [
  // vaultAdapter,
  // infisicalAdapter,
  // sopsAdapter,
  // dopplerAdapter,
  // onepasswordAdapter,
];

const server = new Server(
  {
    name: "poly-secret-mcp",
    version: "1.0.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Collect all tools from adapters
const allTools = adapters.flatMap((adapter) => adapter.tools || []);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: allTools.map((tool) => ({
    name: tool.name,
    description: tool.description,
    inputSchema: tool.inputSchema,
  })),
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  for (const adapter of adapters) {
    const tool = adapter.tools?.find((t) => t.name === name);
    if (tool) {
      try {
        const result = await tool.handler(args);
        return {
          content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
        };
      } catch (error) {
        return {
          content: [{ type: "text", text: `Error: ${error.message}` }],
          isError: true,
        };
      }
    }
  }

  return {
    content: [{ type: "text", text: `Unknown tool: ${name}` }],
    isError: true,
  };
});

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("poly-secret-mcp server started");
}

main().catch(console.error);
