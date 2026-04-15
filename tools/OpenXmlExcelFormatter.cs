using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using DocumentFormat.OpenXml;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Spreadsheet;

public class FormatterOutcome
{
    public bool Success { get; set; }
    public string Error { get; set; }
    public string Intervention { get; set; }
    public List<string> Changes { get; set; }
    public List<string> Notes { get; set; }

    public FormatterOutcome()
    {
        Success = false;
        Error = "";
        Intervention = "sin aplicar";
        Changes = new List<string>();
        Notes = new List<string>();
    }
}

internal enum RowRole
{
    Title,
    Header,
    Total
}

internal sealed class SheetProfile
{
    public int TitleRow;
    public int HeaderRow;
    public int FirstRow;
    public int LastRow;
    public int FirstColumn;
    public int LastColumn;
    public bool SkipAutoFit;
}

internal sealed class StyleManager
{
    private readonly WorkbookStylesPart stylesPart;
    private readonly Stylesheet stylesheet;
    private readonly Dictionary<string, uint> cache = new Dictionary<string, uint>(StringComparer.Ordinal);
    private readonly uint titleFontId;
    private readonly uint headerFontId;
    private readonly uint totalFontId;
    private readonly uint titleFillId;
    private readonly uint headerFillId;
    private readonly uint totalFillId;
    private readonly uint titleBorderId;
    private readonly uint headerBorderId;
    private readonly uint totalBorderId;

    public StyleManager(WorkbookPart workbookPart)
    {
        if (workbookPart.WorkbookStylesPart == null)
        {
            workbookPart.AddNewPart<WorkbookStylesPart>();
            workbookPart.WorkbookStylesPart.Stylesheet = CreateBaseStylesheet();
        }

        stylesPart = workbookPart.WorkbookStylesPart;
        stylesheet = stylesPart.Stylesheet ?? CreateBaseStylesheet();

        if (stylesheet.Fonts == null) { stylesheet.Fonts = new Fonts(new Font()) { Count = 1U, KnownFonts = true }; }
        if (stylesheet.Fills == null) { stylesheet.Fills = new Fills(new Fill(new PatternFill() { PatternType = PatternValues.None }), new Fill(new PatternFill() { PatternType = PatternValues.Gray125 })) { Count = 2U }; }
        if (stylesheet.Borders == null) { stylesheet.Borders = new Borders(new Border()) { Count = 1U }; }
        if (stylesheet.CellStyleFormats == null) { stylesheet.CellStyleFormats = new CellStyleFormats(new CellFormat()) { Count = 1U }; }
        if (stylesheet.CellFormats == null) { stylesheet.CellFormats = new CellFormats(new CellFormat()) { Count = 1U }; }
        if (stylesheet.CellStyles == null) { stylesheet.CellStyles = new CellStyles(new CellStyle() { Name = "Normal", FormatId = 0U, BuiltinId = 0U }) { Count = 1U }; }

        titleFontId = AppendFont("Calibri", 13D, true, "2F3B52");
        headerFontId = AppendFont("Calibri", 10D, true, "FFFFFF");
        totalFontId = AppendFont("Calibri", 10D, true, "2F3B52");

        titleFillId = AppendFill("E9EEF5");
        headerFillId = AppendFill("44546A");
        totalFillId = AppendFill("D9E2F1");

        titleBorderId = AppendBorder("B7C4D3");
        headerBorderId = AppendBorder("9BA9B8");
        totalBorderId = AppendBorder("B7C4D3");
    }

