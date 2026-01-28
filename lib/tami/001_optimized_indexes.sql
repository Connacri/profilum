-- ==================== MIGRATION : INDEX DE RECHERCHE OPTIMISÉS ====================
-- Exécuter dans l'éditeur SQL de Supabase
-- Date: 2025-01-XX
-- Objectif: Accélérer les recherches et réduire les requêtes (économie quota)

-- ✅ 1. EXTENSION POUR RECHERCHE FULL-TEXT (Gratuit)
CREATE EXTENSION IF NOT EXISTS pg_trgm;  -- Recherche floue
CREATE EXTENSION IF NOT EXISTS unaccent; -- Ignore les accents

-- ✅ 2. INDEX DE BASE (Si pas déjà créés)
CREATE INDEX IF NOT EXISTS idx_documents_user_id
ON scanned_documents(user_id);

CREATE INDEX IF NOT EXISTS idx_documents_type
ON scanned_documents(document_type);

CREATE INDEX IF NOT EXISTS idx_documents_created_at
ON scanned_documents(created_at DESC);

-- ✅ 3. INDEX COMPOSÉS (Multi-colonnes pour requêtes complexes)

-- Index user + type (requêtes admin filtrées)
CREATE INDEX IF NOT EXISTS idx_documents_user_type
ON scanned_documents(user_id, document_type);

-- Index user + date (historique utilisateur)
CREATE INDEX IF NOT EXISTS idx_documents_user_date
ON scanned_documents(user_id, created_at DESC);

-- Index type + date (statistiques par type)
CREATE INDEX IF NOT EXISTS idx_documents_type_date
ON scanned_documents(document_type, created_at DESC);

-- ✅ 4. INDEX DE RECHERCHE PAR NOM (CRITIQUE)

-- Index GIN pour recherche floue insensible à la casse
CREATE INDEX IF NOT EXISTS idx_documents_fullname_gin
ON scanned_documents
USING gin(lower(full_name) gin_trgm_ops);

-- Index B-tree pour recherche exacte rapide
CREATE INDEX IF NOT EXISTS idx_documents_fullname_lower
ON scanned_documents(lower(full_name));

-- Index pour tri par nom
CREATE INDEX IF NOT EXISTS idx_documents_fullname_sort
ON scanned_documents(full_name);

-- ✅ 5. INDEX DE RECHERCHE PAR TÉLÉPHONE (CRITIQUE)

-- Index pour recherche par numéro (avec/sans +213)
CREATE INDEX IF NOT EXISTS idx_documents_phone
ON scanned_documents(phone_number);

-- Index pour recherche partielle (commence par...)
CREATE INDEX IF NOT EXISTS idx_documents_phone_prefix
ON scanned_documents(phone_number text_pattern_ops);

-- ✅ 6. INDEX DE RECHERCHE PAR NUMÉRO DE DOCUMENT (CRITIQUE)

-- Chifa
CREATE INDEX IF NOT EXISTS idx_documents_chifa_number
ON scanned_documents(chifa_number)
WHERE document_type = 'chifa' AND chifa_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_documents_chifa_gin
ON scanned_documents
USING gin(chifa_number gin_trgm_ops)
WHERE document_type = 'chifa';

-- CNI
CREATE INDEX IF NOT EXISTS idx_documents_cni_number
ON scanned_documents(cni_number)
WHERE document_type = 'cni' AND cni_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_documents_cni_gin
ON scanned_documents
USING gin(cni_number gin_trgm_ops)
WHERE document_type = 'cni';

-- Passeport
CREATE INDEX IF NOT EXISTS idx_documents_passport_number
ON scanned_documents(passport_number)
WHERE document_type = 'passport' AND passport_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_documents_passport_gin
ON scanned_documents
USING gin(passport_number gin_trgm_ops)
WHERE document_type = 'passport';

-- ✅ 7. INDEX DE RECHERCHE PAR DATE DE NAISSANCE (CRITIQUE)

