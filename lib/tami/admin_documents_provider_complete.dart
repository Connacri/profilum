// ==================== ADMIN DOCUMENTS PROVIDER COMPLET ====================

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_models.dart';
import 'models_unified.dart';

class AdminDocumentsProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  List<ScannedDocument> _allDocuments = [];
  List<ScannedDocument> _filteredDocuments = [];
  DocumentStats _stats = DocumentStats.empty();

  bool _isLoading = false;
  String? _errorMessage;

  // Filtres
  String _searchQuery = '';
  DocumentType? _filterType;
  DateTimeRange? _dateRange;

  // Getters publics
  List<ScannedDocument> get allDocuments => _allDocuments;
  List<ScannedDocument> get filteredDocuments => _filteredDocuments;
  DocumentStats get stats => _stats;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Getters pour statistiques rapides
  int get totalDocuments => _stats.total;
  int get totalChifa => _stats.chifa;
  int get totalCNI => _stats.cni;
  int get totalPassport => _stats.passport;

  // Getters pour filtres (exposés)
  DocumentType? get filterType => _filterType;
  String get searchQuery => _searchQuery;
  DateTimeRange? get dateRange => _dateRange;

  /// Charger tous les documents avec statistiques optimisées
  Future<void> loadAllDocuments() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Charger les statistiques depuis la vue matérialisée
      await _loadStatsFromCache();

      // 2. Charger tous les documents
      final response = await _supabase
          .from('scanned_documents')
          .select()
          .order('created_at', ascending: false);

      _allDocuments = (response as List)
          .map((json) => ScannedDocument.fromSupabaseJson(json))
          .toList();

      // 3. Calculer les statistiques détaillées
      _calculateDetailedStats();

      // 4. Appliquer les filtres
      _applyFilters();
    } catch (e) {
      _errorMessage = 'Erreur chargement: $e';
      debugPrint('AdminDocumentsProvider.loadAllDocuments: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charger les stats depuis la vue matérialisée (ultra rapide)
  Future<void> _loadStatsFromCache() async {
    try {
      final response = await _supabase.from('document_stats_cache').select();

      if (response.isNotEmpty) {
        // Agréger les stats par type
        int totalChifa = 0;
        int totalCni = 0;
        int totalPassport = 0;
        int totalAll = 0;
        int todayAll = 0;
        int weekAll = 0;
        int monthAll = 0;
        int verifiedAll = 0;

        for (final row in response) {
          final type = row['document_type'];
          final count = row['total_count'] ?? 0;

          totalAll += count as int;
          todayAll += (row['today_count'] ?? 0) as int;
          weekAll += (row['week_count'] ?? 0) as int;
          monthAll += (row['month_count'] ?? 0) as int;
          verifiedAll += (row['verified_count'] ?? 0) as int;

          if (type == 'chifa') totalChifa = count;
          if (type == 'cni') totalCni = count;
          if (type == 'passport') totalPassport = count;
        }

        _stats = DocumentStats(
          total: totalAll,
          chifa: totalChifa,
          cni: totalCni,
          passport: totalPassport,
          today: todayAll,
          week: weekAll,
          month: monthAll,
          verified: verifiedAll,
        );
      }
    } catch (e) {
      debugPrint('Erreur _loadStatsFromCache: $e');
    }
  }

  /// Calculer les statistiques détaillées depuis les documents
  void _calculateDetailedStats() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = now.subtract(const Duration(days: 7));
    final monthAgo = DateTime(now.year, now.month - 1, now.day);

    _stats = DocumentStats(
      total: _allDocuments.length,
      chifa: _allDocuments.where((d) => d.type == DocumentType.chifa).length,
      cni: _allDocuments.where((d) => d.type == DocumentType.cni).length,
      passport:
          _allDocuments.where((d) => d.type == DocumentType.passport).length,
      today: _allDocuments.where((d) => d.createdAt.isAfter(today)).length,
      week: _allDocuments.where((d) => d.createdAt.isAfter(weekAgo)).length,
      month: _allDocuments.where((d) => d.createdAt.isAfter(monthAgo)).length,
      verified: _allDocuments.where((d) => d.isManuallyVerified).length,
      lowConfidence: _allDocuments.where((d) => d.confidenceScore < 0.7).length,
    );
  }

  /// Mettre à jour la recherche
  void updateSearch(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  /// Mettre à jour le filtre de type
  void updateTypeFilter(DocumentType? type) {
    _filterType = type;
    _applyFilters();
  }

  /// Mettre à jour le filtre de date
  void updateDateFilter(DateTimeRange? range) {
    _dateRange = range;
    _applyFilters();
  }

  /// Effacer tous les filtres
  void clearFilters() {
    _searchQuery = '';
    _filterType = null;
    _dateRange = null;
    _applyFilters();
  }

  /// Appliquer les filtres
  void _applyFilters() {
    _filteredDocuments = _allDocuments.where((doc) {
      // Filtre recherche
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesName = doc.fullName.toLowerCase().contains(query);
        final matchesPhone = doc.phoneNumber.toLowerCase().contains(query);

        String? docNumber;
        if (doc is ChifaCard) docNumber = doc.chifaNumber;
        if (doc is CNICard) docNumber = doc.cniNumber;
        if (doc is PassportCard) docNumber = doc.passportNumber;

        final matchesNumber = docNumber?.toLowerCase().contains(query) ?? false;

        if (!matchesName && !matchesPhone && !matchesNumber) {
          return false;
        }
      }

      // Filtre type
      if (_filterType != null && doc.type != _filterType) {
        return false;
      }

      // Filtre date
      if (_dateRange != null) {
        if (doc.createdAt.isBefore(_dateRange!.start) ||
            doc.createdAt
                .isAfter(_dateRange!.end.add(const Duration(days: 1)))) {
          return false;
        }
      }

      return true;
    }).toList();

    notifyListeners();
  }

  /// Recherche avancée avec fonction SQL optimisée
  Future<List<ScannedDocument>> advancedSearch({
    required String query,
    DocumentType? typeFilter,
    DateTimeRange? dateRange,
    int limit = 50,
  }) async {
    try {
      final params = {
        'search_query': query,
        'type_filter': typeFilter?.name,
        'date_from': dateRange?.start.toIso8601String(),
        'date_to': dateRange?.end.toIso8601String(),
        'limit_results': limit,
      };

      final response = await _supabase.rpc('search_documents', params: params);

      return (response as List)
          .map((json) => ScannedDocument.fromSupabaseJson(json))
          .toList();
    } catch (e) {
      _errorMessage = 'Erreur recherche avancée: $e';
      notifyListeners();
      return [];
    }
  }

  /// Supprimer un document
  Future<bool> deleteDocument(String documentId) async {
    try {
      await _supabase.from('scanned_documents').delete().eq('id', documentId);
      await loadAllDocuments();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur suppression: $e';
      notifyListeners();
      return false;
    }
  }

  /// Exporter en PDF
  Future<void> exportToPDF(List<ScannedDocument> documents) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          // En-tête
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'EHS Dr Medjbeur Tami',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text('Rapport des documents scannés'),
                pw.Text(
                  'Généré le ${DateFormat('dd/MM/yyyy à HH:mm', 'fr').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 10),
                pw.Divider(),
              ],
            ),
          ),

          // Statistiques
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            color: PdfColors.grey200,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Statistiques',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),
                pw.Text('Total de documents: ${documents.length}'),
                pw.Text(
                    'Cartes Chifa: ${documents.where((d) => d.type == DocumentType.chifa).length}'),
                pw.Text(
                    'CNI: ${documents.where((d) => d.type == DocumentType.cni).length}'),
                pw.Text(
                    'Passeports: ${documents.where((d) => d.type == DocumentType.passport).length}'),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Table
          pw.Text('Liste des documents',
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
            border: pw.TableBorder.all(),
            headerStyle:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            headers: ['Type', 'Nom', 'Téléphone', 'Numéro', 'Date'],
            data: documents.map((doc) {
              String number = '';
              if (doc is ChifaCard) number = doc.chifaNumber;
              if (doc is CNICard) number = doc.cniNumber;
              if (doc is PassportCard) number = doc.passportNumber;

              return [
                doc.type.label,
                doc.fullName,
                '+213 ${doc.phoneNumber}',
                number,
                DateFormat('dd/MM/yyyy', 'fr').format(doc.createdAt),
              ];
            }).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  /// Exporter en CSV
  Future<String> exportToCSV(List<ScannedDocument> documents) async {
    final rows = <List<dynamic>>[
      [
        'Type',
        'Nom Complet',
        'Téléphone',
        'Numéro Document',
        'Date Naissance',
        'Date Enregistrement',
        'Confiance (%)',
        'Vérifié'
      ],
    ];

    for (final doc in documents) {
      String number = '';
      if (doc is ChifaCard) number = doc.chifaNumber;
      if (doc is CNICard) number = doc.cniNumber;
      if (doc is PassportCard) number = doc.passportNumber;

      rows.add([
        doc.type.label,
        doc.fullName,
        '+213${doc.phoneNumber}',
        number,
        doc.birthDate != null
            ? DateFormat('dd/MM/yyyy').format(doc.birthDate!)
            : '',
        DateFormat('dd/MM/yyyy HH:mm').format(doc.createdAt),
        (doc.confidenceScore * 100).toInt(),
        doc.isManuallyVerified ? 'Oui' : 'Non',
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Rafraîchir le cache des statistiques (à appeler régulièrement)
  Future<void> refreshStatsCache() async {
    try {
      await _supabase.rpc('refresh_stats_cache');
    } catch (e) {
      debugPrint('Erreur refreshStatsCache: $e');
    }
  }
}