    public uint GetStyle(uint baseStyleIndex, RowRole role)
    {
        string key = baseStyleIndex.ToString(CultureInfo.InvariantCulture) + "|" + role;
        uint styleId;
        if (cache.TryGetValue(key, out styleId)) return styleId;

        CellFormat baseFormat = stylesheet.CellFormats.Elements<CellFormat>().ElementAtOrDefault((int)baseStyleIndex)
            ?? stylesheet.CellFormats.Elements<CellFormat>().FirstOrDefault()
            ?? new CellFormat();
        CellFormat derived = (CellFormat)baseFormat.CloneNode(true);

        switch (role)
        {
            case RowRole.Title:
                derived.FontId = titleFontId;
                derived.FillId = titleFillId;
                derived.BorderId = titleBorderId;
                derived.ApplyFont = true;
                derived.ApplyFill = true;
                derived.ApplyBorder = true;
                derived.Alignment = new Alignment() { Horizontal = HorizontalAlignmentValues.Left, Vertical = VerticalAlignmentValues.Center, WrapText = true };
                derived.ApplyAlignment = true;
                break;
            case RowRole.Header:
                derived.FontId = headerFontId;
                derived.FillId = headerFillId;
                derived.BorderId = headerBorderId;
                derived.ApplyFont = true;
                derived.ApplyFill = true;
                derived.ApplyBorder = true;
                derived.Alignment = new Alignment() { Horizontal = HorizontalAlignmentValues.Center, Vertical = VerticalAlignmentValues.Center, WrapText = true };
                derived.ApplyAlignment = true;
                break;
            default:
                derived.FontId = totalFontId;
                derived.FillId = totalFillId;
                derived.BorderId = totalBorderId;
                derived.ApplyFont = true;
                derived.ApplyFill = true;
                derived.ApplyBorder = true;
                derived.Alignment = new Alignment() { Vertical = VerticalAlignmentValues.Center, WrapText = true };
                derived.ApplyAlignment = true;
                break;
        }

        stylesheet.CellFormats.AppendChild(derived);
        stylesheet.CellFormats.Count = (uint)stylesheet.CellFormats.Count();
        styleId = (uint)(stylesheet.CellFormats.Count() - 1);
        cache[key] = styleId;
        return styleId;
    }

    public void Save()
    {
        stylesPart.Stylesheet.Save();
    }

    private static Stylesheet CreateBaseStylesheet()
    {
        return new Stylesheet(
            new Fonts(new Font()) { Count = 1U, KnownFonts = true },
            new Fills(
                new Fill(new PatternFill() { PatternType = PatternValues.None }),
                new Fill(new PatternFill() { PatternType = PatternValues.Gray125 })
            ) { Count = 2U },
            new Borders(new Border()) { Count = 1U },
            new CellStyleFormats(new CellFormat()) { Count = 1U },
            new CellFormats(new CellFormat()) { Count = 1U },
            new CellStyles(new CellStyle() { Name = "Normal", FormatId = 0U, BuiltinId = 0U }) { Count = 1U }
        );
    }

    private uint AppendFont(string fontName, double size, bool bold, string rgb)
    {
        Font font = new Font();
        font.AppendChild(new FontName() { Val = fontName });
        font.AppendChild(new FontSize() { Val = size });
        font.AppendChild(new Color() { Rgb = rgb });
        if (bold) font.AppendChild(new Bold());
        stylesheet.Fonts.AppendChild(font);
        stylesheet.Fonts.Count = (uint)stylesheet.Fonts.Count();
        return (uint)(stylesheet.Fonts.Count() - 1);
    }

    private uint AppendFill(string rgb)
    {
        Fill fill = new Fill(new PatternFill(new ForegroundColor() { Rgb = rgb }, new BackgroundColor() { Indexed = 64U }) { PatternType = PatternValues.Solid });
        stylesheet.Fills.AppendChild(fill);
        stylesheet.Fills.Count = (uint)stylesheet.Fills.Count();
        return (uint)(stylesheet.Fills.Count() - 1);
    }

    private uint AppendBorder(string rgb)
    {
        Border border = new Border(
            new LeftBorder() { Style = BorderStyleValues.Thin, Color = new Color() { Rgb = rgb } },
            new RightBorder() { Style = BorderStyleValues.Thin, Color = new Color() { Rgb = rgb } },
            new TopBorder() { Style = BorderStyleValues.Thin, Color = new Color() { Rgb = rgb } },
            new BottomBorder() { Style = BorderStyleValues.Thin, Color = new Color() { Rgb = rgb } },
            new DiagonalBorder()
        );
        stylesheet.Borders.AppendChild(border);
        stylesheet.Borders.Count = (uint)stylesheet.Borders.Count();
        return (uint)(stylesheet.Borders.Count() - 1);
    }
}

