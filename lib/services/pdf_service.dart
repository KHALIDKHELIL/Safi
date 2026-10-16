import 'package:flutter/material.dart'; 
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/contact_model.dart';
import '../models/loan_model.dart';

class PdfService {
  static Future<void> generateAndShareStatement(Contact contact, List<Loan> contactLoans) async {
    final pdf = pw.Document();
    
    double totalOwedToYou = 0;
    double totalYouOwe = 0;
    
    for (final loan in contactLoans) {
      if (!loan.isSettled) {
        if (loan.type == LoanType.lent) totalOwedToYou += loan.remainingAmount;
        if (loan.type == LoanType.borrowed) totalYouOwe += loan.remainingAmount;
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('SAFI LEDGER STATEMENT', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
                  pw.Text(DateFormat('MMM d, yyyy').format(DateTime.now()), style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text('Account: ${contact.name}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              if (contact.phoneNumber != null) pw.Text('Phone: ${contact.phoneNumber}', style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 12),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: const pw.BoxDecoration(color: PdfColors.grey200, borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Text('Owed to You: +$totalOwedToYou ETB', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                    pw.Text('You Owe: -$totalYouOwe ETB', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Transaction History', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                context: context,
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
                headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                data: <List<String>>[
                  ['Date', 'Type', 'Reason', 'Original', 'Paid', 'Remaining', 'Status'],
                  ...contactLoans.map((loan) => [
                    DateFormat('MM/dd/yy').format(loan.timestamp),
                    loan.type == LoanType.lent ? 'Lent' : 'Borrowed',
                    loan.reason != null && loan.reason!.isNotEmpty ? loan.reason! : '-',
                    '${loan.amount.toStringAsFixed(0)} ETB',
                    '${loan.paidAmount.toStringAsFixed(0)} ETB',
                    '${loan.remainingAmount.toStringAsFixed(0)} ETB',
                    loan.isSettled ? 'Settled' : 'Active',
                  ]),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Statement_${contact.name}.pdf');
  }

  static Future<void> generateMasterReport({
    required List<Loan> loans,
    required List<Contact> contacts,
    DateTimeRange? dateRange,
  }) async {
    final pdf = pw.Document();

    final filteredLoans = dateRange == null
        ? loans
        : loans.where((l) => l.timestamp.isAfter(dateRange.start.subtract(const Duration(seconds: 1))) &&
                             l.timestamp.isBefore(dateRange.end.add(const Duration(days: 1)))).toList();

    double totalLent = 0;
    double totalBorrowed = 0;
    double totalCollected = 0;

    for (final l in filteredLoans) {
      if (l.type == LoanType.lent) {
        totalLent += l.amount;
        totalCollected += l.isSettled ? l.amount : l.paidAmount;
      } else {
        totalBorrowed += l.amount;
      }
    }

    final dateRangeLabel = dateRange == null
        ? 'All-Time Records'
        : '${DateFormat('MMM d, yyyy').format(dateRange.start)} - ${DateFormat('MMM d, yyyy').format(dateRange.end)}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('SAFI MASTER AUDIT REPORT', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
              pw.Text(DateFormat('MMM d, yyyy').format(DateTime.now()), style: const pw.TextStyle(fontSize: 11)),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text('Coverage: $dateRangeLabel', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: const pw.BoxDecoration(color: PdfColors.grey200, borderRadius: pw.BorderRadius.all(pw.Radius.circular(8))),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Text('Total Lent: ${totalLent.toStringAsFixed(0)} ETB', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                pw.Text('Total Borrowed: ${totalBorrowed.toStringAsFixed(0)} ETB', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
                pw.Text('Collected: ${totalCollected.toStringAsFixed(0)} ETB', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Detailed Transactions (${filteredLoans.length})', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            context: context,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
            headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
            data: <List<String>>[
              ['Date', 'Party', 'Type', 'Reason', 'Amount', 'Remaining', 'Status'],
              ...filteredLoans.map((loan) {
                final contactName = contacts.firstWhere((c) => c.id == loan.contactId, orElse: () => const Contact(id: '', name: 'Unknown')).name;
                return [
                  DateFormat('MM/dd/yyyy').format(loan.timestamp),
                  contactName,
                  loan.type == LoanType.lent ? 'Lent' : 'Borrowed',
                  loan.reason != null && loan.reason!.isNotEmpty ? loan.reason! : '-',
                  '${loan.amount.toStringAsFixed(0)} ETB',
                  '${loan.remainingAmount.toStringAsFixed(0)} ETB',
                  loan.isSettled ? 'Settled' : 'Active',
                ];
              }),
            ],
          ),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Safi_Master_Report_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }
}