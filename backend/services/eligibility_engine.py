import json
import google.generativeai as genai
from core.config import settings
from schemas.responses import EligibilityResponse, SchemeMatch

genai.configure(api_key=settings.GEMINI_API_KEY)

_ELIGIBILITY_PROMPT = """
You are a government scheme eligibility checker for India.

The user has the following documents with extracted fields:
{context}

Match these against the following 15 government schemes and return ONLY a JSON array:
[
  {{
    "scheme_name": "<scheme name>",
    "level": "<Central|State>",
    "benefit": "<what the user gets>",
    "apply_url": "<official URL>",
    "match_reason": "<why this user qualifies based on their documents>",
    "eligibility_score": <0.0-1.0>
  }}
]

Schemes to check:
1. PM Jan Dhan Yojana (Central) - Bank account for unbanked
2. PM Awas Yojana (Central) - Housing subsidy
3. Ayushman Bharat PM-JAY (Central) - Health insurance ₹5L/year
4. PM Kisan Samman Nidhi (Central) - Farmer income support ₹6000/year
5. PM Ujjwala Yojana (Central) - Free LPG connection
6. Sukanya Samriddhi Yojana (Central) - Girl child savings
7. PM Scholarship Scheme (Central) - Education scholarship
8. National Scholarship Portal (Central) - Education aid
9. PM MUDRA Yojana (Central) - Small business loan
10. Atal Pension Yojana (Central) - Pension for unorganized workers
11. PM Suraksha Bima Yojana (Central) - Accident insurance ₹2L
12. PM Jeevan Jyoti Bima (Central) - Life insurance ₹2L
13. MNREGA (Central) - Employment guarantee
14. Mahatma Gandhi Scholarship (State) - Merit-based scholarship
15. Pradhan Mantri Garib Kalyan Yojana (Central) - Food security

Only include schemes with eligibility_score > 0.3. Return [] if none qualify.
Return ONLY valid JSON, no explanation.
"""


class EligibilityEngine:
    def __init__(self):
        self.model = genai.GenerativeModel(
            model_name="gemini-1.5-flash",
            generation_config=genai.GenerationConfig(
                temperature=0.2,
                response_mime_type="application/json",
            ),
        )

    async def match(self, context_fields: list[dict]) -> EligibilityResponse:
        """
        Matches user's extracted document fields against 15 government schemes.
        Gemini reads all uploaded documents together — nobody in India has built
        this in a consumer app.
        """
        context = "\n".join([f"{f.get('label', '')}: {f.get('value', '')}" for f in context_fields])
        prompt = _ELIGIBILITY_PROMPT.format(context=context)

        response = self.model.generate_content(prompt)

        try:
            schemes_data = json.loads(response.text)
            schemes = [SchemeMatch(**s) for s in schemes_data]
        except Exception:
            schemes = []

        # Build a human-readable summary
        if schemes:
            top = schemes[0]
            summary = (
                f"You may be eligible for {len(schemes)} government scheme(s). "
                f"Top match: {top.scheme_name} — {top.benefit}."
            )
        else:
            summary = "No matching government schemes found based on your current documents."

        return EligibilityResponse(matched_schemes=schemes, summary=summary)