public static class OpenXmlExcelFormatter
{
    public static FormatterOutcome FormatCopy(string sourcePath, string destinationPath)
    {
        FormatterOutcome outcome = new FormatterOutcome();
        File.Copy(sourcePath, destinationPath, true);

        using (SpreadsheetDocument document = SpreadsheetDocument.Open(destinationPath, true))
        {
            WorkbookPart workbookPart = document.WorkbookPart;
            if (workbookPart == null || workbookPart.Workbook == null)
            {
                outcome.Error = "No se ha encontrado WorkbookPart.";
                return outcome;
            }

            StyleManager styles = new StyleManager(workbookPart);
            foreach (Sheet sheet in workbookPart.Workbook.Sheets.Elements<Sheet>())
            {
                if (sheet.State != null && sheet.State.Value != SheetStateValues.Visible)
                {
                    outcome.Notes.Add(sheet.Name + ": sin cambios por estar oculta");
                    continue;
                }

                WorksheetPart wsPart = workbookPart.GetPartById(sheet.Id) as WorksheetPart;
                if (wsPart == null || wsPart.Worksheet == null)
                {
                    outcome.Notes.Add(sheet.Name + ": sin cambios por no ser una hoja estándar");
                    continue;
                }

                if (wsPart.Worksheet.Elements<SheetProtection>().Any())
                {
                    outcome.Notes.Add(sheet.Name + ": sin cambios por protección");
                    continue;
                }

                SheetProfile profile = Analyze(wsPart, workbookPart.SharedStringTablePart);
                if (profile.LastRow == 0 || profile.LastColumn == 0)
                {
                    outcome.Notes.Add(sheet.Name + ": sin cambios por estar vacía");
                    continue;
                }

                if (profile.TitleRow > 0)
                {
                    ApplyRole(wsPart.Worksheet, (uint)profile.TitleRow, styles, RowRole.Title);
                    SetRowHeight(wsPart.Worksheet, (uint)profile.TitleRow, 24D);
                    outcome.Changes.Add("Título reforzado en '" + sheet.Name + "'");
                }

                if (profile.HeaderRow > 0)
                {
                    ApplyRole(wsPart.Worksheet, (uint)profile.HeaderRow, styles, RowRole.Header);
                    SetRowHeight(wsPart.Worksheet, (uint)profile.HeaderRow, 22D);
                    outcome.Changes.Add("Encabezados normalizados en '" + sheet.Name + "'");
                }

                HighlightTotals(wsPart.Worksheet, workbookPart.SharedStringTablePart, styles, profile.FirstRow, profile.LastRow);
                EnsureFreezePane(wsPart.Worksheet, (uint)Math.Max(profile.HeaderRow, 1), profile.LastColumn > 8);
                EnsurePrint(wsPart.Worksheet, profile.LastColumn);

                if (!profile.SkipAutoFit)
                {
                    ApplyColumnWidths(wsPart, workbookPart.SharedStringTablePart, profile.FirstColumn, profile.LastColumn);
                    outcome.Changes.Add("Columnas ajustadas en '" + sheet.Name + "'");
                }
                else
                {
                    outcome.Notes.Add(sheet.Name + ": ajuste de anchos omitido por celdas combinadas/dibujos");
                }

                wsPart.Worksheet.Save();
            }

            styles.Save();
            workbookPart.Workbook.Save();
        }

        outcome.Success = true;
        outcome.Intervention = outcome.Changes.Count >= 3 ? "media" : "baja";
        outcome.Changes = outcome.Changes.Distinct().ToList();
        return outcome;
    }

    private static SheetProfile Analyze(WorksheetPart wsPart, SharedStringTablePart sst)
    {
        SheetProfile profile = new SheetProfile();
        SheetData data = wsPart.Worksheet.GetFirstChild<SheetData>();
        if (data == null) return profile;

        List<Row> rows = data.Elements<Row>().Where(r => r.Elements<Cell>().Any()).OrderBy(r => r.RowIndex.Value).ToList();
        if (!rows.Any()) return profile;

        profile.FirstRow = (int)rows.First().RowIndex.Value;
        profile.LastRow = (int)rows.Last().RowIndex.Value;
        profile.FirstColumn = int.MaxValue;
        profile.LastColumn = 0;

        foreach (Row row in rows)
        {
            foreach (Cell cell in row.Elements<Cell>())
            {
                int col = GetColumnIndex(cell.CellReference != null ? cell.CellReference.Value : "");
                if (col <= 0) continue;
                profile.FirstColumn = Math.Min(profile.FirstColumn, col);
                profile.LastColumn = Math.Max(profile.LastColumn, col);
            }
        }

        if (profile.FirstColumn == int.MaxValue) profile.FirstColumn = 1;

        List<System.Tuple<int, int>> scan = rows.Take(8)
            .Select(r => System.Tuple.Create((int)r.RowIndex.Value, r.Elements<Cell>().Count(c => !String.IsNullOrWhiteSpace(GetCellText(c, sst)))))
            .ToList();

        System.Tuple<int, int> header = scan.OrderByDescending(x => x.Item2).ThenBy(x => x.Item1).FirstOrDefault();
        System.Tuple<int, int> firstFilled = scan.FirstOrDefault(x => x.Item2 > 0);

        if (header != null && header.Item2 > 0) profile.HeaderRow = header.Item1;
        if (firstFilled != null && header != null && firstFilled.Item1 < header.Item1 && firstFilled.Item2 <= Math.Max(3, (profile.LastColumn - profile.FirstColumn + 1) / 4))
        {
            profile.TitleRow = firstFilled.Item1;
        }

        profile.SkipAutoFit = wsPart.Worksheet.Elements<MergeCells>().Any() || wsPart.Worksheet.Elements<Drawing>().Any() || wsPart.DrawingsPart != null;
        return profile;
    }