-- Index pour recherche par date exacte
CREATE INDEX IF NOT EXISTS idx_documents_birthdate
ON scanned_documents(birth_date)
WHERE birth_date IS NOT NULL;

-- Index pour recherche par année de naissance
CREATE INDEX IF NOT EXISTS idx_documents_birth_year
ON scanned_documents(EXTRACT(YEAR FROM birth_date))
WHERE birth_date IS NOT NULL;

-- Index pour recherche par mois/année (anniversaires)
CREATE INDEX IF NOT EXISTS idx_documents_birth_month_year
ON scanned_documents(
  EXTRACT(MONTH FROM birth_date),
  EXTRACT(YEAR FROM birth_date)
) WHERE birth_date IS NOT NULL;

-- ✅ 8. INDEX DE RECHERCHE PAR VILLE/LIEU DE NAISSANCE (CRITIQUE)

-- CNI : Lieu de naissance
CREATE INDEX IF NOT EXISTS idx_documents_cni_birthplace_gin
ON scanned_documents
USING gin(lower(cni_birth_place) gin_trgm_ops)
WHERE document_type = 'cni' AND cni_birth_place IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_documents_cni_birthplace
ON scanned_documents(lower(cni_birth_place))
WHERE document_type = 'cni';

-- Passeport : Lieu d'émission
CREATE INDEX IF NOT EXISTS idx_documents_passport_issueplace_gin
ON scanned_documents
USING gin(lower(passport_issue_place) gin_trgm_ops)
WHERE document_type = 'passport' AND passport_issue_place IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_documents_passport_issueplace
ON scanned_documents(lower(passport_issue_place))
WHERE document_type = 'passport';

-- ✅ 9. INDEX POUR STATISTIQUES (Optimise les dashboards)

-- Documents vérifiés manuellement
CREATE INDEX IF NOT EXISTS idx_documents_verified
ON scanned_documents(is_manually_verified, created_at DESC);

-- Documents avec faible confiance (alertes admin)
CREATE INDEX IF NOT EXISTS idx_documents_low_confidence
ON scanned_documents(confidence_score)
WHERE confidence_score < 0.7;

-- ✅ 10. FONCTION DE RECHERCHE OPTIMISÉE

CREATE OR REPLACE FUNCTION search_documents(
  search_query TEXT,
  user_filter UUID DEFAULT NULL,
  type_filter TEXT DEFAULT NULL,
  date_from TIMESTAMP DEFAULT NULL,
  date_to TIMESTAMP DEFAULT NULL,
  limit_results INT DEFAULT 50
)
RETURNS TABLE (
  id UUID,
  document_type TEXT,
  full_name TEXT,
  phone_number TEXT,
  birth_date DATE,
  created_at TIMESTAMP WITH TIME ZONE,
  document_number TEXT,
  similarity_score REAL
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    d.id,
    d.document_type,
    d.full_name,
    d.phone_number,
    d.birth_date,
    d.created_at,
    COALESCE(d.chifa_number, d.cni_number, d.passport_number) as document_number,
    GREATEST(
      similarity(lower(d.full_name), lower(search_query)),
      similarity(d.phone_number, search_query),
      similarity(COALESCE(d.chifa_number, d.cni_number, d.passport_number, ''), search_query)
    ) as similarity_score
  FROM scanned_documents d
  WHERE
    -- Filtre par user si spécifié
    (user_filter IS NULL OR d.user_id = user_filter)

    -- Filtre par type si spécifié
    AND (type_filter IS NULL OR d.document_type = type_filter)

    -- Filtre par date si spécifié
    AND (date_from IS NULL OR d.created_at >= date_from)
    AND (date_to IS NULL OR d.created_at <= date_to)

    -- Recherche multi-critères
    AND (
      lower(d.full_name) LIKE '%' || lower(search_query) || '%'
      OR d.phone_number LIKE '%' || search_query || '%'
      OR d.chifa_number LIKE '%' || search_query || '%'
      OR d.cni_number LIKE '%' || search_query || '%'
      OR d.passport_number LIKE '%' || search_query || '%'
      OR lower(d.cni_birth_place) LIKE '%' || lower(search_query) || '%'
      OR lower(d.passport_issue_place) LIKE '%' || lower(search_query) || '%'
      OR CAST(d.birth_date AS TEXT) LIKE '%' || search_query || '%'
    )
  ORDER BY similarity_score DESC, d.created_at DESC
  LIMIT limit_results;
END;
$$ LANGUAGE plpgsql STABLE;

-- ✅ 11. VUE MATÉRIALISÉE POUR STATS (Cache, réduit drastiquement les requêtes)

CREATE MATERIALIZED VIEW IF NOT EXISTS document_stats_cache AS
SELECT
  document_type,
  COUNT(*) as total_count,
  COUNT(DISTINCT user_id) as unique_users,
  AVG(confidence_score) as avg_confidence,
  COUNT(*) FILTER (WHERE is_manually_verified = true) as verified_count,
  COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE) as today_count,
  COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE - INTERVAL '7 days') as week_count,
  COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE - INTERVAL '30 days') as month_count,
  MAX(created_at) as last_created,
  MIN(created_at) as first_created
