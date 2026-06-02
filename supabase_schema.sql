-- =========================================================================
-- DocVault AI - Supabase Initialization Script
-- Execute this entire script in your Supabase SQL Editor.
-- =========================================================================

-- 1. Create the `documents` table
-- Note: Column names are in double-quotes to match Drift's camelCase JSON exactly
CREATE TABLE IF NOT EXISTS public.documents (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    filename TEXT NOT NULL,
    "localPath" TEXT NOT NULL,
    "thumbPath" TEXT,
    category TEXT NOT NULL,
    subcategory TEXT,
    "documentDate" TEXT,
    "expiryDate" TEXT,
    confidence REAL DEFAULT 0.0,
    "fileHash" TEXT,
    "isTampered" BOOLEAN DEFAULT false,
    "rawText" TEXT,
    "isSynced" BOOLEAN DEFAULT false,
    "createdAt" BIGINT,
    "updatedAt" BIGINT
);

-- 2. Create the `document_fields` table
CREATE TABLE IF NOT EXISTS public.document_fields (
    id SERIAL PRIMARY KEY,
    "documentId" TEXT NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
    label TEXT NOT NULL,
    value TEXT NOT NULL,
    confidence REAL DEFAULT 0.0,
    "isCopyable" BOOLEAN DEFAULT true
);

-- =========================================================================
-- Row Level Security (RLS)
-- =========================================================================

-- Enable RLS
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_fields ENABLE ROW LEVEL SECURITY;

-- documents: User can only see/edit their own rows
CREATE POLICY "Users can manage their own documents"
    ON public.documents
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- document_fields: User can manage fields attached to their documents
CREATE POLICY "Users can manage fields of their documents"
    ON public.document_fields
    FOR ALL
    USING (
         "documentId" IN (SELECT id FROM public.documents WHERE user_id = auth.uid())
    )
    WITH CHECK (
         "documentId" IN (SELECT id FROM public.documents WHERE user_id = auth.uid())
    );

-- =========================================================================
-- Storage Buckets
-- =========================================================================

-- Create the "documents" storage bucket for scanned images
INSERT INTO storage.buckets (id, name, public) 
VALUES ('documents', 'documents', false)
ON CONFLICT (id) DO NOTHING;

-- Enable RLS on storage
-- Note: 'storage.objects' is the built-in Supabase table for file storage.
-- Users can only upload and read files inside their own `user_id/` folder prefix.
CREATE POLICY "Users can upload to their own folder"
    ON storage.objects FOR INSERT 
    WITH CHECK ( bucket_id = 'documents' AND (storage.foldername(name))[1] = auth.uid()::text );

CREATE POLICY "Users can read their own files"
    ON storage.objects FOR SELECT
    USING ( bucket_id = 'documents' AND (storage.foldername(name))[1] = auth.uid()::text );

CREATE POLICY "Users can update their own files"
    ON storage.objects FOR UPDATE
    USING ( bucket_id = 'documents' AND (storage.foldername(name))[1] = auth.uid()::text );

CREATE POLICY "Users can delete their own files"
    ON storage.objects FOR DELETE
    USING ( bucket_id = 'documents' AND (storage.foldername(name))[1] = auth.uid()::text );

-- =========================================================================
-- Share Links Table (used by share_link_service.py)
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.shared_links (
    id          BIGSERIAL PRIMARY KEY,
    document_id TEXT NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token       TEXT NOT NULL UNIQUE,
    expires_at  TIMESTAMPTZ NOT NULL,
    is_active   BOOLEAN DEFAULT true,
    created_at  TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.shared_links ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage their own share links"
    ON public.shared_links
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
