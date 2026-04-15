from fastapi import APIRouter
from fastapi.responses import JSONResponse

router = APIRouter()


@router.get("/health", tags=["system"])
async def health_check():
    return JSONResponse({"status": "ok", "service": "PropWriter AI"})
