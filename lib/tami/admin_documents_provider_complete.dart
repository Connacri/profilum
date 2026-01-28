// ==================== ADMIN DOCUMENTS PROVIDER OPTIMISÉ ====================
// providers/admin_documents_provider.dart

import 'dart:async';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models_unified.dart';



// ==================== MODÈLE DE STATISTIQUES ====================
class DocumentStats {
  final int total;
  final int chifa;
  final int cni;
  final int passport;
  final int today;
  final int week;
  final int month;
  final int verified;
  final int lowConfidence;

  const DocumentStats({
    required this.total,
    required this.chifa,
    required this.cni,
    required this.passport,
    required this.today,
    required this.week,
    required this.month,
    required this.verified,
    this.lowConfidence = 0,
  });

  factory DocumentStats.empty() => const DocumentStats(
    total: 0,
    chifa: 0,
    cni: 0,
    passport: 0,
    today: 0,
    week: 0,
    month: 0,
    verified: 0,
  );

  DocumentStats copyWith({
    int? total,
    int? chifa,
    int? cni,
    int? passport,
    int? today,
    int? week,
    int? month,
    int? verified,
    int? lowConfidence,
  }) {
    return DocumentStats(
      total: total ?? this.total,
      chifa: chifa ?? this.chifa,
      cni: cni ?? this.cni,
      passport: passport ?? this.passport,
      today: today ?? this.today,
      week: week ?? this.week,
      month: month ?? this.month,
      verified: verified ?? this.verified,
      lowConfidence: lowConfidence ?? this.lowConfidence,
    );
  }
}

