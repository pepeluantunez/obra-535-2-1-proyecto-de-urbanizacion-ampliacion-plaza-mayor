using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Reflection;
using System.Text.RegularExpressions;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading;
using System.Threading.Tasks;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.EditorInput;
using Autodesk.AutoCAD.Geometry;
using Autodesk.AutoCAD.Runtime;
using Autodesk.Civil.ApplicationServices;
using Autodesk.Civil.DatabaseServices;

[assembly: ExtensionApplication(typeof(Civil3DMcpPlugin.PluginEntry))]
[assembly: CommandClass(typeof(Civil3DMcpPlugin.PluginCommands))]

namespace Civil3DMcpPlugin;

public sealed class PluginEntry : IExtensionApplication
{
    internal const string BuildTag = "2026-04-29-surface-pipe-v3-validate2-breakline";
#if ALT_PORT_8081
    private const int Port = 8081;
#else
    private const int Port = 8080;
#endif
    private static readonly string[] AssemblySearchRoots =
    {
        @"C:\Program Files\Autodesk\AutoCAD 2026",
        @"C:\Program Files\Autodesk\AutoCAD 2026\C3D"
    };
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

    private TcpListener? _listener;
    private CancellationTokenSource? _cts;

    public void Initialize()
    {
        try
        {
            AppDomain.CurrentDomain.AssemblyResolve -= ResolveCivil3DAssembly;
            AppDomain.CurrentDomain.AssemblyResolve += ResolveCivil3DAssembly;
            _cts = new CancellationTokenSource();
            _listener = new TcpListener(IPAddress.Loopback, Port);
            _listener.Start();
            _ = Task.Run(() => AcceptLoopAsync(_cts.Token));
            WriteMessage($"\nCivil3DMcpPlugin [{BuildTag}] listening on 127.0.0.1:{Port}");
        }
        catch (System.Exception ex)
        {
            WriteMessage($"\nCivil3DMcpPlugin failed to start: {ex.Message}");
        }
    }

    public void Terminate()
    {
        try
        {
            AppDomain.CurrentDomain.AssemblyResolve -= ResolveCivil3DAssembly;
            _cts?.Cancel();
            _listener?.Stop();
        }
        catch
        {
        }
    }

    private static System.Reflection.Assembly? ResolveCivil3DAssembly(object? sender, ResolveEventArgs args)
    {
        try
        {
            var requestedName = new AssemblyName(args.Name).Name;
            if (string.IsNullOrWhiteSpace(requestedName))
            {
                return null;
            }

            foreach (var root in AssemblySearchRoots)
            {
                var candidate = Path.Combine(root, requestedName + ".dll");
                if (File.Exists(candidate))
                {
                    return System.Reflection.Assembly.LoadFrom(candidate);
                }
            }
        }
        catch
        {
        }

        return null;
    }

    private async Task AcceptLoopAsync(CancellationToken cancellationToken)
    {
        if (_listener is null)
        {
            return;
        }

        while (!cancellationToken.IsCancellationRequested)
        {
            TcpClient? client = null;
            try
            {
                client = await _listener.AcceptTcpClientAsync();
                _ = Task.Run(() => HandleClientAsync(client, cancellationToken), cancellationToken);
            }
            catch (ObjectDisposedException)
            {
                break;
            }
            catch (System.Exception ex)
            {
                client?.Dispose();
                WriteMessage($"\nCivil3DMcpPlugin accept error: {ex.Message}");
                await Task.Delay(250, cancellationToken).ConfigureAwait(false);
            }
        }
    }

    private async Task HandleClientAsync(TcpClient client, CancellationToken cancellationToken)
    {
        using (client)
        await using (var stream = client.GetStream())
        {
            RpcRequest? request = null;

            try
            {
                request = await ReadRequestAsync(stream, cancellationToken).ConfigureAwait(false);
                var result = ExecuteMethod(request.Method, request.Params);
                var response = new RpcResponse
                {
                    Id = request.Id,
                    Result = result
                };
                await WriteResponseAsync(stream, response, cancellationToken).ConfigureAwait(false);
            }
            catch (System.Exception ex)
            {
                var response = new RpcResponse
                {
                    Id = request?.Id,
                    Error = new RpcError
                    {
                        Code = -32000,
                        Message = ex.Message
                    }
                };
                await WriteResponseAsync(stream, response, cancellationToken).ConfigureAwait(false);
            }
        }
    }

    private static async Task<RpcRequest> ReadRequestAsync(NetworkStream stream, CancellationToken cancellationToken)
    {
        using var buffer = new MemoryStream();
        var chunk = new byte[4096];

        while (true)
        {
            var read = await stream.ReadAsync(chunk, 0, chunk.Length, cancellationToken).ConfigureAwait(false);
            if (read <= 0)
            {
                break;
            }

            buffer.Write(chunk, 0, read);
            if (TryParseRequest(buffer, out var request))
            {
                return request;
            }
        }

        throw new InvalidOperationException("No valid JSON-RPC request was received.");
    }

    private static bool TryParseRequest(MemoryStream stream, out RpcRequest request)
    {
        request = null!;
        try
        {
            var json = Encoding.UTF8.GetString(stream.ToArray());
            request = JsonSerializer.Deserialize<RpcRequest>(json, JsonOptions)
                ?? throw new InvalidOperationException("Empty request payload.");
            return true;
        }
        catch (JsonException)
        {
            return false;
        }
    }

    private static async Task WriteResponseAsync(NetworkStream stream, RpcResponse response, CancellationToken cancellationToken)
    {
        // Append '\n' so the TypeScript SocketClient can frame responses reliably
        // via its newline-split path, avoiding partial-JSON edge cases on large payloads.
        var payload = JsonSerializer.Serialize(response, JsonOptions) + "\n";
        var bytes = Encoding.UTF8.GetBytes(payload);
        await stream.WriteAsync(bytes, 0, bytes.Length, cancellationToken).ConfigureAwait(false);
        await stream.FlushAsync(cancellationToken).ConfigureAwait(false);
    }

    private static object ExecuteMethod(string method, JsonElement? args)
    {
        return WithDocument(doc =>
        {
            return method switch
            {
                "getDrawingInfo" => GetDrawingInfo(doc),
                "listCivilObjectTypes" => ListCivilObjectTypes(doc),
                "getSelectedCivilObjectsInfo" => GetSelectedCivilObjectsInfo(doc, args),
                "inspectObjectByHandle" => InspectObjectByHandle(doc, args),
                "exportCogoPoints" => ExportCogoPoints(doc, args),
                "createCogoPointsFromText" => CreateCogoPointsFromText(doc, args),
                "exportPipeNetwork" => ExportPipeNetwork(doc, args),
                "exportPressureNetwork" => ExportPressureNetwork(doc, args),
                "validatePipeNetwork" => ValidatePipeNetwork(doc, args),
                "validateSurfaceFromTopo" => ValidateSurfaceFromTopo(doc, args),
                "validateSurfaceFromTopoV2" => ValidateSurfaceFromTopoV2(doc, args),
                "rebuildSurfaceWithRules" => RebuildSurfaceWithRules(doc, args),
                "createCogoPoint" => CreateCogoPoint(doc, args),
                "createLineSegment" => CreateLineSegment(doc, args),
                _ => throw new InvalidOperationException($"Unsupported method: {method}")
            };
        });
    }

    private static object WithDocument(Func<DocumentContext, object> action)
    {
        var doc = Application.DocumentManager.MdiActiveDocument
            ?? throw new InvalidOperationException("No active Civil 3D document is open.");

        using var docLock = doc.LockDocument();
        using var tr = doc.TransactionManager.StartTransaction();
        var civilDoc = CivilApplication.ActiveDocument
            ?? throw new InvalidOperationException("No active Civil 3D document is available.");

        var context = new DocumentContext(doc, civilDoc, tr);
        var result = action(context);
        tr.Commit();
        return result;
    }

    private static object GetDrawingInfo(DocumentContext context)
    {
        var db = context.Document.Database;
        return new
        {
            drawingName = context.Document.Name,
            projectName = Path.GetFileNameWithoutExtension(context.Document.Name),
            coordinateSystem = TryGetCoordinateSystem(context.CivilDocument),
            units = db.Insunits.ToString()
        };
    }

    private static object ListCivilObjectTypes(DocumentContext context)
    {
        var names = new List<string>();

        AddIfPresent(names, context.CivilDocument, "GetAlignmentIds", "Alignment");
        AddIfPresent(names, context.CivilDocument, "GetSurfaceIds", "Surface");
        AddIfPresent(names, context.CivilDocument, "GetSiteIds", "Site");
        AddIfPresent(names, context.CivilDocument, "GetPipeNetworkIds", "PipeNetwork");
        AddIfPresent(names, context.CivilDocument, "GetPressurePipeNetworkIds", "PressurePipeNetwork");

        if (context.CivilDocument.CogoPoints.Count > 0)
        {
            names.Add("CogoPoint");
        }

        if (names.Count == 0)
        {
            names.Add("Drawing");
        }

        return names.Distinct(StringComparer.OrdinalIgnoreCase).ToArray();
    }

    private static object GetSelectedCivilObjectsInfo(DocumentContext context, JsonElement? args)
    {
        var limit = args.HasValue && args.Value.TryGetProperty("limit", out var limitProp)
            ? Math.Max(1, limitProp.GetInt32())
            : 100;

        var result = context.Document.Editor.SelectImplied();
        if (result.Status != PromptStatus.OK || result.Value is null)
        {
            return Array.Empty<object>();
        }

        var items = new List<object>();
        foreach (SelectedObject selected in result.Value)
        {
            if (selected is null)
            {
                continue;
            }

            var dbObj = context.Transaction.GetObject(selected.ObjectId, OpenMode.ForRead, false);
            items.Add(BuildSelectedObjectInfo(dbObj));

            if (items.Count >= limit)
            {
                break;
            }
        }

        return items;
    }

    private static object InspectObjectByHandle(DocumentContext context, JsonElement? args)
    {
        if (!args.HasValue)
        {
            throw new InvalidOperationException("Missing inspectObjectByHandle parameters.");
        }

        var handleText = GetOptionalString(args.Value, "handle");
        if (string.IsNullOrWhiteSpace(handleText))
        {
            throw new InvalidOperationException("Missing required parameter: handle");
        }

        if (!TryResolveObjectIdByHandle(context.Document.Database, handleText, out var objectId))
        {
            throw new InvalidOperationException($"Handle not found in drawing: {handleText}");
        }

        var includeProperties = GetOptionalBool(args.Value, "includeProperties") ?? true;
        var allowlist = (GetOptionalStringArray(args.Value, "propertyFilter") ?? Array.Empty<string>())
            .Where(s => !string.IsNullOrWhiteSpace(s))
            .ToHashSet(StringComparer.OrdinalIgnoreCase);

