-- تعليق عربي: أرشفة مستندات الحجز والصرف كملفات محفوظة على الخادم مع سجل داخل قاعدة البيانات.

CREATE TABLE IF NOT EXISTS document_attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type VARCHAR(30) NOT NULL,
  entity_id UUID NOT NULL,
  original_file_name VARCHAR(300) NOT NULL,
  stored_file_name VARCHAR(300) NOT NULL,
  content_type VARCHAR(150) NOT NULL,
  file_size BIGINT NOT NULL CHECK (file_size > 0),
  storage_path TEXT NOT NULL,
  notes TEXT,
  uploaded_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  deleted_by UUID REFERENCES users(id),
  CONSTRAINT chk_document_attachments_entity_type
    CHECK (entity_type IN ('reservation', 'expense'))
);

CREATE INDEX IF NOT EXISTS idx_document_attachments_entity
  ON document_attachments(entity_type, entity_id, created_at DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_document_attachments_uploaded_by
  ON document_attachments(uploaded_by, created_at DESC)
  WHERE deleted_at IS NULL;
