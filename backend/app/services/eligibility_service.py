"""
app/services/eligibility_service.py
=====================================
Government scheme eligibility engine — DigiSafe AI's most unique feature.
Checks 15 hardcoded central/state schemes against extracted document data.
All functions synchronous.
"""

from __future__ import annotations

import logging
import re
from datetime import date, datetime
from typing import Any, Optional

from app.core.database import get_supabase_sync

logger = logging.getLogger(__name__)

# ─────────────────────────────── Scheme catalogue ─────────────────────────────

HARDCODED_SCHEMES: list[dict] = [
    {
        "name": "PM Awas Yojana",
        "description": "Subsidised housing loan interest for urban/rural poor",
        "benefit": "Up to ₹2.67 lakh interest subsidy on home loan",
        "level": "central",
        "state": "All India",
        "apply_url": "https://pmaymis.gov.in",
        "criteria": {"max_income": 600000, "required_docs": ["aadhaar card", "income certificate"]},
    },
    {
        "name": "PM Jan Dhan Yojana",
        "description": "Zero-balance bank account with RuPay debit card",
        "benefit": "Free bank account, ₹2L accident insurance, ₹30K life cover",
        "level": "central",
        "state": "All India",
        "apply_url": "https://pmjdy.gov.in",
        "criteria": {"required_docs": ["aadhaar card"]},
    },
    {
        "name": "Ayushman Bharat PM-JAY",
        "description": "Health insurance cover for low-income families",
        "benefit": "₹5 lakh annual health insurance per family",
        "level": "central",
        "state": "All India",
        "apply_url": "https://pmjay.gov.in",
        "criteria": {"max_income": 500000, "required_docs": ["aadhaar card", "income certificate"]},
    },
    {
        "name": "PM Kisan Samman Nidhi",
        "description": "Direct income support for small and marginal farmers",
        "benefit": "₹6,000/year in 3 equal instalments",
        "level": "central",
        "state": "All India",
        "apply_url": "https://pmkisan.gov.in",
        "criteria": {"required_docs": ["aadhaar card", "land document"]},
    },
    {
        "name": "Sukanya Samriddhi Yojana",
        "description": "High-interest savings scheme for girl child education/marriage",
        "benefit": "8.2% interest p.a., tax-exempt under 80C",
        "level": "central",
        "state": "All India",
        "apply_url": "https://www.nsiindia.gov.in",
        "criteria": {"required_docs": ["birth certificate", "aadhaar card"]},
    },
    {
        "name": "National Scholarship Portal",
        "description": "Central government scholarships for meritorious students",
        "benefit": "₹10,000–₹20,000/year scholarship",
        "level": "central",
        "state": "All India",
        "apply_url": "https://scholarships.gov.in",
        "criteria": {
            "max_income": 250000,
            "required_docs": ["marksheet", "income certificate", "aadhaar card"],
        },
    },
    {
        "name": "Post Matric Scholarship SC/ST",
        "description": "Scholarship for SC/ST students pursuing post-matriculation education",
        "benefit": "Full tuition fee + maintenance allowance",
        "level": "central",
        "state": "All India",
        "apply_url": "https://scholarships.gov.in",
        "criteria": {
            "caste": ["sc", "st"],
            "required_docs": ["caste certificate", "marksheet"],
        },
    },
    {
        "name": "OBC Pre-Matric Scholarship",
        "description": "Scholarship for OBC students in class 1–10",
        "benefit": "₹1,000–₹4,400/year",
        "level": "central",
        "state": "All India",
        "apply_url": "https://scholarships.gov.in",
        "criteria": {
            "caste": ["obc"],
            "max_income": 100000,
            "required_docs": ["caste certificate", "marksheet"],
        },
    },
    {
        "name": "MUDRA Loan – Shishu",
        "description": "Collateral-free micro business loan up to ₹50,000",
        "benefit": "Business loan up to ₹50,000 at low interest",
        "level": "central",
        "state": "All India",
        "apply_url": "https://mudra.org.in",
        "criteria": {"required_docs": ["aadhaar card", "pan card"]},
    },
    {
        "name": "Stand Up India",
        "description": "SC/ST and women entrepreneurs bank loans",
        "benefit": "₹10 lakh to ₹1 crore loan for greenfield enterprise",
        "level": "central",
        "state": "All India",
        "apply_url": "https://www.standupmitra.in",
        "criteria": {
            "caste": ["sc", "st"],
            "required_docs": ["aadhaar card", "pan card"],
        },
    },
    {
        "name": "PM Suraksha Bima Yojana",
        "description": "Accident insurance scheme linked to bank account",
        "benefit": "₹2 lakh accident cover at just ₹12/year",
        "level": "central",
        "state": "All India",
        "apply_url": "https://jansuraksha.gov.in",
        "criteria": {"required_docs": ["aadhaar card", "bank statement"]},
    },
    {
        "name": "PM Jeevan Jyoti Bima Yojana",
        "description": "Term life insurance for bank account holders aged 18–50",
        "benefit": "₹2 lakh life cover at ₹436/year",
        "level": "central",
        "state": "All India",
        "apply_url": "https://jansuraksha.gov.in",
        "criteria": {"max_age": 50, "required_docs": ["aadhaar card", "bank statement"]},
    },
    {
        "name": "Atal Pension Yojana",
        "description": "Government-backed pension scheme for unorganised sector workers",
        "benefit": "₹1,000–₹5,000 guaranteed pension after retirement",
        "level": "central",
        "state": "All India",
        "apply_url": "https://npscra.nsdl.co.in",
        "criteria": {"max_age": 40, "required_docs": ["aadhaar card", "bank statement"]},
    },
    {
        "name": "Maharashtra Swadhar Scholarship",
        "description": "Scholarship + maintenance for SC/SBC students in Maharashtra",
        "benefit": "₹51,000–₹65,000/year for accommodation, food, and education",
        "level": "state",
        "state": "Maharashtra",
        "apply_url": "https://mahadbt.maharashtra.gov.in",
        "criteria": {
            "state": "maharashtra",
            "caste": ["sc", "sbc"],
            "required_docs": ["caste certificate", "marksheet", "income certificate"],
        },
    },
    {
        "name": "RTE Free Education",
        "description": "Right to Education — free schooling for children 6–14 years",
        "benefit": "Free and compulsory education up to class 8",
        "level": "central",
        "state": "All India",
        "apply_url": "https://rte.gov.in",
        "criteria": {
            "max_age": 14,
            "max_income": 100000,
            "required_docs": ["birth certificate", "income certificate"],
        },
    },
]


