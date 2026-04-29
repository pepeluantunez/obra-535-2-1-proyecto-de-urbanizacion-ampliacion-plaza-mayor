import { z } from "zod";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { CIVIL3D_MCP_CONFIG } from "../config.js";
import { withApplicationConnection } from "../utils/ConnectionManager.js";

const ExportFormatSchema = z.enum(["json", "csv"]);

const ExportPressureNetworkInputSchema = z.object({
  networkName: z
    .string()
    .optional()
    .describe("Optional pressure network name. When omitted, plugin may export all."),
  includePipes: z.boolean().optional().describe("Include pressure pipes."),
  includeFittings: z.boolean().optional().describe("Include fittings."),
  includeAppurtenances: z
    .boolean()
    .optional()
    .describe("Include appurtenances."),
  includePartsMetadata: z
    .boolean()
    .optional()
    .describe("Include parts list/part size metadata."),
  limit: z
    .number()
    .int()
    .min(1)
    .max(CIVIL3D_MCP_CONFIG.maxExportRows)
    .optional()
    .describe(`Maximum exported rows per entity type (1-${CIVIL3D_MCP_CONFIG.maxExportRows}).`),
  format: ExportFormatSchema
    .optional()
    .describe("Output format hint for plugin side export behavior."),
});

// ---------------------------------------------------------------------------
// Typed row schemas — all coordinates in drawing units, nullable when the
// plugin cannot resolve the value from the Civil 3D pressure network object.
// ---------------------------------------------------------------------------

const PressurePipeRowSchema = z
  .object({
    networkName: z.string().nullable().optional(),
    handle: z.string().describe("AutoCAD object handle (hex)."),
    objectType: z.string().nullable().optional(),
    name: z.string().nullable().optional(),
    description: z.string().nullable().optional(),
    layer: z.string().nullable().optional(),
    x: z.number().nullable().optional().describe("Midpoint or insertion X (drawing units)."),
    y: z.number().nullable().optional().describe("Midpoint or insertion Y (drawing units)."),
    z: z.number().nullable().optional().describe("Midpoint or insertion Z (drawing units)."),
    partFamily: z.string().nullable().optional(),
    partSize: z.string().nullable().optional(),
  })
  .passthrough();

const PressureFittingRowSchema = z
  .object({
    networkName: z.string().nullable().optional(),
    handle: z.string().describe("AutoCAD object handle (hex)."),
    objectType: z.string().nullable().optional(),
    name: z.string().nullable().optional(),
    description: z.string().nullable().optional(),
    layer: z.string().nullable().optional(),
    x: z.number().nullable().optional(),
    y: z.number().nullable().optional(),
    z: z.number().nullable().optional(),
    partFamily: z.string().nullable().optional(),
    partSize: z.string().nullable().optional(),
  })
  .passthrough();

const PressureAppurtenanceRowSchema = z
  .object({
    networkName: z.string().nullable().optional(),
    handle: z.string().describe("AutoCAD object handle (hex)."),
    objectType: z.string().nullable().optional(),
    name: z.string().nullable().optional(),
    description: z.string().nullable().optional(),
    layer: z.string().nullable().optional(),
    x: z.number().nullable().optional(),
    y: z.number().nullable().optional(),
    z: z.number().nullable().optional(),
    partFamily: z.string().nullable().optional(),
    partSize: z.string().nullable().optional(),
  })
  .passthrough();

const ExportPressureNetworkResponseSchema = z
  .object({
    networkName: z.string().nullable().optional(),
    format: ExportFormatSchema.optional(),
    counts: z
      .object({
        pipes: z.number().int().nonnegative().optional(),
        fittings: z.number().int().nonnegative().optional(),
        appurtenances: z.number().int().nonnegative().optional(),
      })
      .passthrough()
      .optional(),
    pipes: z.array(PressurePipeRowSchema).optional(),
    fittings: z.array(PressureFittingRowSchema).optional(),
    appurtenances: z.array(PressureAppurtenanceRowSchema).optional(),
    csv: z
      .object({
        pipes: z.string().optional(),
        fittings: z.string().optional(),
        appurtenances: z.string().optional(),
      })
      .passthrough()
      .optional(),
    metadata: z
      .object({
        includePartsMetadata: z.boolean().optional(),
        matchedNetworks: z.array(z.string()).optional(),
        units: z.string().optional().describe("Drawing unit description, e.g. 'Meters'."),
      })
      .passthrough()
      .optional(),
  })
  .passthrough();

export function registerExportPressureNetworkTool(server: McpServer) {
  server.tool(
    "export_pressure_network",
    "Exports Civil 3D pressure network data (pipes/fittings/appurtenances) in traceable JSON/CSV payloads.",
    ExportPressureNetworkInputSchema.shape,
    async (args) => {
      try {
        const response = await withApplicationConnection(async (appClient) => {
          return await appClient.sendCommand("exportPressureNetwork", {
            networkName: args.networkName?.trim() || undefined,
            includePipes: args.includePipes ?? true,
            includeFittings: args.includeFittings ?? true,
            includeAppurtenances: args.includeAppurtenances ?? true,
            includePartsMetadata: args.includePartsMetadata ?? true,
            limit: args.limit ?? 5000,
            format: args.format ?? "json",
          });
        });

        const validatedResponse =
          ExportPressureNetworkResponseSchema.parse(response);

        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(validatedResponse, null, 2),
            },
          ],
        };
      } catch (error) {
        const errorMessage =
          error instanceof Error
            ? `Failed to export pressure network: ${error.message}`
            : "Failed to export pressure network";

        console.error("Error in export_pressure_network tool:", error);
        return {
          content: [
            {
              type: "text",
              text: errorMessage,
            },
          ],
          isError: true,
        };
      }
    }
  );
}
