import asyncio
import io
import sys
import logging

logging.basicConfig(level=logging.INFO)

from app.services import gemini_service

async def test():
    dummy_image = b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\x0d\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82'
    filename = "test.png"
    try:
        res = await gemini_service.process_document(dummy_image, filename)
        print("RESULT:")
        print(res)
    except Exception as e:
        print(f"FAILED: {e}")

if __name__ == "__main__":
    asyncio.run(test())