        var dbObj = context.Transaction.GetObject(objectId, OpenMode.ForRead, false);
        var details = new Dictionary<string, object?>();
        if (includeProperties)
        {
            foreach (var prop in dbObj.GetType().GetProperties(BindingFlags.Public | BindingFlags.Instance))
            {
                if (!prop.CanRead || prop.GetIndexParameters().Length > 0)
                {
                    continue;
                }

                if (allowlist.Count > 0 && !allowlist.Contains(prop.Name))
                {
                    continue;
                }

                try
                {
                    var value = prop.GetValue(dbObj);
                    details[prop.Name] = ToSerializableValue(value);
                }
                catch
                {
                }
            }
        }

        return new
        {
            handle = dbObj.Handle.ToString(),
            objectType = dbObj.GetType().Name,
            name = TryGetStringProperty(dbObj, "Name"),
            layer = TryGetStringProperty(dbObj, "Layer"),
            properties = includeProperties ? details : null
        };
    }

    private static object ExportCogoPoints(DocumentContext context, JsonElement? args)
    {
        var pointGroupName = args.HasValue ? GetOptionalString(args.Value, "pointGroupName") : null;
        var includeUdp = args.HasValue ? (GetOptionalBool(args.Value, "includeUserDefinedProperties") ?? true) : true;
        var limit = args.HasValue ? (GetOptionalInt(args.Value, "limit") ?? 5000) : 5000;
        var format = args.HasValue ? (GetOptionalString(args.Value, "format") ?? "json") : "json";

        var points = new List<Dictionary<string, object?>>();
        foreach (ObjectId pointId in context.CivilDocument.CogoPoints)
        {
            if (points.Count >= limit)
            {
                break;
            }

            var point = context.Transaction.GetObject(pointId, OpenMode.ForRead) as CogoPoint;
            if (point is null)
            {
                continue;
            }

            var row = new Dictionary<string, object?>
            {
                ["handle"] = point.Handle.ToString(),
                ["pointNumber"] = point.PointNumber,
                ["easting"] = point.Easting,
                ["northing"] = point.Northing,
                ["elevation"] = point.Elevation,
                ["rawDescription"] = point.RawDescription,
                ["fullDescription"] = point.FullDescription
            };

            if (includeUdp)
            {
                row["userDefinedProperties"] = TryReadUserDefinedProperties(point);
            }

            points.Add(row);
        }

        return new
        {
            format,
            count = points.Count,
            points,
            csv = string.Equals(format, "csv", StringComparison.OrdinalIgnoreCase)
                ? BuildCsv(points, new[] { "handle", "pointNumber", "easting", "northing", "elevation", "rawDescription", "fullDescription" })
                : null,
            metadata = new
            {
                pointGroupName,
                pointGroupFilterApplied = false,
                note = string.IsNullOrWhiteSpace(pointGroupName)
                    ? null
                    : "Point group filter is not yet enforced in plugin; exporting all drawing COGO points."
            }
        };
    }

    private static object CreateCogoPointsFromText(DocumentContext context, JsonElement? args)
    {
        var layerPatterns = args.HasValue ? (GetOptionalStringArray(args.Value, "layerPatterns") ?? Array.Empty<string>()) : Array.Empty<string>();
        var textRegex = args.HasValue ? (GetOptionalString(args.Value, "textRegex") ?? @"[-+]?\d+(?:[.,]\d+)?") : @"[-+]?\d+(?:[.,]\d+)?";
        var decimalSeparatorMode = (args.HasValue ? GetOptionalString(args.Value, "decimalSeparatorMode") : null) ?? "auto";
        var minElevation = args.HasValue ? GetOptionalDouble(args.Value, "minElevation") : null;
        var maxElevation = args.HasValue ? GetOptionalDouble(args.Value, "maxElevation") : null;
        var dedupeToleranceXY = args.HasValue ? (GetOptionalDouble(args.Value, "dedupeToleranceXY") ?? 0.01) : 0.01;
        var dryRun = args.HasValue ? (GetOptionalBool(args.Value, "dryRun") ?? true) : true;
        var rawDescription = args.HasValue ? (GetOptionalString(args.Value, "rawDescription") ?? "TXT_ELEV") : "TXT_ELEV";

        if (minElevation.HasValue && maxElevation.HasValue && minElevation.Value > maxElevation.Value)
        {
            throw new InvalidOperationException("minElevation must be <= maxElevation");
        }

        var regex = new Regex(textRegex, RegexOptions.Compiled | RegexOptions.CultureInvariant);
        var warnings = new List<string>();
        var createdSamples = new List<Dictionary<string, object?>>();
        var skippedSamples = new List<Dictionary<string, object?>>();
        var candidatePoints = new List<(double x, double y, double z, string sourceHandle, string sourceLayer, string sourceText)>();

        var db = context.Document.Database;
        var btr = (BlockTableRecord)context.Transaction.GetObject(db.CurrentSpaceId, OpenMode.ForRead);

        var scannedTexts = 0;
        var skippedCount = 0;

        foreach (ObjectId entityId in btr)
        {
            var entity = context.Transaction.GetObject(entityId, OpenMode.ForRead, false) as Autodesk.AutoCAD.DatabaseServices.Entity;
            if (entity is null)
            {
                continue;
            }

            if (!(entity is DBText) && !(entity is MText))
            {
                continue;
            }

            scannedTexts++;

            if (layerPatterns.Length > 0 && !LayerMatches(entity.Layer, layerPatterns))
            {
                skippedCount++;
                AddSkippedSample(skippedSamples, entity.Handle.ToString(), entity.Layer, "layer_filtered", null);
                continue;
            }

            var sourceText = TryGetTextValue(entity);
            if (string.IsNullOrWhiteSpace(sourceText))
            {
                skippedCount++;
                AddSkippedSample(skippedSamples, entity.Handle.ToString(), entity.Layer, "empty_text", null);
                continue;
            }

            if (!TryParseElevationFromText(sourceText!, regex, decimalSeparatorMode, out var elevation, out var token))
            {
                skippedCount++;
                AddSkippedSample(skippedSamples, entity.Handle.ToString(), entity.Layer, "no_numeric_match", sourceText);
                continue;
            }

            if (minElevation.HasValue && elevation < minElevation.Value)
            {
                skippedCount++;
                AddSkippedSample(skippedSamples, entity.Handle.ToString(), entity.Layer, "below_min_elevation", token);
                continue;
            }

            if (maxElevation.HasValue && elevation > maxElevation.Value)
            {
                skippedCount++;
                AddSkippedSample(skippedSamples, entity.Handle.ToString(), entity.Layer, "above_max_elevation", token);
                continue;
            }

            if (!TryGetPoint3d(entity, out var point))
            {
                skippedCount++;
                AddSkippedSample(skippedSamples, entity.Handle.ToString(), entity.Layer, "no_insertion_point", token);
                continue;
            }

            if (candidatePoints.Any(p => Dist2d(p.x, p.y, point.X, point.Y) <= dedupeToleranceXY))
            {
                skippedCount++;
                AddSkippedSample(skippedSamples, entity.Handle.ToString(), entity.Layer, "duplicate_xy", token);
                continue;
            }

            candidatePoints.Add((point.X, point.Y, elevation, entity.Handle.ToString(), entity.Layer, sourceText!));
        }

        var createdCount = 0;
        if (!dryRun)
        {
            foreach (var candidate in candidatePoints)
            {
                var createdId = TryAddCogoPoint(
                    context.CivilDocument.CogoPoints,
                    new Point3d(candidate.x, candidate.y, candidate.z),
                    rawDescription);
                var created = context.Transaction.GetObject(createdId, OpenMode.ForRead) as CogoPoint;
                createdCount++;
                if (createdSamples.Count < 10)
                {
                    createdSamples.Add(new Dictionary<string, object?>
                    {
                        ["sourceHandle"] = candidate.sourceHandle,
                        ["sourceLayer"] = candidate.sourceLayer,
                        ["pointNumber"] = created?.PointNumber,
                        ["easting"] = candidate.x,
                        ["northing"] = candidate.y,
                        ["elevation"] = candidate.z
                    });
                }
            }
        }
        else
        {
            createdCount = candidatePoints.Count;
            foreach (var candidate in candidatePoints.Take(10))
            {
                createdSamples.Add(new Dictionary<string, object?>
                {
                    ["sourceHandle"] = candidate.sourceHandle,
                    ["sourceLayer"] = candidate.sourceLayer,
                    ["easting"] = candidate.x,
                    ["northing"] = candidate.y,
                    ["elevation"] = candidate.z
                });
            }
        }

        if (string.Equals(decimalSeparatorMode, "auto", StringComparison.OrdinalIgnoreCase))
        {
            warnings.Add("decimalSeparatorMode=auto may misinterpret ambiguous tokens like 1.234 in mixed locale drawings.");
        }

        return new
        {
            dryRun,
            scannedTexts,
            createdCount,
            skippedCount,
            dedupeToleranceXY,
            rawDescription,
            createdSamples,
            skippedSamples,
            warnings
        };
    }

    private static object ExportPipeNetwork(DocumentContext context, JsonElement? args)
    {
        var networkNameFilter = args.HasValue ? GetOptionalString(args.Value, "networkName") : null;
        var includeStructures = args.HasValue ? (GetOptionalBool(args.Value, "includeStructures") ?? true) : true;
        var includePipes = args.HasValue ? (GetOptionalBool(args.Value, "includePipes") ?? true) : true;
        var includePartsMetadata = args.HasValue ? (GetOptionalBool(args.Value, "includePartsMetadata") ?? true) : true;
        var limit = args.HasValue ? (GetOptionalInt(args.Value, "limit") ?? 5000) : 5000;
        var format = args.HasValue ? (GetOptionalString(args.Value, "format") ?? "json") : "json";

