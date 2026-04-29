import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { registerGetConnectionStatusTool } from "./get_connection_status.js";
import { registerGetDrawingInfoTool } from "./get_drawing_info.js";
import { registerListCivilObjectTypesTool } from "./list_civil_object_types.js";
import { registerGetSelectedCivilObjectsInfoTool } from "./get_selected_civil_objects_info.js";
import { registerInspectObjectByHandleTool } from "./inspect_object_by_handle.js";
import { registerExportCogoPointsTool } from "./export_cogo_points.js";
import { registerCreateCogoPointsFromTextTool } from "./create_cogo_points_from_text.js";
import { registerExportPipeNetworkTool } from "./export_pipe_network.js";
import { registerExportPressureNetworkTool } from "./export_pressure_network.js";
import { registerValidatePipeNetworkTool } from "./validate_pipe_network.js";
import { registerValidateSurfaceFromTopoTool } from "./validate_surface_from_topo.js";
import { registerValidateSurfaceFromTopoV2Tool } from "./validate_surface_from_topo_v2.js";
import { registerRebuildSurfaceWithRulesTool } from "./rebuild_surface_with_rules.js";
import { registerCreateCogoPointTool } from "./create_cogo_point.js";
import { registerCreateLineSegmentTool } from "./create_line_segment.js";

export async function registerTools(server: McpServer) {
  registerGetConnectionStatusTool(server);
  registerGetDrawingInfoTool(server);
  registerListCivilObjectTypesTool(server);
  registerGetSelectedCivilObjectsInfoTool(server);
  registerInspectObjectByHandleTool(server);
  registerExportCogoPointsTool(server);
  registerCreateCogoPointsFromTextTool(server);
  registerExportPipeNetworkTool(server);
  registerExportPressureNetworkTool(server);
  registerValidatePipeNetworkTool(server);
  registerValidateSurfaceFromTopoTool(server);
  registerValidateSurfaceFromTopoV2Tool(server);
  registerRebuildSurfaceWithRulesTool(server);
  registerCreateCogoPointTool(server);
  registerCreateLineSegmentTool(server);
}