    private static void ApplyRole(Worksheet worksheet, uint rowIndex, StyleManager styles, RowRole role)
    {
        Row row = worksheet.Descendants<Row>().FirstOrDefault(r => r.RowIndex != null && r.RowIndex.Value == rowIndex);
        if (row == null) return;

        foreach (Cell cell in row.Elements<Cell>())
        {
            uint baseStyle = cell.StyleIndex != null ? cell.StyleIndex.Value : 0U;
            cell.StyleIndex = styles.GetStyle(baseStyle, role);
        }
    }

    private static void SetRowHeight(Worksheet worksheet, uint rowIndex, double height)
    {
        Row row = worksheet.Descendants<Row>().FirstOrDefault(r => r.RowIndex != null && r.RowIndex.Value == rowIndex);
        if (row == null) return;
        row.Height = height;
        row.CustomHeight = true;
    }

    private static void HighlightTotals(Worksheet worksheet, SharedStringTablePart sst, StyleManager styles, int firstRow, int lastRow)
    {
        foreach (Row row in worksheet.Descendants<Row>().Where(r => r.RowIndex != null && r.RowIndex.Value >= (uint)firstRow && r.RowIndex.Value <= (uint)lastRow))
        {
            Cell first = row.Elements<Cell>().FirstOrDefault();
            if (first == null) continue;
            string text = GetCellText(first, sst).Trim().ToLowerInvariant();
            if (text.Contains("total") || text.Contains("resumen") || text.Contains("resultado"))
            {
                foreach (Cell cell in row.Elements<Cell>())
                {
                    uint baseStyle = cell.StyleIndex != null ? cell.StyleIndex.Value : 0U;
                    cell.StyleIndex = styles.GetStyle(baseStyle, RowRole.Total);
                }
            }
        }
    }

    private static void EnsureFreezePane(Worksheet worksheet, uint headerRow, bool freezeFirstColumn)
    {
        if (headerRow == 0U) headerRow = 1U;
        SheetViews views = worksheet.GetFirstChild<SheetViews>();
        if (views == null)
        {
            views = new SheetViews();
            worksheet.InsertAt(views, 0);
        }

        SheetView view = views.Elements<SheetView>().FirstOrDefault();
        if (view == null)
        {
            view = new SheetView() { WorkbookViewId = 0U };
            views.AppendChild(view);
        }

        Pane pane = view.Elements<Pane>().FirstOrDefault();
        if (pane == null)
        {
            pane = new Pane();
            view.InsertAt(pane, 0);
        }

        pane.State = PaneStateValues.Frozen;
        pane.VerticalSplit = headerRow;
        pane.TopLeftCell = (freezeFirstColumn ? "B" : "A") + (headerRow + 1U).ToString(CultureInfo.InvariantCulture);
        if (freezeFirstColumn)
        {
            pane.HorizontalSplit = 1D;
            pane.ActivePane = PaneValues.BottomRight;
        }
        else
        {
            pane.ActivePane = PaneValues.BottomLeft;
        }
    }