        var pipes = new List<Dictionary<string, object?>>();
        var structures = new List<Dictionary<string, object?>>();
        var matchedNetworkNames = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var networkId in EnumerateCivilObjectIds(context.CivilDocument, "GetPipeNetworkIds"))
        {
            var networkObj = context.Transaction.GetObject(networkId, OpenMode.ForRead, false);
            var networkName = TryGetStringProperty(networkObj, "Name") ?? networkId.Handle.ToString();
            if (!string.IsNullOrWhiteSpace(networkNameFilter) &&
                !string.Equals(networkNameFilter, networkName, StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            matchedNetworkNames.Add(networkName);

            if (includePipes)
            {
                foreach (var pipeId in EnumerateObjectIds(networkObj, "GetPipeIds", "PipeIds"))
                {
                    if (pipes.Count >= limit)
                    {
                        break;
                    }

                    var dbObj = context.Transaction.GetObject(pipeId, OpenMode.ForRead, false);
                    pipes.Add(BuildPipeRow(dbObj, networkName, includePartsMetadata));
                }
            }

            if (includeStructures)
            {
                foreach (var structId in EnumerateObjectIds(networkObj, "GetStructureIds", "StructureIds"))
                {
                    if (structures.Count >= limit)
                    {
                        break;
                    }

                    var dbObj = context.Transaction.GetObject(structId, OpenMode.ForRead, false);
                    structures.Add(BuildStructureRow(dbObj, networkName, includePartsMetadata));
                }
            }
        }

        return new
        {
            networkName = matchedNetworkNames.Count == 1 ? matchedNetworkNames.First() : networkNameFilter,
            format,
            counts = new { pipes = pipes.Count, structures = structures.Count },
            pipes,
            structures,
            csv = string.Equals(format, "csv", StringComparison.OrdinalIgnoreCase)
                ? new
                {
                    pipes = BuildCsv(pipes, new[] { "networkName", "handle", "name", "startX", "startY", "startZ", "endX", "endY", "endZ", "length2d", "slopePercent", "partFamily", "partSize" }),
                    structures = BuildCsv(structures, new[] { "networkName", "handle", "name", "x", "y", "z", "rimElevation", "sumpElevation", "partFamily", "partSize" })
                }
                : null,
            metadata = new
            {
                includePartsMetadata,
                matchedNetworks = matchedNetworkNames.OrderBy(x => x).ToArray(),
                units = context.Document.Database.Insunits.ToString()
            }
        };
    }

    private static object ExportPressureNetwork(DocumentContext context, JsonElement? args)
    {
        var networkNameFilter = args.HasValue ? GetOptionalString(args.Value, "networkName") : null;
        var includePipes = args.HasValue ? (GetOptionalBool(args.Value, "includePipes") ?? true) : true;
        var includeFittings = args.HasValue ? (GetOptionalBool(args.Value, "includeFittings") ?? true) : true;
        var includeAppurtenances = args.HasValue ? (GetOptionalBool(args.Value, "includeAppurtenances") ?? true) : true;
        var includePartsMetadata = args.HasValue ? (GetOptionalBool(args.Value, "includePartsMetadata") ?? true) : true;
        var limit = args.HasValue ? (GetOptionalInt(args.Value, "limit") ?? 5000) : 5000;
        var format = args.HasValue ? (GetOptionalString(args.Value, "format") ?? "json") : "json";

        var pipes = new List<Dictionary<string, object?>>();
        var fittings = new List<Dictionary<string, object?>>();
        var appurtenances = new List<Dictionary<string, object?>>();
        var matchedNetworkNames = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var networkId in EnumerateCivilObjectIds(context.CivilDocument, "GetPressurePipeNetworkIds"))
        {
            var networkObj = context.Transaction.GetObject(networkId, OpenMode.ForRead, false);
            var networkName = TryGetStringProperty(networkObj, "Name") ?? networkId.Handle.ToString();
            if (!string.IsNullOrWhiteSpace(networkNameFilter) &&
                !string.Equals(networkNameFilter, networkName, StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            matchedNetworkNames.Add(networkName);

            if (includePipes)
            {
                foreach (var objectId in EnumerateObjectIds(networkObj, "GetPipeIds", "GetPressurePipeIds", "PressurePipeIds", "PipeIds"))
                {
                    if (pipes.Count >= limit)
                    {
                        break;
                    }

                    var dbObj = context.Transaction.GetObject(objectId, OpenMode.ForRead, false);
                    pipes.Add(BuildGenericNetworkRow(dbObj, networkName, includePartsMetadata));
                }
            }

            if (includeFittings)
            {
                foreach (var objectId in EnumerateObjectIds(networkObj, "GetFittingIds", "GetPressureFittingIds", "FittingIds"))
                {
                    if (fittings.Count >= limit)
                    {
                        break;
                    }

                    var dbObj = context.Transaction.GetObject(objectId, OpenMode.ForRead, false);
                    fittings.Add(BuildGenericNetworkRow(dbObj, networkName, includePartsMetadata));
                }
            }

            if (includeAppurtenances)
            {
                foreach (var objectId in EnumerateObjectIds(networkObj, "GetAppurtenanceIds", "GetPressureAppurtenanceIds", "AppurtenanceIds"))
                {
                    if (appurtenances.Count >= limit)
                    {
                        break;
                    }

                    var dbObj = context.Transaction.GetObject(objectId, OpenMode.ForRead, false);
                    appurtenances.Add(BuildGenericNetworkRow(dbObj, networkName, includePartsMetadata));
                }
            }
        }

        return new
        {
            networkName = matchedNetworkNames.Count == 1 ? matchedNetworkNames.First() : networkNameFilter,
            format,
            counts = new { pipes = pipes.Count, fittings = fittings.Count, appurtenances = appurtenances.Count },
            pipes,
            fittings,
            appurtenances,
            csv = string.Equals(format, "csv", StringComparison.OrdinalIgnoreCase)
                ? new
                {
                    pipes = BuildCsv(pipes, new[] { "networkName", "handle", "objectType", "name", "x", "y", "z", "partFamily", "partSize" }),
                    fittings = BuildCsv(fittings, new[] { "networkName", "handle", "objectType", "name", "x", "y", "z", "partFamily", "partSize" }),
                    appurtenances = BuildCsv(appurtenances, new[] { "networkName", "handle", "objectType", "name", "x", "y", "z", "partFamily", "partSize" })
                }
                : null,
            metadata = new
            {
                includePartsMetadata,
                matchedNetworks = matchedNetworkNames.OrderBy(x => x).ToArray(),
                units = context.Document.Database.Insunits.ToString()
            }
        };
    }

    private static object ValidatePipeNetwork(DocumentContext context, JsonElement? args)
    {
        var networkNameFilter = args.HasValue ? GetOptionalString(args.Value, "networkName") : null;
        var minSlopePercent = args.HasValue ? GetOptionalDouble(args.Value, "minSlopePercent") : null;
        var checkConnectivity = args.HasValue ? (GetOptionalBool(args.Value, "checkConnectivity") ?? true) : true;
        var checkFlowDirection = args.HasValue ? (GetOptionalBool(args.Value, "checkFlowDirection") ?? true) : true;

        var issues = new List<Dictionary<string, object?>>();
        var matchedNetworkNames = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var networkId in EnumerateCivilObjectIds(context.CivilDocument, "GetPipeNetworkIds"))
        {
            var networkObj = context.Transaction.GetObject(networkId, OpenMode.ForRead, false);
            var networkName = TryGetStringProperty(networkObj, "Name") ?? networkId.Handle.ToString();
            if (!string.IsNullOrWhiteSpace(networkNameFilter) &&
                !string.Equals(networkNameFilter, networkName, StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            matchedNetworkNames.Add(networkName);

            foreach (var pipeId in EnumerateObjectIds(networkObj, "GetPipeIds", "PipeIds"))
            {
                if (context.Transaction.GetObject(pipeId, OpenMode.ForRead, false) is not Pipe pipe)
                {
                    continue;
                }

                var slopePercent = 0.0;
                try
                {
                    slopePercent = ((pipe.EndPoint.Z - pipe.StartPoint.Z) / pipe.Length2DCenterToCenter) * 100.0;
                }
                catch
                {
                }

                if (minSlopePercent.HasValue && Math.Abs(slopePercent) < minSlopePercent.Value)
                {
                    issues.Add(new Dictionary<string, object?>
                    {
                        ["code"] = "PIPE_MIN_SLOPE",
                        ["severity"] = "warning",
                        ["message"] = $"Pipe slope {slopePercent:F3}% is below minimum {minSlopePercent.Value:F3}%",
                        ["objectHandle"] = pipe.Handle.ToString(),
                        ["objectType"] = pipe.GetType().Name
                    });
                }

                if (checkFlowDirection && pipe.StartPoint.Z < pipe.EndPoint.Z)
                {
                    issues.Add(new Dictionary<string, object?>
                    {
                        ["code"] = "PIPE_FLOW_DIRECTION",
                        ["severity"] = "warning",
                        ["message"] = "Pipe appears to run uphill (start elevation lower than end elevation).",
                        ["objectHandle"] = pipe.Handle.ToString(),
                        ["objectType"] = pipe.GetType().Name
                    });
                }

                if (checkConnectivity)
                {
                    var startStructId = TryGetObjectIdProperty(pipe, "StartStructureId");
                    var endStructId = TryGetObjectIdProperty(pipe, "EndStructureId");
                    if (!startStructId.HasValue || startStructId.Value.IsNull || !endStructId.HasValue || endStructId.Value.IsNull)
                    {
                        issues.Add(new Dictionary<string, object?>
                        {
                            ["code"] = "PIPE_CONNECTIVITY",
                            ["severity"] = "warning",
                            ["message"] = "Pipe has missing start/end structure association.",
                            ["objectHandle"] = pipe.Handle.ToString(),
                            ["objectType"] = pipe.GetType().Name
                        });
                    }
                }
            }
        }

        var hasErrors = issues.Any(i => string.Equals(Convert.ToString(i.GetValueOrDefault("severity")), "error", StringComparison.OrdinalIgnoreCase));
        return new
        {
            networkName = matchedNetworkNames.Count == 1 ? matchedNetworkNames.First() : networkNameFilter,
            passed = !hasErrors,
            totalIssues = issues.Count,
            issues,
            summary = $"Checked {matchedNetworkNames.Count} network(s). Found {issues.Count} issue(s)."
        };
    }

    private static object ValidateSurfaceFromTopo(DocumentContext context, JsonElement? args)
    {
        var surfaceName = args.HasValue ? GetOptionalString(args.Value, "surfaceName") : null;
        var breaklinePatterns = args.HasValue ? (GetOptionalStringArray(args.Value, "breaklineLayerPatterns") ?? Array.Empty<string>()) : Array.Empty<string>();
        var maxTriangleEdgeLength = args.HasValue ? GetOptionalDouble(args.Value, "maxTriangleEdgeLength") : null;
        var maxSlopePercent = args.HasValue ? GetOptionalDouble(args.Value, "maxSlopePercent") : null;
        var detectOutliers = args.HasValue ? (GetOptionalBool(args.Value, "detectOutliers") ?? true) : true;
        var includeSampleIssues = args.HasValue ? (GetOptionalBool(args.Value, "includeSampleIssues") ?? true) : true;

        var issues = new List<Dictionary<string, object?>>();
        var surface = TryGetSurface(context, surfaceName);
        if (surface is null)
        {
            issues.Add(new Dictionary<string, object?>
            {
                ["code"] = "SURFACE_NOT_FOUND",
                ["severity"] = "error",
                ["message"] = string.IsNullOrWhiteSpace(surfaceName)
                    ? "No surface found in drawing."
                    : $"Surface not found: {surfaceName}"
            });

            return new
            {
                surfaceName,
                passed = false,
                totalIssues = issues.Count,
                issues,
                summary = "Surface validation failed: no target surface."
            };
        }

        var actualSurfaceName = TryGetStringProperty(surface, "Name") ?? surfaceName;

        var pointsCount = context.CivilDocument.CogoPoints.Count;
        var minElevation = TryGetDoubleProperty(surface, "MinimumElevation");
        var maxElevation = TryGetDoubleProperty(surface, "MaximumElevation");

        var breaklineCount = CountBreaklineCandidates(context, breaklinePatterns);
        if (breaklinePatterns.Length > 0 && breaklineCount == 0)
        {
            issues.Add(new Dictionary<string, object?>
            {
                ["code"] = "BREAKLINES_NOT_FOUND",
                ["severity"] = "warning",
                ["message"] = "No breakline candidate entities were found for the provided layer patterns."
            });
        }

        if (maxTriangleEdgeLength.HasValue)
        {
            issues.Add(new Dictionary<string, object?>
            {
                ["code"] = "TRIANGLE_EDGE_CHECK_LIMITED",
                ["severity"] = "info",
                ["message"] = "Triangle max-edge check is not fully available in this plugin build.",
                ["details"] = new Dictionary<string, object?> { ["requestedMaxTriangleEdgeLength"] = maxTriangleEdgeLength.Value }
            });
        }

        if (maxSlopePercent.HasValue)
        {
            issues.Add(new Dictionary<string, object?>
            {
                ["code"] = "TRIANGLE_SLOPE_CHECK_LIMITED",
                ["severity"] = "info",
                ["message"] = "Triangle slope check is not fully available in this plugin build.",
                ["details"] = new Dictionary<string, object?> { ["requestedMaxSlopePercent"] = maxSlopePercent.Value }
            });
        }

        if (detectOutliers)
        {
            var outlierInfo = DetectCogoElevationOutliers(context, includeSampleIssues ? 10 : 0);
            if (outlierInfo.totalOutliers > 0)
            {
                issues.Add(new Dictionary<string, object?>
                {
                    ["code"] = "COGO_ELEVATION_OUTLIERS",
                    ["severity"] = "warning",
                    ["message"] = $"Detected {outlierInfo.totalOutliers} potential elevation outlier(s) among COGO points.",
                    ["details"] = new Dictionary<string, object?>
                    {
                        ["medianElevation"] = outlierInfo.median,
                        ["mad"] = outlierInfo.mad,
                        ["thresholdMultiplier"] = 4.5
                    }
                });

                foreach (var sample in outlierInfo.samples)
                {
                    issues.Add(new Dictionary<string, object?>
                    {
                        ["code"] = "COGO_ELEVATION_OUTLIER_SAMPLE",
                        ["severity"] = "info",
                        ["message"] = $"Sample outlier point {sample.pointNumber}: elevation {sample.elevation:F3}",
                        ["objectHandle"] = sample.handle,
                        ["objectType"] = "CogoPoint"
                    });
                }
            }
        }

        var trianglesCount = TryGetIntProperty(surface, "TrianglesCount");
        var hasErrors = issues.Any(i => string.Equals(Convert.ToString(i.GetValueOrDefault("severity")), "error", StringComparison.OrdinalIgnoreCase));

        return new
        {
            surfaceName = actualSurfaceName,
            passed = !hasErrors,
            summary = $"Validated surface '{actualSurfaceName}'. Points: {pointsCount}, breakline candidates: {breaklineCount}, issues: {issues.Count}.",
            metrics = new
            {
                pointsCount,
                breaklinesCount = breaklineCount,
                trianglesCount,
                minElevation,
                maxElevation,
                longestTriangleEdge = (double?)null
            },
            totalIssues = issues.Count,
            issues
        };
    }

    // -----------------------------------------------------------------------
    // ValidateSurfaceFromTopoV2
    // -----------------------------------------------------------------------
    // Advanced surface QA: long triangle edges, steep slopes, peak/sink
    // anomalies, breakline coverage gaps.
    // Returns a list of typed issues: { handle, layer, type, severity, description }.
    // Triangle-level analysis requires TinSurface.GetTriangles() to be available
    // in the loaded Civil 3D assemblies; falls back to API_UNAVAILABLE if not.
    // -----------------------------------------------------------------------

    private static object ValidateSurfaceFromTopoV2(DocumentContext context, JsonElement? args)
    {
        var surfaceName        = args.HasValue ? GetOptionalString(args.Value, "surfaceName") : null;
        var maxEdgeLength      = args.HasValue ? GetOptionalDouble(args.Value, "maxTriangleEdgeLength") : null;
        var maxSlopePercent    = args.HasValue ? GetOptionalDouble(args.Value, "maxSlopePercent") : null;
        var detectPeaksSinks   = args.HasValue ? (GetOptionalBool(args.Value, "detectPeaksSinks") ?? true) : true;
        var blPatterns         = args.HasValue ? (GetOptionalStringArray(args.Value, "breaklineLayerPatterns") ?? Array.Empty<string>()) : Array.Empty<string>();
        var maxIssues          = args.HasValue ? (GetOptionalInt(args.Value, "maxIssues") ?? 200) : 200;

        var issues = new List<Dictionary<string, object?>>();

        var surface = TryGetSurface(context, surfaceName);
        if (surface is null)
        {
            var msg = string.IsNullOrWhiteSpace(surfaceName)
                ? "No TIN surface found in drawing."
                : $"Surface not found: {surfaceName}";
            issues.Add(MakeIssue("?", "0", "SURFACE_NOT_FOUND", "error", msg));
            return BuildV2Result(surfaceName, false, msg, null, issues);
        }

        var surfaceHandle = (surface as Autodesk.AutoCAD.DatabaseServices.DBObject)?.Handle.ToString() ?? "?";
        var surfaceLayer  = TryGetStringProperty(surface, "Layer") ?? "0";
        var actualName    = TryGetStringProperty(surface, "Name") ?? surfaceName ?? "Unknown";

        var metrics = new Dictionary<string, object?>
        {
            ["trianglesChecked"] = (int?)null,
            ["longEdgesFound"]   = (int?)null,
            ["steepSlopesFound"] = (int?)null,
            ["peaksFound"]       = (int?)null,
            ["sinksFound"]       = (int?)null,
            ["noBreaklineZones"] = (int?)null,
        };

        // ------------------------------------------------------------------
        // Triangle-level analysis
        // ------------------------------------------------------------------
        var triangles = TryExtractTinTriangleVertices(surface);
        if (triangles is not null && triangles.Count > 0)
        {
            metrics["trianglesChecked"] = triangles.Count;
            var longEdges   = 0;
            var steepSlopes = 0;

            foreach (var tri in triangles)
            {
                // Long-edge check
                if (maxEdgeLength.HasValue)
                {
                    var e1 = Dist2d(tri.v1.X, tri.v1.Y, tri.v2.X, tri.v2.Y);
                    var e2 = Dist2d(tri.v2.X, tri.v2.Y, tri.v3.X, tri.v3.Y);
                    var e3 = Dist2d(tri.v1.X, tri.v1.Y, tri.v3.X, tri.v3.Y);
                    var maxE = Math.Max(e1, Math.Max(e2, e3));
                    if (maxE > maxEdgeLength.Value && issues.Count < maxIssues)
                    {
                        longEdges++;
                        issues.Add(MakeIssue(surfaceHandle, surfaceLayer, "LONG_EDGE", "warning",
                            $"Triangle edge {maxE:F2} units exceeds maximum {maxEdgeLength.Value:F2} units."));
                    }
                }

                // Steep slope check
                if (maxSlopePercent.HasValue)
                {
                    var slope = ComputeTriangleMaxSlopePercent(tri.v1, tri.v2, tri.v3);
                    if (slope > maxSlopePercent.Value && issues.Count < maxIssues)
                    {
                        steepSlopes++;
                        issues.Add(MakeIssue(surfaceHandle, surfaceLayer, "STEEP_SLOPE", "warning",
                            $"Triangle slope {slope:F1}% exceeds maximum {maxSlopePercent.Value:F1}%."));
                    }
                }
            }

            metrics["longEdgesFound"]   = longEdges;
            metrics["steepSlopesFound"] = steepSlopes;

            // Peak / sink detection
            if (detectPeaksSinks)
            {
                var (peaks, sinks) = DetectPeaksSinksFromTriangles(triangles, issues, maxIssues, surfaceHandle, surfaceLayer);
                metrics["peaksFound"] = peaks;
                metrics["sinksFound"] = sinks;
            }

            // Breakline coverage
            if (blPatterns.Length > 0)
            {
                var noZones = CheckBreaklineCoverage(context, triangles, blPatterns, issues, maxIssues, surfaceHandle, surfaceLayer);
                metrics["noBreaklineZones"] = noZones;
            }
        }
        else
        {
            // Triangle-level API not available in this build / surface type
            issues.Add(MakeIssue(surfaceHandle, surfaceLayer, "API_UNAVAILABLE", "info",
                "TIN triangle enumeration is not available via this Civil 3D build or surface type. " +
                "Triangle-level checks (long edges, steep slopes, peaks/sinks) were skipped. " +
                "Upgrade to Civil 3D 2024+ and ensure AeccDbMgd exposes TinSurface.GetTriangles()."));

            // Fallback: peak/sink from COGO points if present
            if (detectPeaksSinks)
            {
                var outlierInfo = DetectCogoElevationOutliers(context, 20);
                if (outlierInfo.totalOutliers > 0)
                {
                    issues.Add(MakeIssue(surfaceHandle, surfaceLayer, "PEAK",
                        "warning",
                        $"Fallback outlier detection (COGO): {outlierInfo.totalOutliers} anomalous elevation(s) " +
                        $"detected via MAD (median={outlierInfo.median:F3}, MAD={outlierInfo.mad:F3}, threshold=4.5×MAD)."));
                    metrics["peaksFound"] = outlierInfo.totalOutliers;
                }
            }
        }

        var hasErrors = issues.Any(i =>
            string.Equals(Convert.ToString(i.GetValueOrDefault("severity")), "error", StringComparison.OrdinalIgnoreCase));

        var summary = BuildV2SummaryText(actualName, metrics, issues.Count);
        return BuildV2Result(actualName, !hasErrors, summary, metrics, issues);
    }

    // ------------------------------------------------------------------
    // Triangle extraction via reflection (safe across C3D versions)
    // ------------------------------------------------------------------

    private static List<(Point3d v1, Point3d v2, Point3d v3)>? TryExtractTinTriangleVertices(object surface)
    {
        // Strategy 1: GetTriangles() no args
        var method = surface.GetType().GetMethod(
            "GetTriangles",
            BindingFlags.Instance | BindingFlags.Public,
            null,
            Type.EmptyTypes,
            null);

        // Strategy 2: GetTriangles(bool visibleOnly)
        if (method is null)
        {
            method = surface.GetType().GetMethod(
                "GetTriangles",
                BindingFlags.Instance | BindingFlags.Public,
                null,
                new[] { typeof(bool) },
                null);
        }

        object? collection = null;
        if (method is not null)
        {
            try
            {
                collection = method.GetParameters().Length == 0
                    ? method.Invoke(surface, null)
                    : method.Invoke(surface, new object[] { true });
            }
            catch { /* fall through to property strategy */ }
        }

        // Strategy 3: Triangles property
        if (collection is null)
        {
            try
            {
                var prop = surface.GetType().GetProperty(
                    "Triangles",
                    BindingFlags.Instance | BindingFlags.Public);
                collection = prop?.GetValue(surface);
            }
            catch { }
        }

        if (collection is not System.Collections.IEnumerable enumerable)
        {
            return null;
        }

        var result = new List<(Point3d v1, Point3d v2, Point3d v3)>();
        try
        {
            foreach (var tri in enumerable)
            {
                if (tri is null)
                {
                    continue;
                }

                var triType = tri.GetType();
                var v1 = TryGetTriangleVertex(tri, triType, "Vertex1");
                var v2 = TryGetTriangleVertex(tri, triType, "Vertex2");
                var v3 = TryGetTriangleVertex(tri, triType, "Vertex3");

                if (v1.HasValue && v2.HasValue && v3.HasValue)
                {
                    result.Add((v1.Value, v2.Value, v3.Value));
                }
            }
        }
        catch { /* partial result */ }

        return result.Count > 0 ? result : null;
    }

    private static Point3d? TryGetTriangleVertex(object tri, Type triType, string propName)
    {
        try
        {
            var prop = triType.GetProperty(propName, BindingFlags.Instance | BindingFlags.Public);
            if (prop is null)
            {
                return null;
            }

            var value = prop.GetValue(tri);
            if (value is Point3d p)
            {
                return p;
            }

            // TinSurfaceVertex wraps Location as Point3d
            var locProp = value?.GetType().GetProperty("Location", BindingFlags.Instance | BindingFlags.Public);
            if (locProp?.GetValue(value) is Point3d loc)
            {
                return loc;
            }
        }
        catch { }

        return null;
    }

    // ------------------------------------------------------------------
    // Triangle geometry helpers
    // ------------------------------------------------------------------

    private static double ComputeTriangleMaxSlopePercent(Point3d v1, Point3d v2, Point3d v3)
    {
        return Math.Max(
            ComputeEdgeSlopePercent(v1, v2),
            Math.Max(
                ComputeEdgeSlopePercent(v2, v3),
                ComputeEdgeSlopePercent(v1, v3)));
    }

    private static double ComputeEdgeSlopePercent(Point3d a, Point3d b)
    {
        var dz  = Math.Abs(b.Z - a.Z);
        var dxy = Dist2d(a.X, a.Y, b.X, b.Y);
        return dxy < 1e-9 ? 0.0 : (dz / dxy) * 100.0;
    }

    // ------------------------------------------------------------------
    // Peak / sink detection from vertex neighborhood
    // ------------------------------------------------------------------

    private static (int peaks, int sinks) DetectPeaksSinksFromTriangles(
        IReadOnlyList<(Point3d v1, Point3d v2, Point3d v3)> triangles,
        List<Dictionary<string, object?>> issues,
        int maxIssues,
        string surfaceHandle,
        string surfaceLayer)
    {
        // Build vertex → neighbor elevation list
        // Key: rounded XY to merge duplicate vertices (tolerance 1e-4)
        const double snapTol = 1e-4;
        var vertexNeighbors = new Dictionary<(long xi, long yi), (double z, List<double> neighborZ)>();

        void Register(Point3d v, Point3d n1, Point3d n2)
        {
            var key = ((long)Math.Round(v.X / snapTol), (long)Math.Round(v.Y / snapTol));
            if (!vertexNeighbors.TryGetValue(key, out var entry))
            {
                entry = (v.Z, new List<double>());
                vertexNeighbors[key] = entry;
            }

            entry.neighborZ.Add(n1.Z);
            entry.neighborZ.Add(n2.Z);
            vertexNeighbors[key] = entry;
        }

        foreach (var tri in triangles)
        {
            Register(tri.v1, tri.v2, tri.v3);
            Register(tri.v2, tri.v1, tri.v3);
            Register(tri.v3, tri.v1, tri.v2);
        }

        var peaks = 0;
        var sinks = 0;

        foreach (var kvp in vertexNeighbors)
        {
            var (z, neighborZ) = kvp.Value;
            if (neighborZ.Count < 2)
            {
                continue;
            }

            var avg = neighborZ.Average();
            var variance = neighborZ.Average(n => (n - avg) * (n - avg));
            var stdDev = Math.Sqrt(variance);
            var threshold = Math.Max(stdDev * 3.0, 0.05); // 3σ or 5 cm minimum

            var delta = z - avg;
            if (Math.Abs(delta) <= threshold)
            {
                continue;
            }

            var xi = kvp.Key.xi * snapTol;
            var yi = kvp.Key.yi * snapTol;

            if (delta > 0)
            {
                peaks++;
                if (issues.Count < maxIssues)
                {
                    issues.Add(MakeIssue(surfaceHandle, surfaceLayer, "PEAK", "warning",
                        $"Anomalous peak at ({xi:F2}, {yi:F2}): elev={z:F3}, neighbors avg={avg:F3}, delta=+{delta:F3}."));
                }
            }
            else
            {
                sinks++;
                if (issues.Count < maxIssues)
                {
                    issues.Add(MakeIssue(surfaceHandle, surfaceLayer, "SINK", "warning",
                        $"Anomalous sink at ({xi:F2}, {yi:F2}): elev={z:F3}, neighbors avg={avg:F3}, delta={delta:F3}."));
                }
            }
        }

        return (peaks, sinks);
    }

    // ------------------------------------------------------------------
    // Breakline coverage check
    // ------------------------------------------------------------------

    private static int CheckBreaklineCoverage(
        DocumentContext context,
        IReadOnlyList<(Point3d v1, Point3d v2, Point3d v3)> triangles,
        IReadOnlyList<string> blPatterns,
        List<Dictionary<string, object?>> issues,
        int maxIssues,
        string surfaceHandle,
        string surfaceLayer)
    {
        if (triangles.Count == 0)
        {
            return 0;
        }

        // Collect breakline sample points (vertices of lines/polylines on matching layers)
        var blPoints = new List<(double x, double y)>();
        var db  = context.Document.Database;
        var btr = (BlockTableRecord)context.Transaction.GetObject(db.CurrentSpaceId, OpenMode.ForRead);

        foreach (ObjectId entityId in btr)
        {
            var entity = context.Transaction.GetObject(entityId, OpenMode.ForRead, false)
                         as Autodesk.AutoCAD.DatabaseServices.Entity;
            if (entity is null || !LayerMatches(entity.Layer, blPatterns))
            {
                continue;
            }

            if (entity is Line line)
            {
                blPoints.Add((line.StartPoint.X, line.StartPoint.Y));
                blPoints.Add((line.EndPoint.X, line.EndPoint.Y));
            }
            else if (entity is Polyline pline)
            {
                for (var i = 0; i < pline.NumberOfVertices; i++)
                {
                    var pt = pline.GetPoint3dAt(i);
                    blPoints.Add((pt.X, pt.Y));
                }
            }
            else if (entity is Polyline3d pline3d)
            {
                foreach (ObjectId vertId in pline3d)
                {
                    if (context.Transaction.GetObject(vertId, OpenMode.ForRead) is PolylineVertex3d vert)
                    {
                        blPoints.Add((vert.Position.X, vert.Position.Y));
                    }
                }
            }
        }

        if (blPoints.Count == 0)
        {
            return 0;
        }

        // Estimate gap threshold as 5× median triangle edge
        var sampleEdges = triangles
            .Take(Math.Min(200, triangles.Count))
            .SelectMany(t => new[]
            {
                Dist2d(t.v1.X, t.v1.Y, t.v2.X, t.v2.Y),
                Dist2d(t.v2.X, t.v2.Y, t.v3.X, t.v3.Y),
                Dist2d(t.v1.X, t.v1.Y, t.v3.X, t.v3.Y),
            })
            .OrderBy(v => v)
            .ToArray();

        var medEdge    = sampleEdges.Length > 0 ? Median(sampleEdges) : 5.0;
        var gapThresh  = Math.Max(medEdge * 5.0, 1.0);

        var noZones = 0;
        // Limit to 500 triangles to avoid O(n·m) timeout on large surfaces
        foreach (var tri in triangles.Take(500))
        {
            var cx = (tri.v1.X + tri.v2.X + tri.v3.X) / 3.0;
            var cy = (tri.v1.Y + tri.v2.Y + tri.v3.Y) / 3.0;

            var minDist = blPoints.Min(p => Dist2d(cx, cy, p.x, p.y));
            if (minDist > gapThresh && issues.Count < maxIssues)
            {
                noZones++;
                issues.Add(MakeIssue(surfaceHandle, surfaceLayer, "NO_BREAKLINE_ZONE", "info",
                    $"Triangle centroid ({cx:F2}, {cy:F2}) has no breakline point within {gapThresh:F2} units (nearest={minDist:F2})."));
            }
        }

        return noZones;
    }

    // ------------------------------------------------------------------
    // V2 result builders / helpers
    // ------------------------------------------------------------------

    private static Dictionary<string, object?> MakeIssue(
        string handle, string layer, string type, string severity, string description)
    {
        return new Dictionary<string, object?>
        {
            ["handle"]      = handle,
            ["layer"]       = layer,
            ["type"]        = type,
            ["severity"]    = severity,
            ["description"] = description,
        };
    }

    private static object BuildV2Result(
        string? surfaceName,
        bool passed,
        string summary,
        Dictionary<string, object?>? metrics,
        List<Dictionary<string, object?>> issues)
    {
        return new
        {
            surfaceName,
            passed,
            summary,
            metrics,
            totalIssues = issues.Count,
            issues,
        };
    }

    private static string BuildV2SummaryText(
        string surfaceName,
        Dictionary<string, object?> metrics,
        int totalIssues)
    {
        var checked_ = metrics.TryGetValue("trianglesChecked", out var tc) && tc is int t ? t : (int?)null;
        return checked_.HasValue
            ? $"Surface '{surfaceName}': checked {checked_} triangles, {totalIssues} issue(s) found."
            : $"Surface '{surfaceName}': triangle-level check unavailable, {totalIssues} issue(s) found.";
    }

    private static object RebuildSurfaceWithRules(DocumentContext context, JsonElement? args)
    {
        if (!args.HasValue)
        {
            throw new InvalidOperationException("Missing rebuildSurfaceWithRules parameters.");
        }

        var surfaceName = GetOptionalString(args.Value, "surfaceName");
        if (string.IsNullOrWhiteSpace(surfaceName))
        {
            throw new InvalidOperationException("Missing required parameter: surfaceName");
        }

        var breaklinePatterns = GetOptionalStringArray(args.Value, "breaklineLayerPatterns") ?? Array.Empty<string>();
        var pointGroupName = GetOptionalString(args.Value, "pointGroupName");
        var boundaryName = GetOptionalString(args.Value, "boundaryName");
        var weedingDistance = GetOptionalDouble(args.Value, "weedingDistance");
        var weedingAngle = GetOptionalDouble(args.Value, "weedingAngle");
        var supplementingDistance = GetOptionalDouble(args.Value, "supplementingDistance");
        var deleteOverlaps = GetOptionalBool(args.Value, "deleteOverlaps") ?? true;
        var dryRun = GetOptionalBool(args.Value, "dryRun") ?? false;

        var surface = TryGetSurface(context, surfaceName)
            ?? throw new InvalidOperationException($"Surface not found: {surfaceName}");

        var actions = new List<string>();
        var warnings = new List<string>();
        var before = CollectSurfaceStats(context, surface, breaklinePatterns);

        if (!string.IsNullOrWhiteSpace(pointGroupName))
        {
            warnings.Add("Point group constrained rebuild is not fully implemented in this plugin build.");
        }

        if (!string.IsNullOrWhiteSpace(boundaryName))
        {
            warnings.Add("Boundary constrained rebuild is not fully implemented in this plugin build.");
        }

        if (weedingDistance.HasValue || weedingAngle.HasValue || supplementingDistance.HasValue || deleteOverlaps)
        {
            warnings.Add("Breakline geometric cleanup options are registered but not yet fully applied by this plugin build.");
        }

        if (!dryRun)
        {
            if (TryInvokeNoArg(surface, "Rebuild"))
            {
                actions.Add("Surface rebuilt.");
            }
            else
            {
                warnings.Add("Surface rebuild method was not available on target surface type.");
            }
        }
        else
        {
            actions.Add("Dry run: no modifications applied.");
        }

        var after = CollectSurfaceStats(context, surface, breaklinePatterns);
        var applied = !dryRun && actions.Count > 0;

        return new
        {
            surfaceName = TryGetStringProperty(surface, "Name") ?? surfaceName,
            dryRun,
            applied,
            summary = dryRun
                ? "Dry run completed. Review actions/warnings before applying."
                : $"Rebuild completed. Actions: {actions.Count}, warnings: {warnings.Count}.",
            before,
            after,
            actions,
            warnings
        };
    }

    private static object CreateCogoPoint(DocumentContext context, JsonElement? args)
    {
        if (!args.HasValue)
        {
            throw new InvalidOperationException("Missing point parameters.");
        }

        var easting = GetRequiredDouble(args.Value, "easting");
        var northing = GetRequiredDouble(args.Value, "northing");
        var elevation = GetOptionalDouble(args.Value, "elevation") ?? 0.0;
        var rawDescription = GetOptionalString(args.Value, "rawDescription") ?? string.Empty;
        var point = new Point3d(easting, northing, elevation);

        var collection = context.CivilDocument.CogoPoints;
        var pointId = TryAddCogoPoint(collection, point, rawDescription);
        var created = (CogoPoint)context.Transaction.GetObject(pointId, OpenMode.ForRead);

        return new
        {
            pointId = created.PointNumber,
            easting = created.Easting,
            northing = created.Northing,
            elevation = created.Elevation,
            rawDescription = created.RawDescription
        };
    }

    private static object CreateLineSegment(DocumentContext context, JsonElement? args)
    {
        if (!args.HasValue)
        {
            throw new InvalidOperationException("Missing line parameters.");
        }

        var start = new Point3d(
            GetRequiredDouble(args.Value, "startX"),
            GetRequiredDouble(args.Value, "startY"),
            GetOptionalDouble(args.Value, "startZ") ?? 0.0);
        var end = new Point3d(
            GetRequiredDouble(args.Value, "endX"),
            GetRequiredDouble(args.Value, "endY"),
            GetOptionalDouble(args.Value, "endZ") ?? 0.0);

        var btr = (BlockTableRecord)context.Transaction.GetObject(
            context.Document.Database.CurrentSpaceId,
            OpenMode.ForWrite);

        var line = new Line(start, end);
        var id = btr.AppendEntity(line);
        context.Transaction.AddNewlyCreatedDBObject(line, true);

        return new
        {
            lineId = id.Handle.ToString()
        };
    }

    private static object BuildSelectedObjectInfo(Autodesk.AutoCAD.DatabaseServices.DBObject dbObj)
    {
        if (dbObj is Pipe pipe)
        {
            var slope = 0.0;
            try
            {
                slope = (pipe.EndPoint.Z - pipe.StartPoint.Z) / pipe.Length2DCenterToCenter;
            }
            catch
            {
            }

            return new
            {
                handle = dbObj.Handle.ToString(),
                objectType = dbObj.GetType().Name,
                name = pipe.Name,
                description = TryGetStringProperty(pipe, "Description"),
                startPoint = new { x = pipe.StartPoint.X, y = pipe.StartPoint.Y, z = pipe.StartPoint.Z },
                endPoint = new { x = pipe.EndPoint.X, y = pipe.EndPoint.Y, z = pipe.EndPoint.Z },
                length2dCenterToCenter = pipe.Length2DCenterToCenter,
                slope = slope,
                slopePercent = slope * 100.0
            };
        }

        return new
        {
            handle = dbObj.Handle.ToString(),
            objectType = dbObj.GetType().Name,
            name = TryGetStringProperty(dbObj, "Name"),
            description = TryGetStringProperty(dbObj, "Description")
        };
    }

    private static IEnumerable<ObjectId> EnumerateCivilObjectIds(CivilDocument civilDocument, string methodName)
    {
        var method = civilDocument.GetType().GetMethod(methodName, BindingFlags.Instance | BindingFlags.Public);
        if (method is null)
        {
            return Enumerable.Empty<ObjectId>();
        }

        var value = method.Invoke(civilDocument, null);
        return ConvertToObjectIds(value);
    }

    private static IEnumerable<ObjectId> EnumerateObjectIds(object target, params string[] memberNames)
    {
        foreach (var memberName in memberNames)
        {
            var method = target.GetType().GetMethod(memberName, BindingFlags.Instance | BindingFlags.Public);
            if (method is not null && method.GetParameters().Length == 0)
            {
                var value = method.Invoke(target, null);
                var ids = ConvertToObjectIds(value).ToArray();
                if (ids.Length > 0)
                {
                    return ids;
                }
            }

            var prop = target.GetType().GetProperty(memberName, BindingFlags.Instance | BindingFlags.Public);
            if (prop is not null)
            {
                var value = prop.GetValue(target);
                var ids = ConvertToObjectIds(value).ToArray();
                if (ids.Length > 0)
                {
                    return ids;
                }
            }
        }

        return Enumerable.Empty<ObjectId>();
    }

    private static IEnumerable<ObjectId> ConvertToObjectIds(object? value)
    {
        switch (value)
        {
            case null:
                yield break;
            case ObjectId id when !id.IsNull:
                yield return id;
                yield break;
            case ObjectIdCollection coll:
                foreach (ObjectId item in coll)
                {
                    if (!item.IsNull)
                    {
                        yield return item;
                    }
                }
                yield break;
            case System.Collections.IEnumerable enumerable:
                foreach (var item in enumerable)
                {
                    if (item is ObjectId enumId && !enumId.IsNull)
                    {
                        yield return enumId;
                    }
                }
                yield break;
            default:
                yield break;
        }
    }

    private static Dictionary<string, object?> BuildPipeRow(object dbObj, string networkName, bool includePartsMetadata)
    {
        if (dbObj is Pipe pipe)
        {
            var slope = 0.0;
            try
            {
                slope = (pipe.EndPoint.Z - pipe.StartPoint.Z) / pipe.Length2DCenterToCenter;
            }
            catch
            {
            }

            var row = new Dictionary<string, object?>
            {
                ["networkName"] = networkName,
                ["handle"] = pipe.Handle.ToString(),
                ["objectType"] = pipe.GetType().Name,
                ["name"] = pipe.Name,
                ["description"] = TryGetStringProperty(pipe, "Description"),
                ["layer"] = pipe.Layer,
                ["startX"] = pipe.StartPoint.X,
                ["startY"] = pipe.StartPoint.Y,
                ["startZ"] = pipe.StartPoint.Z,
                ["endX"] = pipe.EndPoint.X,
                ["endY"] = pipe.EndPoint.Y,
                ["endZ"] = pipe.EndPoint.Z,
                ["length2d"] = pipe.Length2DCenterToCenter,
                ["slopePercent"] = slope * 100.0
            };

            if (includePartsMetadata)
            {
                row["partFamily"] = TryGetStringProperty(pipe, "PartFamilyName");
                row["partSize"] = TryGetStringProperty(pipe, "PartSizeName");
            }

            return row;
        }

        return BuildGenericNetworkRow((Autodesk.AutoCAD.DatabaseServices.DBObject)dbObj, networkName, includePartsMetadata);
    }

    private static Dictionary<string, object?> BuildStructureRow(object dbObj, string networkName, bool includePartsMetadata)
    {
        var row = BuildGenericNetworkRow((Autodesk.AutoCAD.DatabaseServices.DBObject)dbObj, networkName, includePartsMetadata);

        var rimElevation = TryGetDoubleProperty(dbObj, "RimElevation");
        var sumpElevation = TryGetDoubleProperty(dbObj, "SumpElevation");
        if (rimElevation.HasValue)
        {
            row["rimElevation"] = rimElevation.Value;
        }

        if (sumpElevation.HasValue)
        {
            row["sumpElevation"] = sumpElevation.Value;
        }

        return row;
    }

    private static Dictionary<string, object?> BuildGenericNetworkRow(Autodesk.AutoCAD.DatabaseServices.DBObject dbObj, string networkName, bool includePartsMetadata)
    {
        var row = new Dictionary<string, object?>
        {
            ["networkName"] = networkName,
            ["handle"] = dbObj.Handle.ToString(),
            ["objectType"] = dbObj.GetType().Name,
            ["name"] = TryGetStringProperty(dbObj, "Name"),
            ["description"] = TryGetStringProperty(dbObj, "Description"),
            ["layer"] = TryGetStringProperty(dbObj, "Layer")
        };

        if (TryGetPoint3d(dbObj, out var point))
        {
            row["x"] = point.X;
            row["y"] = point.Y;
            row["z"] = point.Z;
        }

        if (includePartsMetadata)
        {
            row["partFamily"] = TryGetStringProperty(dbObj, "PartFamilyName");
            row["partSize"] = TryGetStringProperty(dbObj, "PartSizeName");
        }

        return row;
    }

    private static bool TryGetPoint3d(object target, out Point3d point)
    {
        foreach (var propName in new[] { "Location", "Position", "Point", "StartPoint" })
        {
            var prop = target.GetType().GetProperty(propName, BindingFlags.Instance | BindingFlags.Public);
            if (prop is null)
            {
                continue;
            }

            try
            {
                var value = prop.GetValue(target);
                if (value is Point3d p)
                {
                    point = p;
                    return true;
                }
            }
            catch
            {
            }
        }

        point = default;
        return false;
    }

    private static string BuildCsv(IReadOnlyList<Dictionary<string, object?>> rows, IReadOnlyList<string> preferredColumns)
    {
        if (rows.Count == 0)
        {
            return string.Empty;
        }

        var columns = new List<string>();
        foreach (var col in preferredColumns)
        {
            if (rows.Any(r => r.ContainsKey(col)))
            {
                columns.Add(col);
            }
        }

        foreach (var key in rows.SelectMany(r => r.Keys).Distinct(StringComparer.OrdinalIgnoreCase))
        {
            if (!columns.Contains(key, StringComparer.OrdinalIgnoreCase))
            {
                columns.Add(key);
            }
        }

        var sb = new StringBuilder();
        sb.AppendLine(string.Join(",", columns.Select(CsvEscape)));
        foreach (var row in rows)
        {
            sb.AppendLine(string.Join(",", columns.Select(c => CsvEscape(ToInvariantString(row.TryGetValue(c, out var v) ? v : null)))));
        }

        return sb.ToString();
    }

    private static string CsvEscape(string value)
    {
        if (value.Contains(',') || value.Contains('"') || value.Contains('\n') || value.Contains('\r'))
        {
            return "\"" + value.Replace("\"", "\"\"") + "\"";
        }

        return value;
    }

    private static string ToInvariantString(object? value)
    {
        return value switch
        {
            null => string.Empty,
            double d => d.ToString("G17", CultureInfo.InvariantCulture),
            float f => f.ToString("G9", CultureInfo.InvariantCulture),
            decimal m => m.ToString(CultureInfo.InvariantCulture),
            bool b => b ? "true" : "false",
            _ => Convert.ToString(value, CultureInfo.InvariantCulture) ?? string.Empty
        };
    }

    private static object? ToSerializableValue(object? value)
    {
        return value switch
        {
            null => null,
            string s => s,
            bool b => b,
            byte b => b,
            sbyte sb => sb,
            short sh => sh,
            ushort ush => ush,
            int i => i,
            uint ui => ui,
            long l => l,
            ulong ul => ul,
            float f => f,
            double d => d,
            decimal m => m,
            Point3d p => new { x = p.X, y = p.Y, z = p.Z },
            ObjectId id => id.IsNull ? null : id.Handle.ToString(),
            _ => value.ToString()
        };
    }

    private static ObjectId? TryGetObjectIdProperty(object target, string propertyName)
    {
        try
        {
            var prop = target.GetType().GetProperty(propertyName, BindingFlags.Instance | BindingFlags.Public);
            var value = prop?.GetValue(target);
            return value is ObjectId id ? id : null;
        }
        catch
        {
            return null;
        }
    }

    private static bool TryResolveObjectIdByHandle(Database db, string handleText, out ObjectId objectId)
    {
        objectId = ObjectId.Null;

        var normalized = handleText.Trim().ToUpperInvariant();
        if (normalized.StartsWith("0X", StringComparison.Ordinal))
        {
            normalized = normalized[2..];
        }

        if (!long.TryParse(normalized, NumberStyles.HexNumber, CultureInfo.InvariantCulture, out var value))
        {
            return false;
        }

        try
        {
            var handle = new Handle(value);
            objectId = db.GetObjectId(false, handle, 0);
            return !objectId.IsNull;
        }
        catch
        {
            return false;
        }
    }

    private static object TryReadUserDefinedProperties(CogoPoint point)
    {
        var props = new Dictionary<string, object?>();

        try
        {
            var udpCollection = point.GetType().GetProperty("UserDefinedProperties", BindingFlags.Instance | BindingFlags.Public)?.GetValue(point);
            if (udpCollection is System.Collections.IEnumerable enumerable)
            {
                foreach (var item in enumerable)
                {
                    var name = TryGetStringProperty(item!, "Name") ?? TryGetStringProperty(item!, "DisplayName");
                    var value = item?.GetType().GetProperty("Value", BindingFlags.Instance | BindingFlags.Public)?.GetValue(item);
                    if (!string.IsNullOrWhiteSpace(name))
                    {
                        props[name] = ToSerializableValue(value);
                    }
                }
            }
        }
        catch
        {
        }

        return props;
    }

    private static Autodesk.AutoCAD.DatabaseServices.DBObject? TryGetSurface(DocumentContext context, string? surfaceName)
    {
        foreach (var id in EnumerateCivilObjectIds(context.CivilDocument, "GetSurfaceIds"))
        {
            var surface = context.Transaction.GetObject(id, OpenMode.ForRead, false);
            var name = TryGetStringProperty(surface, "Name");
            if (string.IsNullOrWhiteSpace(surfaceName) ||
                string.Equals(surfaceName, name, StringComparison.OrdinalIgnoreCase))
            {
                return surface;
            }
        }

        return null;
    }

    private static int CountBreaklineCandidates(DocumentContext context, IReadOnlyList<string> layerPatterns)
    {
        var db = context.Document.Database;
        var btr = (BlockTableRecord)context.Transaction.GetObject(db.CurrentSpaceId, OpenMode.ForRead);
        var count = 0;

        foreach (ObjectId entityId in btr)
        {
            var entity = context.Transaction.GetObject(entityId, OpenMode.ForRead, false) as Autodesk.AutoCAD.DatabaseServices.Entity;
            if (entity is null)
            {
                continue;
            }

            if (layerPatterns.Count > 0 && !LayerMatches(entity.Layer, layerPatterns))
            {
                continue;
            }

            var typeName = entity.GetType().Name;
            if (typeName.Contains("Polyline", StringComparison.OrdinalIgnoreCase) ||
                typeName.Contains("FeatureLine", StringComparison.OrdinalIgnoreCase) ||
                entity is Line)
            {
                count++;
            }
        }

        return count;
    }

    private static bool LayerMatches(string layer, IReadOnlyList<string> patterns)
    {
        if (patterns.Count == 0)
        {
            return true;
        }

        foreach (var pattern in patterns)
        {
            if (string.IsNullOrWhiteSpace(pattern))
            {
                continue;
            }

            var regex = "^" + Regex.Escape(pattern).Replace("\\*", ".*").Replace("\\?", ".") + "$";
            if (Regex.IsMatch(layer, regex, RegexOptions.IgnoreCase))
            {
                return true;
            }
        }

        return false;
    }

    // Precompiled regex to strip MTEXT RTF control sequences.
    // Covers: \P (paragraph), \~ (non-break space), \t (tab), format codes, braces.
    private static readonly Regex MTextRtfStripRegex = new(
        @"\\[A-Za-z][^;\\{}\s]*;?|[{}]|\\~|\\t",
        RegexOptions.Compiled | RegexOptions.CultureInvariant);

    private static string? TryGetTextValue(Autodesk.AutoCAD.DatabaseServices.Entity entity)
    {
        if (entity is DBText dbText)
        {
            return dbText.TextString?.Trim();
        }

        if (entity is MText mText)
        {
            var raw = mText.Text;
            if (string.IsNullOrWhiteSpace(raw))
            {
                raw = mText.Contents;
            }

            if (string.IsNullOrWhiteSpace(raw))
            {
                return null;
            }

            // Strip RTF formatting codes that survive .Text on some C3D builds
            raw = MTextRtfStripRegex.Replace(raw, " ");
            raw = Regex.Replace(raw, @"\s+", " ").Trim();
            return raw.Length == 0 ? null : raw;
        }

        return null;
    }

    private static bool TryParseElevationFromText(
        string sourceText,
        Regex regex,
        string decimalSeparatorMode,
        out double elevation,
        out string token)
    {
        elevation = 0.0;
        token = string.Empty;

        var match = regex.Match(sourceText);
        if (!match.Success)
        {
            return false;
        }

        token = match.Value.Trim();
        if (string.IsNullOrWhiteSpace(token))
        {
            return false;
        }

        if (!TryNormalizeNumberToken(token, decimalSeparatorMode, out var normalized))
        {
            return false;
        }

        return double.TryParse(normalized, NumberStyles.Any, CultureInfo.InvariantCulture, out elevation);
    }

    private static bool TryNormalizeNumberToken(string token, string mode, out string normalized)
    {
        normalized = token.Trim();
        if (string.IsNullOrWhiteSpace(normalized))
        {
            return false;
        }

        normalized = normalized.Replace(" ", string.Empty);

        if (string.Equals(mode, "dot", StringComparison.OrdinalIgnoreCase))
        {
            normalized = normalized.Replace(",", string.Empty);
            return true;
        }

        if (string.Equals(mode, "comma", StringComparison.OrdinalIgnoreCase))
        {
            normalized = normalized.Replace(".", string.Empty).Replace(",", ".");
            return true;
        }

        // auto: heuristic based on separator positions
        var commaCount = normalized.Count(c => c == ',');
        var dotCount = normalized.Count(c => c == '.');
        if (commaCount > 0 && dotCount > 0)
        {
            var lastComma = normalized.LastIndexOf(',');
            var lastDot = normalized.LastIndexOf('.');
            if (lastComma > lastDot)
            {
                normalized = normalized.Replace(".", string.Empty).Replace(",", ".");
            }
            else
            {
                normalized = normalized.Replace(",", string.Empty);
            }
            return true;
        }

        if (commaCount > 0)
        {
            normalized = normalized.Replace(",", ".");
        }

        return true;
    }

    private static double Dist2d(double x1, double y1, double x2, double y2)
    {
        var dx = x1 - x2;
        var dy = y1 - y2;
        return Math.Sqrt(dx * dx + dy * dy);
    }

    private static void AddSkippedSample(
        IList<Dictionary<string, object?>> target,
        string handle,
        string layer,
        string reason,
        string? sample)
    {
        if (target.Count >= 10)
        {
            return;
        }

        target.Add(new Dictionary<string, object?>
        {
            ["sourceHandle"] = handle,
            ["sourceLayer"] = layer,
            ["reason"] = reason,
            ["sample"] = sample
        });
    }

    private static (int totalOutliers, double median, double mad, List<(string handle, uint pointNumber, double elevation)> samples)
        DetectCogoElevationOutliers(DocumentContext context, int maxSamples)
    {
        var data = new List<(string handle, uint pointNumber, double elevation)>();
        foreach (ObjectId pointId in context.CivilDocument.CogoPoints)
        {
            if (context.Transaction.GetObject(pointId, OpenMode.ForRead) is CogoPoint point)
            {
                data.Add((point.Handle.ToString(), point.PointNumber, point.Elevation));
            }
        }

        if (data.Count < 10)
        {
            return (0, 0.0, 0.0, new List<(string handle, uint pointNumber, double elevation)>());
        }

        var elevations = data.Select(d => d.elevation).OrderBy(v => v).ToArray();
        var median = Median(elevations);
        var absDevs = elevations.Select(v => Math.Abs(v - median)).OrderBy(v => v).ToArray();
        var mad = Median(absDevs);
        if (mad <= 1e-9)
        {
            return (0, median, mad, new List<(string handle, uint pointNumber, double elevation)>());
        }

        var threshold = 4.5 * mad;
        var outliers = data
            .Where(d => Math.Abs(d.elevation - median) > threshold)
            .OrderByDescending(d => Math.Abs(d.elevation - median))
            .ToList();

        return (outliers.Count, median, mad, outliers.Take(Math.Max(0, maxSamples)).ToList());
    }

    private static double Median(IReadOnlyList<double> sortedValues)
    {
        if (sortedValues.Count == 0)
        {
            return 0.0;
        }

        var mid = sortedValues.Count / 2;
        return sortedValues.Count % 2 == 0
            ? (sortedValues[mid - 1] + sortedValues[mid]) / 2.0
            : sortedValues[mid];
    }

    private static Dictionary<string, object?> CollectSurfaceStats(DocumentContext context, object surface, IReadOnlyList<string> breaklinePatterns)
    {
        return new Dictionary<string, object?>
        {
            ["surfaceName"] = TryGetStringProperty(surface, "Name"),
            ["pointsCount"] = context.CivilDocument.CogoPoints.Count,
            ["breaklineCandidates"] = CountBreaklineCandidates(context, breaklinePatterns),
            ["minElevation"] = TryGetDoubleProperty(surface, "MinimumElevation"),
            ["maxElevation"] = TryGetDoubleProperty(surface, "MaximumElevation"),
            ["trianglesCount"] = TryGetIntProperty(surface, "TrianglesCount")
        };
    }

    private static bool TryInvokeNoArg(object target, string methodName)
    {
        try
        {
            var method = target.GetType().GetMethod(methodName, BindingFlags.Instance | BindingFlags.Public);
            if (method is null || method.GetParameters().Length != 0)
            {
                return false;
            }

            method.Invoke(target, null);
            return true;
        }
        catch
        {
            return false;
        }
    }

    private static int? TryGetIntProperty(object target, string propertyName)
    {
        try
        {
            var value = target.GetType().GetProperty(propertyName, BindingFlags.Instance | BindingFlags.Public)?.GetValue(target);
            return value switch
            {
                null => null,
                int i => i,
                long l => (int)l,
                short s => s,
                _ => int.TryParse(Convert.ToString(value, CultureInfo.InvariantCulture), NumberStyles.Integer, CultureInfo.InvariantCulture, out var parsed) ? parsed : null
            };
        }
        catch
        {
            return null;
        }
    }

    private static double? TryGetDoubleProperty(object target, string propertyName)
    {
        try
        {
            var value = target.GetType().GetProperty(propertyName, BindingFlags.Instance | BindingFlags.Public)?.GetValue(target);
            return value switch
            {
                null => null,
                double d => d,
                float f => f,
                decimal m => (double)m,
                _ => double.TryParse(Convert.ToString(value, CultureInfo.InvariantCulture), NumberStyles.Any, CultureInfo.InvariantCulture, out var parsed) ? parsed : null
            };
        }
        catch
        {
            return null;
        }
    }

    private static ObjectId TryAddCogoPoint(CogoPointCollection collection, Point3d point, string rawDescription)
    {
        var methods = collection.GetType()
            .GetMethods(BindingFlags.Instance | BindingFlags.Public)
            .Where(m => m.Name == "Add")
            .OrderBy(m => m.GetParameters().Length)
            .ToArray();

        foreach (var method in methods)
        {
            var parameters = method.GetParameters();
            try
            {
                if (parameters.Length == 2 &&
                    parameters[0].ParameterType == typeof(Point3d) &&
                    parameters[1].ParameterType == typeof(bool))
                {
                    return NormalizeObjectId(method.Invoke(collection, new object[] { point, true }));
                }

                if (parameters.Length == 3 &&
                    parameters[0].ParameterType == typeof(Point3d) &&
                    parameters[1].ParameterType == typeof(string) &&
                    parameters[2].ParameterType == typeof(bool))
                {
                    return NormalizeObjectId(method.Invoke(collection, new object[] { point, rawDescription, true }));
                }
            }
            catch
            {
            }
        }

        var pts = new Point3dCollection { point };
        var fallbackResult = collection.Add(pts, rawDescription, true);
        return NormalizeObjectId(fallbackResult);
    }

    private static ObjectId NormalizeObjectId(object? value)
    {
        return value switch
        {
            ObjectId id => id,
            ObjectIdCollection ids when ids.Count > 0 => ids[0],
            null => throw new InvalidOperationException("The COGO point operation did not return an object id."),
            _ => throw new InvalidOperationException($"Unexpected COGO point return type: {value.GetType().FullName}")
        };
    }

    private static void AddIfPresent(ICollection<string> names, object target, string methodName, string label)
    {
        try
        {
            var method = target.GetType().GetMethod(methodName, BindingFlags.Instance | BindingFlags.Public);
            var value = method?.Invoke(target, null);
            if (value is System.Collections.ICollection collection && collection.Count > 0)
            {
                names.Add(label);
            }
        }
        catch
        {
        }
    }

    private static string? TryGetCoordinateSystem(CivilDocument doc)
    {
        try
        {
            var settings = doc.GetType().GetProperty("Settings")?.GetValue(doc);
            var drawingSettings = settings?.GetType().GetProperty("DrawingSettings")?.GetValue(settings);
            var unitZone = drawingSettings?.GetType().GetProperty("UnitZoneSettings")?.GetValue(drawingSettings);
            var code = unitZone?.GetType().GetProperty("CoordinateSystemCode")?.GetValue(unitZone);
            return code?.ToString();
        }
        catch
        {
            return null;
        }
    }

    private static string? TryGetStringProperty(object target, string propertyName)
    {
        try
        {
            return target.GetType().GetProperty(propertyName)?.GetValue(target)?.ToString();
        }
        catch
        {
            return null;
        }
    }

    private static double GetRequiredDouble(JsonElement args, string propertyName)
    {
        if (!args.TryGetProperty(propertyName, out var prop))
        {
            throw new InvalidOperationException($"Missing required parameter: {propertyName}");
        }

        return prop.ValueKind switch
        {
            JsonValueKind.Number => prop.GetDouble(),
            JsonValueKind.String => double.Parse(prop.GetString()!, CultureInfo.InvariantCulture),
            _ => throw new InvalidOperationException($"Parameter {propertyName} is not numeric.")
        };
    }

    private static double? GetOptionalDouble(JsonElement args, string propertyName)
    {
        return args.TryGetProperty(propertyName, out _)
            ? GetRequiredDouble(args, propertyName)
            : null;
    }

    private static int? GetOptionalInt(JsonElement args, string propertyName)
    {
        if (!args.TryGetProperty(propertyName, out var prop))
        {
            return null;
        }

        return prop.ValueKind switch
        {
            JsonValueKind.Number => prop.GetInt32(),
            JsonValueKind.String => int.Parse(prop.GetString()!, CultureInfo.InvariantCulture),
            _ => throw new InvalidOperationException($"Parameter {propertyName} is not an integer.")
        };
    }

    private static bool? GetOptionalBool(JsonElement args, string propertyName)
    {
        if (!args.TryGetProperty(propertyName, out var prop))
        {
            return null;
        }

        return prop.ValueKind switch
        {
            JsonValueKind.True => true,
            JsonValueKind.False => false,
            JsonValueKind.String => bool.Parse(prop.GetString()!),
            _ => throw new InvalidOperationException($"Parameter {propertyName} is not a boolean.")
        };
    }

    private static string? GetOptionalString(JsonElement args, string propertyName)
    {
        return args.TryGetProperty(propertyName, out var prop) ? prop.GetString() : null;
    }

    private static string[]? GetOptionalStringArray(JsonElement args, string propertyName)
    {
        if (!args.TryGetProperty(propertyName, out var prop))
        {
            return null;
        }

        if (prop.ValueKind != JsonValueKind.Array)
        {
            throw new InvalidOperationException($"Parameter {propertyName} is not a string array.");
        }

        return prop.EnumerateArray()
            .Where(item => item.ValueKind == JsonValueKind.String)
            .Select(item => item.GetString() ?? string.Empty)
            .ToArray();
    }

    private static void WriteMessage(string message)
    {
        try
        {
            Application.DocumentManager.MdiActiveDocument?.Editor.WriteMessage(message);
        }
        catch
        {
        }
    }

    private sealed class DocumentContext
    {
        public DocumentContext(Document document, CivilDocument civilDocument, Transaction transaction)
        {
            Document = document;
            CivilDocument = civilDocument;
            Transaction = transaction;
        }

        public Document Document { get; }
        public CivilDocument CivilDocument { get; }
        public Transaction Transaction { get; }
    }

    private sealed class RpcRequest
    {
        [JsonPropertyName("jsonrpc")]
        public string JsonRpc { get; set; } = string.Empty;

        [JsonPropertyName("method")]
        public string Method { get; set; } = string.Empty;

        [JsonPropertyName("params")]
        public JsonElement? Params { get; set; }

        [JsonPropertyName("id")]
        public JsonElement? IdElement { get; set; }

        [JsonIgnore]
        public object? Id
        {
            get
            {
                if (!IdElement.HasValue)
                {
                    return null;
                }

                var value = IdElement.Value;
                return value.ValueKind switch
                {
                    JsonValueKind.String => value.GetString(),
                    JsonValueKind.Number => value.GetInt64(),
                    _ => value.ToString()
                };
            }
        }
    }

    private sealed class RpcResponse
    {
        [JsonPropertyName("jsonrpc")]
        public string JsonRpc { get; set; } = "2.0";

        [JsonPropertyName("id")]
        public object? Id { get; set; }

        [JsonPropertyName("result")]
        public object? Result { get; set; }

        [JsonPropertyName("error")]
        public RpcError? Error { get; set; }
    }

    private sealed class RpcError
    {
        [JsonPropertyName("code")]
        public int Code { get; set; }

        [JsonPropertyName("message")]
        public string Message { get; set; } = string.Empty;
    }
}

public sealed class PluginCommands
{
    [CommandMethod("CIVIL3DMCPSTATUS", CommandFlags.Modal)]
    public void ShowStatus()
    {
        var isListening = false;

        try
        {
            using var client = new TcpClient();
            var connect = client.BeginConnect("127.0.0.1", PortAccessor.Value, null, null);
            isListening = connect.AsyncWaitHandle.WaitOne(250) && client.Connected;
            if (client.Connected)
            {
                client.EndConnect(connect);
            }
        }
        catch
        {
            isListening = false;
        }

        Application.DocumentManager.MdiActiveDocument?.Editor.WriteMessage(
            $"\nCivil3DMcpPlugin [{PluginEntry.BuildTag}] status: {(isListening ? \"listening\" : \"not listening\")} on 127.0.0.1:{PortAccessor.Value}");
    }

    [CommandMethod("CIVIL3DMCPVER", CommandFlags.Modal)]
    public void ShowVersion()
    {
        Application.DocumentManager.MdiActiveDocument?.Editor.WriteMessage(
            $"\nCivil3DMcpPlugin version: {PluginEntry.BuildTag}");
    }
}

internal static class PortAccessor
{
    internal const int Value = 8080;
}