# ─────────────────────────────── Helpers ─────────────────────────────────────

def _normalise(s: Any) -> str:
    return str(s).lower().strip() if s else ""


def extract_income_from_fields(fields: list[dict]) -> Optional[int]:
    """Try to parse annual income from document field values."""
    income_keywords = ["annual income", "income", "yearly income", "annual earning"]
    for field in fields:
        if any(kw in _normalise(field.get("label", "")) for kw in income_keywords):
            raw = re.sub(r"[^\d]", "", str(field.get("value", "")))
            if raw:
                try:
                    return int(raw)
                except ValueError:
                    pass
    return None


def extract_caste_from_fields(fields: list[dict]) -> Optional[str]:
    """Try to extract caste category from document field values."""
    caste_keywords = ["caste", "category", "community", "tribe"]
    for field in fields:
        label = _normalise(field.get("label", ""))
        if any(kw in label for kw in caste_keywords):
            value = _normalise(field.get("value", ""))
            for cat in ["sc", "st", "obc", "sbc", "ews", "general"]:
                if cat in value:
                    return cat
    return None


def extract_dob_for_age(fields: list[dict]) -> Optional[int]:
    """Return age in years calculated from DOB field, or None."""
    dob_keywords = ["dob", "date of birth", "birth date", "born"]
    for field in fields:
        if any(kw in _normalise(field.get("label", "")) for kw in dob_keywords):
            raw = str(field.get("value", ""))
            # Try common date formats
            for fmt in ("%Y-%m-%d", "%d/%m/%Y", "%d-%m-%Y", "%d %b %Y", "%B %d, %Y"):
                try:
                    dob = datetime.strptime(raw.strip(), fmt).date()
                    today = date.today()
                    age = today.year - dob.year - (
                        (today.month, today.day) < (dob.month, dob.day)
                    )
                    return age
                except ValueError:
                    continue
    return None