    private static void EnsurePrint(Worksheet worksheet, int lastColumn)
    {
        PageMargins margins = worksheet.GetFirstChild<PageMargins>();
        if (margins == null)
        {
            margins = new PageMargins();
            worksheet.AppendChild(margins);
        }

        margins.Left = 0.45D;
        margins.Right = 0.35D;
        margins.Top = 0.55D;
        margins.Bottom = 0.55D;
        margins.Header = 0.2D;
        margins.Footer = 0.2D;

        PageSetup setup = worksheet.GetFirstChild<PageSetup>();
        if (setup == null)
        {
            setup = new PageSetup();
            worksheet.AppendChild(setup);
        }

        setup.Orientation = lastColumn > 8 ? OrientationValues.Landscape : OrientationValues.Portrait;
        setup.FitToWidth = 1U;
    }

    private static void ApplyColumnWidths(WorksheetPart wsPart, SharedStringTablePart sst, int firstColumn, int lastColumn)
    {
        Worksheet worksheet = wsPart.Worksheet;
        Columns cols = worksheet.Elements<Columns>().FirstOrDefault();
        if (cols == null)
        {
            cols = new Columns();
            OpenXmlElement anchor = worksheet.Elements<SheetFormatProperties>().Cast<OpenXmlElement>().FirstOrDefault()
                ?? worksheet.Elements<SheetViews>().Cast<OpenXmlElement>().FirstOrDefault()
                ?? worksheet.Elements<SheetDimension>().Cast<OpenXmlElement>().FirstOrDefault();
            if (anchor != null) worksheet.InsertAfter(cols, anchor);
            else worksheet.PrependChild(cols);
        }

        for (int col = firstColumn; col <= lastColumn; col++)
        {
            if (IsHidden(cols, (uint)col)) continue;
            double width = Math.Max(8D, Math.Min(42D, EstimateWidth(wsPart, sst, col)));
            Column existing = cols.Elements<Column>().FirstOrDefault(c => c.Min != null && c.Max != null && c.Min.Value == (uint)col && c.Max.Value == (uint)col);
            if (existing == null)
            {
                existing = new Column() { Min = (uint)col, Max = (uint)col };
                cols.AppendChild(existing);
            }
            existing.Width = width;
            existing.CustomWidth = true;
            existing.BestFit = true;
        }
    }

    private static bool IsHidden(Columns cols, uint columnIndex)
    {
        foreach (Column col in cols.Elements<Column>())
        {
            if (col.Min == null || col.Max == null) continue;
            if (col.Min.Value <= columnIndex && col.Max.Value >= columnIndex && col.Hidden != null && col.Hidden.Value) return true;
        }
        return false;
    }

    private static double EstimateWidth(WorksheetPart wsPart, SharedStringTablePart sst, int columnIndex)
    {
        double maxLen = 8D;
        int seen = 0;
        foreach (Row row in wsPart.Worksheet.Descendants<Row>())
        {
            Cell cell = row.Elements<Cell>().FirstOrDefault(c => GetColumnIndex(c.CellReference != null ? c.CellReference.Value : "") == columnIndex);
            if (cell == null) continue;
            string text = GetCellText(cell, sst);
            if (String.IsNullOrWhiteSpace(text)) continue;
            maxLen = Math.Max(maxLen, Math.Min(40D, text.Length + 2D));
            seen++;
            if (seen >= 120) break;
        }
        return maxLen;
    }

    private static string GetCellText(Cell cell, SharedStringTablePart sst)
    {
        if (cell == null) return String.Empty;
        if (cell.DataType != null)
        {
            if (cell.DataType == CellValues.SharedString && sst != null && cell.CellValue != null)
            {
                int index;
                if (Int32.TryParse(cell.CellValue.Text, out index))
                {
                    SharedStringItem item = sst.SharedStringTable.Elements<SharedStringItem>().ElementAtOrDefault(index);
                    if (item != null) return item.InnerText ?? String.Empty;
                }
            }
            if (cell.DataType == CellValues.InlineString) return cell.InnerText ?? String.Empty;
            if (cell.CellValue != null) return cell.CellValue.Text ?? String.Empty;
        }
        if (cell.CellValue != null) return cell.CellValue.Text ?? String.Empty;
        if (cell.CellFormula != null) return cell.CellFormula.Text ?? String.Empty;
        return cell.InnerText ?? String.Empty;
    }

    private static int GetColumnIndex(string cellReference)
    {
        if (String.IsNullOrWhiteSpace(cellReference)) return 0;
        int index = 0;
        foreach (char c in cellReference.ToUpperInvariant())
        {
            if (c < 'A' || c > 'Z') break;
            index = (index * 26) + (c - 'A' + 1);
        }
        return index;
    }
}
