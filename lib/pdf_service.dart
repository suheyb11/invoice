// Builds a professional A4 PDF for a quotation or invoice, then prints or shares it.
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'models.dart';
import 'widgets.dart';

class PdfService {
  static final PdfColor primary = PdfColor.fromHex('#4F46E5');
  static final PdfColor muted = PdfColor.fromHex('#6B7280');
  static final PdfColor light = PdfColor.fromHex('#F3F4F6');

  static Future<Uint8List> build(Doc doc) async {
    final s = App.settings;
    final pdf = pw.Document(title: doc.number, author: s['company_name'] ?? '');
    final title = doc.isQuote ? 'QUOTATION' : 'INVOICE';

    final rows = <List<String>>[];
    for (var i = 0; i < doc.items.length; i++) {
      final it = doc.items[i];
      rows.add([
        '${i + 1}',
        it.description,
        qtyText(it.qty),
        money(it.unitPrice),
        it.discountPercent > 0 ? '${qtyText(it.discountPercent)}%' : '-',
        it.taxRate > 0 ? '${qtyText(it.taxRate)}%' : '-',
        money(it.net),
      ]);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (ctx) => pw.Row(
          children: [
            pw.Expanded(child: pw.Text(s['company_name'] ?? '', style: pw.TextStyle(fontSize: 8, color: muted))),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: pw.TextStyle(fontSize: 8, color: muted)),
          ],
        ),
        build: (ctx) => [
          // ---------- Header
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(s['company_name'] ?? '', style: const pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    if ((s['company_address'] ?? '').isNotEmpty) pw.Text(s['company_address']!, style: pw.TextStyle(color: muted, fontSize: 9.5)),
                    if ((s['company_phone'] ?? '').isNotEmpty) pw.Text(s['company_phone']!, style: pw.TextStyle(color: muted, fontSize: 9.5)),
                    if ((s['company_email'] ?? '').isNotEmpty) pw.Text(s['company_email']!, style: pw.TextStyle(color: muted, fontSize: 9.5)),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: primary, letterSpacing: 1.5)),
                  pw.SizedBox(height: 6),
                  pw.Text(doc.number, style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text('Date: ${niceDate(doc.date)}', style: const pw.TextStyle(fontSize: 9.5)),
                  pw.Text('${doc.isQuote ? 'Valid until' : 'Due date'}: ${niceDate(doc.dueDate)}', style: const pw.TextStyle(fontSize: 9.5)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 22),

          // ---------- Bill to
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: light, borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(doc.isQuote ? 'PREPARED FOR' : 'BILL TO',
                    style: pw.TextStyle(fontSize: 8, color: muted, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
                pw.SizedBox(height: 4),
                pw.Text(doc.customerName, style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                if (doc.customerAddress.isNotEmpty) pw.Text(doc.customerAddress, style: const pw.TextStyle(fontSize: 9.5)),
                if (doc.customerPhone.isNotEmpty) pw.Text(doc.customerPhone, style: const pw.TextStyle(fontSize: 9.5)),
                if (doc.customerEmail.isNotEmpty) pw.Text(doc.customerEmail, style: const pw.TextStyle(fontSize: 9.5)),
              ],
            ),
          ),
          pw.SizedBox(height: 18),

          // ---------- Items table
          pw.TableHelper.fromTextArray(
            headers: ['#', 'Description', 'Qty', 'Price', 'Disc.', 'Tax', 'Amount'],
            data: rows,
            border: null,
            headerStyle: const pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9.5),
            headerDecoration: pw.BoxDecoration(color: primary),
            cellStyle: const pw.TextStyle(fontSize: 9.5),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
            oddRowDecoration: pw.BoxDecoration(color: light),
            columnWidths: {
              0: const pw.FixedColumnWidth(22),
              1: const pw.FlexColumnWidth(4),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1.6),
              4: const pw.FlexColumnWidth(1),
              5: const pw.FlexColumnWidth(1),
              6: const pw.FlexColumnWidth(1.8),
            },
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
            },
          ),
          pw.SizedBox(height: 14),

          // ---------- Totals
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: stamp(doc)),
              pw.SizedBox(
                width: 220,
                child: pw.Column(
                  children: [
                    totalRow('Subtotal', money(doc.subtotal)),
                    if (doc.discountTotal > 0) totalRow('Discount', '- ${money(doc.discountTotal)}'),
                    totalRow('Tax', money(doc.taxTotal)),
                    pw.Divider(color: muted, thickness: 0.5),
                    totalRow('Total', money(doc.total), bold: true),
                    if (!doc.isQuote && doc.paid > 0) ...[
                      totalRow('Paid', money(doc.paid)),
                      pw.Container(
                        margin: const pw.EdgeInsets.only(top: 4),
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        color: light,
                        child: totalRow('Balance due', money(doc.balance), bold: true),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // ---------- Notes & terms
          if (doc.notes.isNotEmpty) ...[
            pw.SizedBox(height: 22),
            pw.Text('Notes', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.SizedBox(height: 3),
            pw.Text(doc.notes, style: const pw.TextStyle(fontSize: 9.5)),
          ],
          if (doc.terms.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text('Terms & conditions', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.SizedBox(height: 3),
            pw.Text(doc.terms, style: pw.TextStyle(fontSize: 9, color: muted)),
          ],
          pw.SizedBox(height: 30),
          pw.Center(child: pw.Text('Thank you for your business!', style: pw.TextStyle(color: primary, fontWeight: pw.FontWeight.bold))),
        ],
      ),
    );
    return pdf.save();
  }

  static pw.Widget totalRow(String label, String value, {bool bold = false}) {
    final style = pw.TextStyle(fontSize: bold ? 11.5 : 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(children: [pw.Expanded(child: pw.Text(label, style: style)), pw.Text(value, style: style)]),
    );
  }

  // A big coloured status stamp (PAID, OVERDUE, ACCEPTED...)
  static pw.Widget stamp(Doc doc) {
    const show = ['paid', 'overdue', 'cancelled', 'accepted', 'rejected', 'expired', 'partial'];
    if (!show.contains(doc.status)) return pw.SizedBox();
    PdfColor color = muted;
    if (doc.status == 'paid' || doc.status == 'accepted') color = PdfColors.green700;
    if (doc.status == 'overdue' || doc.status == 'rejected') color = PdfColors.red700;
    if (doc.status == 'partial') color = PdfColors.orange700;
    return pw.Transform.rotate(
      angle: 0.12,
      child: pw.Container(
        margin: const pw.EdgeInsets.only(top: 10, left: 20),
        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: color, width: 2), borderRadius: pw.BorderRadius.circular(6)),
        child: pw.Text(doc.status.toUpperCase(), style: pw.TextStyle(color: color, fontSize: 20, fontWeight: pw.FontWeight.bold, letterSpacing: 2)),
      ),
    );
  }

  static Future<void> printDoc(Doc doc) async {
    await Printing.layoutPdf(name: doc.number, onLayout: (format) => build(doc));
  }

  static Future<void> shareDoc(Doc doc) async {
    final bytes = await build(doc);
    await Printing.sharePdf(bytes: bytes, filename: '${doc.number}.pdf');
  }
}