def _extract_user_state(fields: list[dict]) -> Optional[str]:
    """Try to extract state name from any address-like field."""
    address_keywords = ["address", "permanent address", "state"]
    indian_states = [
        "maharashtra", "gujarat", "rajasthan", "karnataka", "tamil nadu",
        "uttar pradesh", "madhya pradesh", "bihar", "west bengal", "andhra pradesh",
        "kerala", "haryana", "punjab", "jharkhand", "assam", "odisha",
    ]
    for field in fields:
        if any(kw in _normalise(field.get("label", "")) for kw in address_keywords):
            value = _normalise(field.get("value", ""))
            for state in indian_states:
                if state in value:
                    return state
    return None


def _has_doc_type(doc_types_present: list[str], required: str) -> bool:
    req = _normalise(required)
    return any(req in _normalise(dt) or _normalise(dt) in req for dt in doc_types_present)


# ─────────────────────────────── Main function ────────────────────────────────

def check_eligibility(user_id: str) -> list[dict]:
    """
    Evaluate all 15 hardcoded schemes against a user's uploaded documents.
    Returns a list of eligible scheme dicts enriched with *why_eligible*.
    """
    supabase = get_supabase_sync()

    # Fetch all documents
    try:
        docs_result = (
            supabase.table("documents")
            .select("id", "subcategory", "category", "filename")
            .eq("user_id", user_id)
            .execute()
        )
        docs = docs_result.data or []
    except Exception as exc:
        logger.error("check_eligibility: cannot fetch documents: %s", exc)
        return []

    doc_ids = [d["id"] for d in docs]

    # Fetch all fields
    all_fields: list[dict] = []
    if doc_ids:
        try:
            fields_result = (
                supabase.table("document_fields")
                .select("document_id", "label", "value")
                .in_("document_id", doc_ids)
                .execute()
            )
            all_fields = fields_result.data or []
        except Exception as exc:
            logger.error("check_eligibility: cannot fetch fields: %s", exc)

    # Build user profile
    doc_types_present = [
        _normalise(d.get("subcategory") or d.get("category") or "")
        for d in docs
    ]

    annual_income = extract_income_from_fields(all_fields)
    caste = extract_caste_from_fields(all_fields)
    age = extract_dob_for_age(all_fields)
    user_state = _extract_user_state(all_fields)

    eligible: list[dict] = []

    for scheme in HARDCODED_SCHEMES:
        criteria = scheme.get("criteria", {})
        reasons: list[str] = []
        fail = False

        # Income check
        if "max_income" in criteria:
            if annual_income is not None:
                if annual_income <= criteria["max_income"]:
                    reasons.append(f"Income ₹{annual_income:,} ≤ ₹{criteria['max_income']:,}")
                else:
                    fail = True
            # If income unknown — still show (give benefit of doubt)

        # Age check
        if "max_age" in criteria:
            if age is not None:
                if age <= criteria["max_age"]:
                    reasons.append(f"Age {age} ≤ {criteria['max_age']} years")
                else:
                    fail = True

        # Caste check
        if "caste" in criteria:
            allowed = [c.lower() for c in criteria["caste"]]
            if caste and caste in allowed:
                reasons.append(f"Caste category: {caste.upper()}")
            else:
                fail = True

        # State check
        if "state" in criteria:
            if user_state and criteria["state"] in user_state:
                reasons.append(f"Resident of {user_state.title()}")
            elif user_state is None:
                pass  # unknown state — still include
            else:
                fail = True

        # Required documents check
        required_docs = criteria.get("required_docs", [])
        missing_docs = [d for d in required_docs if not _has_doc_type(doc_types_present, d)]
        if missing_docs:
            reasons.append(f"You have most required documents (missing: {', '.join(missing_docs)})")
        else:
            reasons.append("You have all required documents")

        if fail:
            continue

        eligible.append(
            {
                "scheme_name": scheme["name"],
                "description": scheme["description"],
                "benefit": scheme["benefit"],
                "level": scheme["level"],
                "state": scheme["state"],
                "why_eligible": "; ".join(reasons) if reasons else "Likely eligible based on your documents",
                "apply_url": scheme.get("apply_url"),
            }
        )

    return eligible
