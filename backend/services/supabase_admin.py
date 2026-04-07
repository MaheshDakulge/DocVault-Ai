from supabase import create_client
from core.config import settings
from schemas.responses import SyncResponse

supabase = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_KEY)


class SupabaseAdminService:
    """Handles all Supabase admin operations using the service role key."""

    async def sync_batch(self, user_id: str, operations: list[dict]) -> SyncResponse:
        """
        Push a batch of SQLite change-log items to Supabase.
        Device-wins conflict resolution: all payloads override cloud data.
        """
        synced = 0
        failed = []

        for op in operations:
            table = op.get("table")
            record_id = op.get("record_id")
            operation = op.get("operation")  # INSERT | UPDATE | DELETE
            payload = op.get("payload", {})

            try:
                payload["user_id"] = user_id  # Enforce RLS ownership

                if operation in ("INSERT", "UPDATE"):
                    supabase.table(table).upsert(payload).execute()
                elif operation == "DELETE":
                    supabase.table(table).delete().eq("id", record_id).execute()

                synced += 1
            except Exception:
                failed.append(record_id or "unknown")

        return SyncResponse(synced_count=synced, failed_ids=failed)
