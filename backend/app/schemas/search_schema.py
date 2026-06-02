"""
app/schemas/search_schema.py
============================
Pydantic v2 schemas for DigiSafe AI search endpoints.
"""

from __future__ import annotations

from typing import Optional

from pydantic import BaseModel


class SearchResultItem(BaseModel):
    id: str
    filename: str
    category: str
    subcategory: Optional[str] = None
    doc_type: Optional[str] = None
    match_field_label: Optional[str] = None   # which field matched
    match_field_value: Optional[str] = None   # the matched value
    match_highlight: Optional[str] = None     # value with ^^marked^^ text
    document_date: Optional[str] = None
    created_at: str


class SearchResponse(BaseModel):
    query: str
    total: int
    results: list[SearchResultItem]
