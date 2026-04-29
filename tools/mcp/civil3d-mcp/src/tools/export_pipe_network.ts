import { z } from "zod";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { CIVIL3D_MCP_CONFIG } from "../config.js";
import { withApplicationConnection } from "../utils/ConnectionManager.js";

const ExportFormatSchema = z.enum(["json", "csv"]);

const ExportPipeNetworkInputSchema = z.object({
  networkName: z
    .string()
    .optional()
    .describe("Optional network name. When omitted, plugin may export all."),
  includeStructures: z
    .boolean()
    .optional()
    .describe("Include structures/manholes in export."),
  includePipes: z.boolean().optional().describe("Include pipes in export."),
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
// Typed row schemas for traceability — coordinates in drawing units (metres
// unless drawing units differ), slopes in percent, elevations in drawing units.
// Fields marked .nullable().optional() may be absent when the plugin cannot
// resolve the value from the Civil 3D object model.
// ---------------------------------------------------------------------------

const PipeRowSchema = z
  .object({
    networkName: z.string().nullable().optional(),
    handle: z.string().describe("AutoCAD object handle (hex)."),
    objectType: z.string().nullable().optional(),
    name: z.string().nullable().optional(),
    description: z.string().nullable().optional(),
    layer: z.string().nullable().optional(),
    startX: z.number().nullable().optional().describe("Start centre X (drawing units)."),
    startY: z.number().nullable().optional().describe("Start centre Y (drawing units)."),
    startZ: z.number().nullable().optional().describe("Start invert elevation (drawing units)."),
    endX: z.number().nullable().optional().describe("End centre X (drawing units)."),
    endY: z.number().nullable().optional().describe("End centre Y (drawing units)."),
    endZ: z.number().nullable().optional().describe("End invert elevation (drawing units)."),
    length2d: z.number().nonnegative().nullable().optional().describe("2D centre-to-centre length (drawing units)."),
    slopePercent: z.number().nullable().optional().describe("Hydraulic slope (%, positive = downhill)."),
    partFamily: z.string().nullable().optional(),
    partSize: z.string().nullable().optional(),
  })
  .passthrough();

const StructureRowSchema = z
  .object({
    networkName: z.string().nullable().optional(),
    handle: z.string().describe("AutoCAD object handle (hex)."),
    objectType: z.string().nullable().optional(),
    name: z.string().nullable().optional(),
    description: z.string().nullable().optional(),
    layer: z.string().nullable().optional(),
    x: z.number().nullable().optional().describe("Insertion X (drawing units)."),
    y: z.number().nullable().optional().describe("Insertion Y (drawing units)."),
    z: z.number().nullable().optional().describe("Insertion Z (drawing units)."),
    rimElevation: z.number().nullable().optional().describe("Rim/cover elevation (drawing units)."),
    sumpElevation: z.number().nullable().optional().describe("Sump elevation (drawing units)."),
    partFamily: z.string().nullable().optional(),
    partSize: z.string().nullable().optional(),
  })
  .passthrough();

const ExportPipeNetworkResponseSchema = z
  .object({
    networkName: z.string().nullable().optional(),
    format: ExportFormatSchema.optional(),
    counts: z
      .object({
        pipes: z.number().int().nonnegative().optional(),
        structures: z.number().int().nonnegative().optional(),
      })
      .passthrough()
      .optional(),
    pipes: z.array(PipeRowSchema).optional(),
    structures: z.array(StructureRowSchema).optional(),
    csv: z
      .object({
        pipes: z.string().optional(),
        structures: z.string().optional(),
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

export function registerExportPipeNetworkTool(server: McpServer) {
  server.tool(
    "export_pipe_network",
    "Exports Civil 3D gravity pipe network data (pipes/structures) in traceable JSON/CSV payloads.",
    ExportPipeNetworkInputSchema.shape,
    async (args) => {
      try {
        const response = await withApplicationConnection(async (appClient) => {
          return await appClient.sendCommand("exportPipeNetwork", {
            networkName: args.networkName?.trim() || undefined,
            includeStructures: args.includeStructures ?? true,
            includePipes: args.includePipes ?? true,
            includePartsMetadata: args.includePartsMetadata ?? true,
            limit: args.limit ?? 5000,
            format: args.format ?? "json",
          });
        });

        const validatedResponse = ExportPipeNetworkResponseSchema.parse(response);

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
            ? `Failed to export pipe network: ${error.message}`
            : "Failed to export pipe network";

        console.error("Error in export_pipe_network tool:", error);
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