FROM scanned_documents
GROUP BY document_type;

-- Index sur la vue matérialisée
CREATE UNIQUE INDEX IF NOT EXISTS idx_stats_cache_type
ON document_stats_cache(document_type);

-- ✅ 12. FONCTION DE RAFRAÎCHISSEMENT AUTO (Appeler toutes les heures)

CREATE OR REPLACE FUNCTION refresh_stats_cache()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY document_stats_cache;
END;
$$ LANGUAGE plpgsql;

-- ✅ 13. NETTOYAGE AUTOMATIQUE (Optionnel - libère de l'espace)

CREATE OR REPLACE FUNCTION cleanup_old_documents()
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  -- Supprime les documents > 5 ans (ajuster selon besoins)
  DELETE FROM scanned_documents
  WHERE created_at < NOW() - INTERVAL '5 years';

  GET DIAGNOSTICS deleted_count = ROW_COUNT;

  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- ✅ 14. POLITIQUE RLS OPTIMISÉE (Sécurité + Performance)

-- Drop anciennes policies si existantes
DROP POLICY IF EXISTS "Users can manage their own documents" ON scanned_documents;
DROP POLICY IF EXISTS "Admins can view all documents" ON scanned_documents;
DROP POLICY IF EXISTS "Super Admin and Admin can modify all" ON scanned_documents;

-- Policy User (READ + WRITE ses propres docs)
CREATE POLICY "users_own_documents"
ON scanned_documents
FOR ALL
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Policy Admin (READ ONLY tous les docs)
CREATE POLICY "admins_read_all"
ON scanned_documents
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM admin_users
    WHERE id = auth.uid()
    AND is_active = true
  )
);

-- Policy Admin (WRITE tous les docs - sauf ReadOnly)
CREATE POLICY "admins_write_all"
ON scanned_documents
FOR INSERT, UPDATE, DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM admin_users
    WHERE id = auth.uid()
    AND is_active = true
    AND role IN ('superAdmin', 'admin')
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM admin_users
    WHERE id = auth.uid()
    AND is_active = true
    AND role IN ('superAdmin', 'admin')
  )
);

-- ✅ 15. COMMENTAIRES POUR DOCUMENTATION

COMMENT ON FUNCTION search_documents IS 'Recherche multi-critères optimisée avec similarité';
COMMENT ON MATERIALIZED VIEW document_stats_cache IS 'Cache des statistiques (rafraîchir toutes les heures)';
COMMENT ON FUNCTION refresh_stats_cache IS 'Rafraîchit le cache des stats (CRON toutes les heures)';
COMMENT ON FUNCTION cleanup_old_documents IS 'Nettoie les vieux documents (CRON mensuel)';

-- ✅ 16. ANALYSE DES INDEX (Force PostgreSQL à optimiser)

ANALYZE scanned_documents;
ANALYZE admin_users;

-- FIN DE LA MIGRATION