// ==================== PROVIDER ADMIN ====================
class AdminDocumentsProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  // Cache timer pour auto-refresh
  Timer? _cacheRefreshTimer;
  static const _cacheRefreshInterval = Duration(minutes: 5);

  // États
  List<ScannedDocument> _allDocuments = [];
  List<ScannedDocument> _filteredDocuments = [];
  DocumentStats _stats = DocumentStats.empty();

  bool _isLoading = false;
  bool _isPaginating = false;
  String? _errorMessage;

  // Pagination
  static const _pageSize = 50;
  int _currentPage = 0;
  bool _hasMoreData = true;

  // Filtres
  String _searchQuery = '';
  DocumentType? _filterType;
  DateTimeRange? _dateRange;
  bool _showOnlyUnverified = false;

  // Getters publics
  List<ScannedDocument> get allDocuments => List.unmodifiable(_allDocuments);
  List<ScannedDocument> get filteredDocuments => List.unmodifiable(_filteredDocuments);
  DocumentStats get stats => _stats;
  bool get isLoading => _isLoading;
  bool get isPaginating => _isPaginating;
  bool get hasMoreData => _hasMoreData;
  String? get errorMessage => _errorMessage;

  // Getters statistiques
  int get totalDocuments => _stats.total;
  int get totalChifa => _stats.chifa;
  int get totalCNI => _stats.cni;
  int get totalPassport => _stats.passport;

  // Getters filtres
  DocumentType? get filterType => _filterType;
  String get searchQuery => _searchQuery;
  DateTimeRange? get dateRange => _dateRange;
  bool get showOnlyUnverified => _showOnlyUnverified;

  AdminDocumentsProvider() {
    _startCacheRefreshTimer();
  }

  @override
  void dispose() {
    _cacheRefreshTimer?.cancel();
    super.dispose();
  }

  // ==================== TIMER AUTO-REFRESH ====================
  void _startCacheRefreshTimer() {
    _cacheRefreshTimer = Timer.periodic(_cacheRefreshInterval, (_) {
      refreshStatsCache();
    });
  }

  // ==================== CHARGEMENT INITIAL ====================
  /// Charger tous les documents avec pagination
  Future<void> loadAllDocuments({bool forceRefresh = false}) async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    _currentPage = 0;
    _hasMoreData = true;

    if (forceRefresh) {
      _allDocuments.clear();
    }

    notifyListeners();

    try {
      // 1. Charger stats depuis cache (ultra rapide)
      await _loadStatsFromCache();

      // 2. Charger première page de documents
      await _loadDocumentPage();

      // 3. Appliquer filtres
      _applyFilters();
    } catch (e) {
      _errorMessage = 'Erreur chargement: ${e.toString()}';
      debugPrint('AdminDocumentsProvider.loadAllDocuments: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charger une page de documents
  Future<void> _loadDocumentPage() async {
    try {
      final from = _currentPage * _pageSize;
      final to = from + _pageSize - 1;

      final response = await _supabase
          .from('scanned_documents')
          .select()
          .order('created_at', ascending: false)
          .range(from, to);

      final List<dynamic> data = response as List;

      if (data.isEmpty) {
        _hasMoreData = false;
        return;
      }

      final newDocs = data
          .map((json) => ScannedDocument.fromSupabaseJson(json))
          .toList();

      _allDocuments.addAll(newDocs);
      _hasMoreData = data.length == _pageSize;
      _currentPage++;
    } catch (e) {
      _errorMessage = 'Erreur pagination: ${e.toString()}';
      _hasMoreData = false;
      rethrow;
    }
  }

  /// Charger page suivante (scroll infini)
  Future<void> loadNextPage() async {
    if (_isPaginating || !_hasMoreData || _isLoading) return;

    _isPaginating = true;
    notifyListeners();

    try {
      await _loadDocumentPage();
      _applyFilters();
    } catch (e) {
      debugPrint('AdminDocumentsProvider.loadNextPage: $e');
    } finally {
      _isPaginating = false;
      notifyListeners();
    }
  }

  // ==================== STATISTIQUES OPTIMISÉES ====================
  /// Charger stats depuis vue matérialisée (cache SQL)
  Future<void> _loadStatsFromCache() async {
    try {
      final response = await _supabase
          .from('document_stats_cache')
          .select()
          .timeout(const Duration(seconds: 5));

      if (response.isEmpty) {
        // Fallback: calculer stats à la volée
        await _calculateStatsDirectly();
        return;
      }

      int totalChifa = 0;
      int totalCni = 0;
      int totalPassport = 0;
      int totalAll = 0;
      int todayAll = 0;
      int weekAll = 0;
      int monthAll = 0;
      int verifiedAll = 0;

      for (final row in response) {
        final type = row['document_type'] as String?;
        final count = (row['total_count'] ?? 0) as int;

        totalAll += count;
        todayAll += (row['today_count'] ?? 0) as int;
        weekAll += (row['week_count'] ?? 0) as int;
        monthAll += (row['month_count'] ?? 0) as int;
        verifiedAll += (row['verified_count'] ?? 0) as int;

        switch (type) {
          case 'chifa':
            totalChifa = count;
            break;
          case 'cni':
            totalCni = count;
            break;
          case 'passport':
            totalPassport = count;
            break;
        }
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
    } on TimeoutException {
      debugPrint('⚠️ Timeout stats cache, fallback calcul direct');
      await _calculateStatsDirectly();
    } catch (e) {
      debugPrint('⚠️ Erreur _loadStatsFromCache: $e, fallback calcul direct');
      await _calculateStatsDirectly();
    }
  }

  /// Calculer stats directement (fallback)
  Future<void> _calculateStatsDirectly() async {
    try {
      final response = await _supabase
          .from('scanned_documents')
          .select('type, created_at, is_manually_verified')
          .timeout(const Duration(seconds: 10));

      final List<dynamic> data = response as List;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final weekAgo = now.subtract(const Duration(days: 7));
      final monthAgo = DateTime(now.year, now.month - 1, now.day);

      int totalChifa = 0, totalCni = 0, totalPassport = 0;
      int todayCount = 0, weekCount = 0, monthCount = 0, verifiedCount = 0;

      for (final row in data) {
        final type = row['type'] as String?;
        final createdAt = DateTime.parse(row['created_at'] as String);
        final isVerified = row['is_manually_verified'] as bool? ?? false;

        // Comptage par type
        switch (type) {
          case 'chifa':
            totalChifa++;
            break;
          case 'cni':
            totalCni++;
            break;
          case 'passport':
            totalPassport++;
            break;
        }

        // Comptage temporel
        if (createdAt.isAfter(today)) todayCount++;
        if (createdAt.isAfter(weekAgo)) weekCount++;
        if (createdAt.isAfter(monthAgo)) monthCount++;
        if (isVerified) verifiedCount++;
      }

      _stats = DocumentStats(
        total: data.length,
        chifa: totalChifa,
        cni: totalCni,
        passport: totalPassport,
        today: todayCount,
        week: weekCount,
        month: monthCount,
        verified: verifiedCount,
      );
    } catch (e) {
      debugPrint('❌ Erreur _calculateStatsDirectly: $e');
      _stats = DocumentStats.empty();
    }
  }

  /// Rafraîchir cache stats (appel RPC)
  Future<void> refreshStatsCache() async {
    try {
      await _supabase
          .rpc('refresh_stats_cache')
          .timeout(const Duration(seconds: 10));
      debugPrint('✅ Cache stats rafraîchi');
    } catch (e) {
      debugPrint('⚠️ Erreur refreshStatsCache: $e');
    }
  }

  // ==================== FILTRES ====================
  void updateSearch(String query) {
    _searchQuery = query.trim();
    _applyFilters();
  }

  void updateTypeFilter(DocumentType? type) {
    _filterType = type;
    _applyFilters();
  }

  void updateDateFilter(DateTimeRange? range) {
    _dateRange = range;
    _applyFilters();
  }

  void toggleUnverifiedFilter() {
    _showOnlyUnverified = !_showOnlyUnverified;
    _applyFilters();
  }

  void clearFilters() {
    _searchQuery = '';
    _filterType = null;
    _dateRange = null;
    _showOnlyUnverified = false;
    _applyFilters();
  }

  /// Appliquer filtres (optimisé)
  void _applyFilters() {
    _filteredDocuments = _allDocuments.where((doc) {
      // Filtre recherche (nom, téléphone, numéro)
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesName = doc.fullName.toLowerCase().contains(query);
        final matchesPhone = doc.phoneNumber.contains(query);

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
        final start = _dateRange!.start;
        final end = _dateRange!.end.add(const Duration(days: 1));
        if (doc.createdAt.isBefore(start) || doc.createdAt.isAfter(end)) {
          return false;
        }
      }

      // Filtre non-vérifiés
      if (_showOnlyUnverified && doc.isManuallyVerified) {
        return false;
      }

      return true;
    }).toList();

    notifyListeners();
  }

  // ==================== RECHERCHE AVANCÉE ====================
  /// Recherche SQL optimisée (utilise RPC function)
  Future<List<ScannedDocument>> advancedSearch({
    required String query,
    DocumentType? typeFilter,
    DateTimeRange? dateRange,
    int limit = 50,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      final params = {
        'search_query': query.trim(),
        'type_filter': typeFilter?.name,
        'date_from': dateRange?.start.toIso8601String(),
        'date_to': dateRange?.end.toIso8601String(),
        'limit_results': limit,
      };

      final response = await _supabase
          .rpc('search_documents', params: params)
          .timeout(const Duration(seconds: 10));

      return (response as List)
          .map((json) => ScannedDocument.fromSupabaseJson(json))
          .toList();
    } on TimeoutException {
      _errorMessage = 'Recherche timeout, réessayez';
      notifyListeners();
      return [];
    } catch (e) {
      _errorMessage = 'Erreur recherche: ${e.toString()}';
      notifyListeners();
      return [];
    }
  }

  // ==================== ACTIONS CRUD ====================
  /// Supprimer document
  Future<bool> deleteDocument(String documentId) async {
    try {
      await _supabase
          .from('scanned_documents')
          .delete()
          .eq('id', documentId)
          .timeout(const Duration(seconds: 10));

      // Retirer du cache local
      _allDocuments.removeWhere((doc) => doc.id == documentId);
      _applyFilters();

      // Refresh stats
      await _loadStatsFromCache();

      return true;
    } on TimeoutException {
      _errorMessage = 'Suppression timeout';
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Erreur suppression: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Vérifier manuellement un document
  Future<bool> verifyDocument(String documentId) async {
    try {
      await _supabase
          .from('scanned_documents')
          .update({'is_manually_verified': true, 'verified_at': DateTime.now().toIso8601String()})
          .eq('id', documentId)
          .timeout(const Duration(seconds: 10));

      // Mettre à jour cache local
      final index = _allDocuments.indexWhere((doc) => doc.id == documentId);
      if (index != -1) {
        // Note: Il faudrait un copyWith sur ScannedDocument
        await loadAllDocuments(forceRefresh: true);
      }

      return true;
    } catch (e) {
      _errorMessage = 'Erreur vérification: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // ==================== EXPORT PDF ====================
  Future<void> exportToPDF(List<ScannedDocument> documents) async {
    try {
      final pdf = pw.Document();
      final font = await PdfGoogleFonts.notoSansRegular();
      final fontBold = await PdfGoogleFonts.notoSansBold();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          build: (context) => [
            // En-tête
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'EHS Dr Medjbeur Tami',
                    style: pw.TextStyle(fontSize: 24, font: fontBold),
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
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Statistiques', style: pw.TextStyle(fontSize: 16, font: fontBold)),
                  pw.SizedBox(height: 5),
                  pw.Text('Total de documents: ${documents.length}'),
                  pw.Text('Cartes Chifa: ${documents.where((d) => d.type == DocumentType.chifa).length}'),
                  pw.Text('CNI: ${documents.where((d) => d.type == DocumentType.cni).length}'),
                  pw.Text('Passeports: ${documents.where((d) => d.type == DocumentType.passport).length}'),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Table
            pw.Text('Liste des documents', style: pw.TextStyle(fontSize: 16, font: fontBold)),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              border: pw.TableBorder.all(),
              headerStyle: pw.TextStyle(font: fontBold, fontSize: 10),
              cellStyle: pw.TextStyle(font: font, fontSize: 9),
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
    } catch (e) {
      _errorMessage = 'Erreur export PDF: ${e.toString()}';
      notifyListeners();
      debugPrint('❌ Export PDF error: $e');
    }
  }

  // ==================== EXPORT CSV ====================
  Future<String> exportToCSV(List<ScannedDocument> documents) async {
    try {
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
          doc.birthDate != null ? DateFormat('dd/MM/yyyy').format(doc.birthDate!) : '',
          DateFormat('dd/MM/yyyy HH:mm').format(doc.createdAt),
          (doc.confidenceScore * 100).toInt(),
          doc.isManuallyVerified ? 'Oui' : 'Non',
        ]);
      }

      return const ListToCsvConverter().convert(rows);
    } catch (e) {
      _errorMessage = 'Erreur export CSV: ${e.toString()}';
      notifyListeners();
      return '';
    }
  }
}