import { z } from "zod";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { withApplicationConnection } from "../utils/ConnectionManager.js";

// ---------------------------------------------------------------------------
// Input schema
// ---------------------------------------------------------------------------

const ValidateSurfaceFromTopoV2InputSchema = z.object({
  surfaceName: z
    .string()
    .optional()
    .describe(
      "Target TIN surface name. If omitted, uses first surface found in drawing."
    ),
  maxTriangleEdgeLength: z
    .number()
    .positive()
    .optional()
    .describe(
      "Maximum acceptable TIN triangle edge length in drawing units. " +
        "Longer edges are reported as LONG_EDGE warnings."
    ),
  maxSlopePercent: z
    .number()
    .nonnegative()
    .optional()
    .describe(
      "Maximum acceptable triangle face slope (%). " +
        "Steeper faces are reported as STEEP_SLOPE warnings."
    ),
  detectPeaksSinks: z
    .boolean()
    .optional()
    .describe(
      "Detect anomalous peak and sink vertices (default: true). " +
        "Uses 3-sigma deviation from neighbor average elevation."
    ),
  breaklineLayerPatterns: z
    .array(z.string())
    .optional()
    .describe(
      "Layer wildcard patterns for expected breaklines (e.g. C-TOPO-BRK, LEVANT-*). " +
        "Used to flag surface zones with no nearby breakline support."
    ),
  maxIssues: z
    .number()
    .int()
    .positive()
    .optional()
    .describe("Maximum number of issues to return (default: 200)."),
});

// ---------------------------------------------------------------------------
// Response schema — strict per-issue contract for downstream annexes
// ---------------------------------------------------------------------------

const SurfaceIssueV2Schema = z
  .object({
    handle: z.string().describe("Drawing handle of the affected entity, or surface handle for triangle-level issues."),
    layer: z.string().describe("Layer of the affected entity."),
    type: z
      .enum([
        "LONG_EDGE",
        "STEEP_SLOPE",
        "PEAK",
        "SINK",
        "NO_BREAKLINE_ZONE",
        "SURFACE_NOT_FOUND",
        "API_UNAVAILABLE",
        "GENERAL",
      ])
      .describe("Machine-readable issue type."),
    severity: z
      .enum(["info", "warning", "error"])
      .describe("Issue severity."),
    description: z.string().describe("Human-readable description of the issue."),
  })
  .passthrough();

const V2MetricsSchema = z
  .object({
    trianglesChecked: z.number().int().nonnegative().optional(),
    longEdgesFound: z.number().int().nonnegative().optional(),
    steepSlopesFound: z.number().int().nonnegative().optional(),
    peaksFound: z.number().int().nonnegative().optional(),
    sinksFound: z.number().int().nonnegative().optional(),
    noBreaklineZones: z.number().int().nonnegative().optional(),
  })
  .passthrough();

const ValidateSurfaceFromTopoV2ResponseSchema = z
  .object({
    surfaceName: z.string().optional(),
    passed: z.boolean(),
    summary: z.string(),
    metrics: V2MetricsSchema.optional(),
    totalIssues: z.number().int().nonnegative(),
    issues: z.array(SurfaceIssueV2Schema),
  })
  .passthrough();

// ---------------------------------------------------------------------------
// Tool registration
// ---------------------------------------------------------------------------

export function registerValidateSurfaceFromTopoV2Tool(server: McpServer) {
  server.tool(
    "validate_surface_from_topo_v2",
    "Advanced TIN surface validation: long triangle edges, steep slope faces, " +
      "peak/sink anomalies, and zones lacking breakline support. " +
      "Returns a structured issue list suitable for technical annexes. " +
      "Requires triangle-level API access (Civil 3D 2024+); reports API_UNAVAILABLE otherwise.",
    ValidateSurfaceFromTopoV2InputSchema.shape,
    async (args) => {
      try {
        const response = await withApplicationConnection(async (appClient) => {
          return await appClient.sendCommand("validateSurfaceFromTopoV2", {
            surfaceName: args.surfaceName?.trim() || undefined,
            maxTriangleEdgeLength: args.maxTriangleEdgeLength,
            maxSlopePercent: args.maxSlopePercent,
            detectPeaksSinks: args.detectPeaksSinks ?? true,
            breaklineLayerPatterns: args.breaklineLayerPatterns ?? [],
            maxIssues: args.maxIssues ?? 200,
          });
        });

        const validatedResponse =
          ValidateSurfaceFromTopoV2ResponseSchema.parse(response);

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
            ? `Failed to validate surface (v2): ${error.message}`
            : "Failed to validate surface (v2)";

        console.error("Error in validate_surface_from_topo_v2 tool:", error);
        return {
          content: [{ type: "text", text: errorMessage }],
          isError: true,
        };
      }
    }
  );
}
