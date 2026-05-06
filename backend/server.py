from dotenv import load_dotenv
from pathlib import Path

ROOT_DIR = Path(__file__).parent
load_dotenv(ROOT_DIR / ".env")

import os
import uuid
import logging
import io
from datetime import datetime, timezone, timedelta
from typing import Optional, List, Literal

import bcrypt
import httpx
import jwt
from fastapi import FastAPI, APIRouter, Depends, HTTPException, Request, Response
from fastapi.responses import StreamingResponse
from starlette.middleware.cors import CORSMiddleware
from motor.motor_asyncio import AsyncIOMotorClient
from pydantic import BaseModel, Field, EmailStr

from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib import colors
from reportlab.pdfgen import canvas as pdf_canvas

# ---------- Logging ----------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger("goldenauto")


def env_bool(name: str, default: bool = False) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}

# ---------- MongoDB ----------
MONGO_URL = os.environ["MONGO_URL"]
DB_NAME = os.environ["DB_NAME"]
client = AsyncIOMotorClient(MONGO_URL)
db = client[DB_NAME]

# ---------- Supabase read-only (customers, phase 1A) ----------
SUPABASE_READONLY_CUSTOMERS_ENABLED = env_bool("SUPABASE_READONLY_CUSTOMERS_ENABLED", False)
SUPABASE_AUTH_CHECK_ENABLED = env_bool("SUPABASE_AUTH_CHECK_ENABLED", False)
SUPABASE_URL = os.environ.get("SUPABASE_URL", "").strip()
SUPABASE_ANON_KEY = os.environ.get("SUPABASE_ANON_KEY", "").strip()
SUPABASE_CUSTOMERS_TIMEOUT_SEC = float(os.environ.get("SUPABASE_CUSTOMERS_TIMEOUT_SEC", "5"))

SUPABASE_CUSTOMERS_SELECT = ",".join([
    "id",
    "customer_number",
    "full_name",
    "email",
    "phone",
    "is_active",
    "created_at",
    "updated_at",
])


def extract_bearer_token(authorization_header: Optional[str]) -> Optional[str]:
    if not authorization_header:
        return None
    auth_value = authorization_header.strip()
    if not auth_value.startswith("Bearer "):
        return None
    token = auth_value[7:].strip()
    if not token or " " in token:
        return None
    return token


async def fetch_customers_from_supabase(q: Optional[str], authorization_header: Optional[str]) -> Optional[List[dict]]:
    if not SUPABASE_READONLY_CUSTOMERS_ENABLED:
        return None

    if not SUPABASE_URL or not SUPABASE_ANON_KEY:
        logger.warning("Supabase customers read-only enabled but config missing; falling back to MongoDB")
        return None

    user_access_token = extract_bearer_token(authorization_header)
    if not user_access_token:
        logger.info("Supabase customers read-only missing bearer user token; falling back to MongoDB")
        return None

    url = f"{SUPABASE_URL.rstrip('/')}/rest/v1/customers"
    params = {
        "select": SUPABASE_CUSTOMERS_SELECT,
        "order": "full_name.asc",
        "limit": "500",
    }

    if q:
        safe_q = q.replace("*", "").replace(",", "").strip()
        if safe_q:
            params["or"] = f"(full_name.ilike.*{safe_q}*,phone.ilike.*{safe_q}*,email.ilike.*{safe_q}*)"

    headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Authorization": f"Bearer {user_access_token}",
        "Accept": "application/json",
    }

    try:
        async with httpx.AsyncClient(timeout=SUPABASE_CUSTOMERS_TIMEOUT_SEC) as client_http:
            resp = await client_http.get(url, params=params, headers=headers)
    except Exception:
        logger.exception("Supabase customers read failed; falling back to MongoDB")
        return None

    if resp.status_code != 200:
        if resp.status_code in (401, 403):
            logger.warning("Supabase customers read unauthorized/forbidden; falling back to MongoDB")
        else:
            logger.warning("Supabase customers read returned non-200 (%s); falling back to MongoDB", resp.status_code)
        return None

    try:
        rows = resp.json()
    except Exception:
        logger.exception("Supabase customers read returned invalid JSON; falling back to MongoDB")
        return None

    if not isinstance(rows, list):
        logger.warning("Supabase customers read returned unexpected payload; falling back to MongoDB")
        return None

    mapped = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        mapped.append({
            "id": row.get("id"),
            "name": row.get("full_name"),
            "phone": row.get("phone"),
            "email": row.get("email"),
            "customer_number": row.get("customer_number"),
            "is_active": row.get("is_active", True),
            "created_at": row.get("created_at"),
            "updated_at": row.get("updated_at"),
            "notes": None,
        })

    logger.info("Customers served from Supabase read-only path: %s", len(mapped))
    return mapped


async def verify_supabase_user_token(user_access_token: str) -> Optional[str]:
    if not SUPABASE_URL or not SUPABASE_ANON_KEY:
        return None

    headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Authorization": f"Bearer {user_access_token}",
        "Accept": "application/json",
    }
    url = f"{SUPABASE_URL.rstrip('/')}/auth/v1/user"

    try:
        async with httpx.AsyncClient(timeout=SUPABASE_CUSTOMERS_TIMEOUT_SEC) as client_http:
            resp = await client_http.get(url, headers=headers)
    except Exception:
        logger.exception("Supabase auth smoke check request failed")
        return None

    if resp.status_code != 200:
        return None

    try:
        payload = resp.json()
    except Exception:
        logger.exception("Supabase auth smoke check returned invalid JSON")
        return None

    if not isinstance(payload, dict):
        return None

    user_id = payload.get("id")
    if not isinstance(user_id, str) or not user_id.strip():
        return None
    return user_id

# ---------- JWT / Auth helpers ----------
JWT_ALGO = "HS256"


def get_jwt_secret() -> str:
    return os.environ["JWT_SECRET"]


def hash_password(pw: str) -> str:
    return bcrypt.hashpw(pw.encode(), bcrypt.gensalt()).decode()


def verify_password(pw: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(pw.encode(), hashed.encode())
    except Exception:
        return False


def create_access_token(user_id: str, email: str, role: str) -> str:
    payload = {
        "sub": user_id,
        "email": email,
        "role": role,
        "exp": datetime.now(timezone.utc) + timedelta(hours=12),
        "type": "access",
    }
    return jwt.encode(payload, get_jwt_secret(), algorithm=JWT_ALGO)


async def get_current_user(request: Request) -> dict:
    token = request.cookies.get("access_token")
    if not token:
        auth = request.headers.get("Authorization", "")
        if auth.startswith("Bearer "):
            token = auth[7:]
    if not token:
        raise HTTPException(status_code=401, detail="Ej autentiserad")
    try:
        payload = jwt.decode(token, get_jwt_secret(), algorithms=[JWT_ALGO])
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token har gått ut")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Ogiltig token")
    user = await db.users.find_one({"id": payload["sub"]}, {"_id": 0, "password_hash": 0})
    if not user:
        raise HTTPException(status_code=401, detail="Användare finns ej")
    return user


def require_roles(*roles: str):
    async def checker(user: dict = Depends(get_current_user)) -> dict:
        if user.get("role") not in roles and user.get("role") != "superadmin":
            raise HTTPException(status_code=403, detail="Saknar behörighet")
        return user
    return checker


# ---------- Audit logger ----------
async def log_audit(
    entity: str,
    entity_id: str,
    action: str,
    user: Optional[dict],
    old_value: Optional[dict] = None,
    new_value: Optional[dict] = None,
    ip: Optional[str] = None,
):
    doc = {
        "id": str(uuid.uuid4()),
        "entity": entity,
        "entity_id": entity_id,
        "action": action,
        "old_value": old_value,
        "new_value": new_value,
        "user_id": user.get("id") if user else None,
        "user_name": user.get("name") if user else "public",
        "user_email": user.get("email") if user else None,
        "ip": ip,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    await db.audit_logs.insert_one(doc)


# ---------- Mock notification sender ----------
async def send_notification(booking_id: str, channel: str, to: str, subject: str, body: str, template: str):
    doc = {
        "id": str(uuid.uuid4()),
        "booking_id": booking_id,
        "channel": channel,
        "template": template,
        "to": to,
        "subject": subject,
        "body": body,
        "status": "sent",  # MOCKED
        "sent_at": datetime.now(timezone.utc).isoformat(),
    }
    await db.notifications.insert_one(doc)
    logger.info(f"[MOCK {channel.upper()}] to={to} template={template}")
    return doc


# ---------- Pydantic Models ----------
class LoginIn(BaseModel):
    email: EmailStr
    password: str


class UserOut(BaseModel):
    id: str
    email: str
    name: str
    role: str
    active: bool = True


class UserCreate(BaseModel):
    email: EmailStr
    password: str
    name: str
    role: Literal["superadmin", "admin", "mechanic", "detailing"]


class CustomerIn(BaseModel):
    name: str
    phone: str
    email: Optional[EmailStr] = None
    notes: Optional[str] = None


class VehicleIn(BaseModel):
    customer_id: str
    regnr: str
    brand: Optional[str] = None
    model: Optional[str] = None
    year: Optional[int] = None
    tire_info: Optional[str] = None
    notes: Optional[str] = None


class ServiceIn(BaseModel):
    category: Literal["verkstad", "service", "hjulskifte", "dackhotell", "biltvatt", "rekond"]
    name: str
    description: Optional[str] = None
    price_from: float = 0
    duration_min: int = 30
    active: bool = True


class StandardActionIn(BaseModel):
    category: str
    name: str
    description: Optional[str] = None
    default_price: float = 0
    default_vat: float = 25.0
    active: bool = True


class PublicBookingIn(BaseModel):
    service_id: str
    date: str  # YYYY-MM-DD
    time: str  # HH:MM
    customer_name: str
    phone: str
    email: EmailStr
    regnr: str
    brand: Optional[str] = None
    model: Optional[str] = None
    message: Optional[str] = None


class BookingStatusIn(BaseModel):
    status: Literal["new", "confirmed", "checked_in", "in_progress", "awaiting", "done", "delivered", "cancelled"]
    note: Optional[str] = None


class WorkOrderItemIn(BaseModel):
    action_id: Optional[str] = None
    description: str
    qty: float = 1
    unit_price: float = 0
    vat: float = 25.0


class WorkOrderIn(BaseModel):
    booking_id: Optional[str] = None
    customer_id: str
    vehicle_id: str
    assigned_to: Optional[str] = None
    planned_at: Optional[str] = None
    items: List[WorkOrderItemIn] = []
    notes: Optional[str] = None
    status: Literal["draft", "in_progress", "done", "invoiced"] = "draft"


class ReceiptIn(BaseModel):
    work_order_id: str
    paid_status: Literal["unpaid", "paid"] = "unpaid"
    comment: Optional[str] = None


class TireHotelIn(BaseModel):
    customer_id: str
    vehicle_id: str
    location: str
    tires_info: str
    season: Literal["summer", "winter"]
    status: Literal["stored", "withdrawn"] = "stored"


# ---------- App ----------
app = FastAPI(title="Golden Auto Platform")
api = APIRouter(prefix="/api")


# ===== AUTH =====
@api.post("/auth/login")
async def auth_login(payload: LoginIn, response: Response, request: Request):
    email = payload.email.lower().strip()
    user = await db.users.find_one({"email": email}, {"_id": 0})
    if not user or not user.get("active", True) or not verify_password(payload.password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Fel e-post eller lösenord")
    token = create_access_token(user["id"], user["email"], user["role"])
    response.set_cookie(
        "access_token", token, httponly=True, secure=True, samesite="none",
        max_age=60 * 60 * 12, path="/",
    )
    await log_audit("user", user["id"], "login", user, ip=request.client.host if request.client else None)
    user_out = {k: v for k, v in user.items() if k != "password_hash"}
    return {"user": user_out, "token": token}


@api.post("/auth/logout")
async def auth_logout(response: Response):
    response.delete_cookie("access_token", path="/")
    return {"ok": True}


@api.get("/auth/me")
async def auth_me(user: dict = Depends(get_current_user)):
    return user


# ===== USERS (superadmin only) =====
@api.get("/users")
async def users_list(user: dict = Depends(require_roles("superadmin"))):
    users = await db.users.find({}, {"_id": 0, "password_hash": 0}).to_list(500)
    return users


@api.post("/users")
async def users_create(payload: UserCreate, user: dict = Depends(require_roles("superadmin"))):
    email = payload.email.lower().strip()
    exists = await db.users.find_one({"email": email})
    if exists:
        raise HTTPException(status_code=400, detail="E-post används redan")
    new = {
        "id": str(uuid.uuid4()),
        "email": email,
        "password_hash": hash_password(payload.password),
        "name": payload.name,
        "role": payload.role,
        "active": True,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    await db.users.insert_one(new)
    await log_audit("user", new["id"], "create", user, new_value={"email": email, "role": payload.role})
    return {k: v for k, v in new.items() if k != "password_hash"}


@api.delete("/users/{uid}")
async def users_delete(uid: str, user: dict = Depends(require_roles("superadmin"))):
    if uid == user["id"]:
        raise HTTPException(400, "Kan inte radera dig själv")
    await db.users.delete_one({"id": uid})
    await log_audit("user", uid, "delete", user)
    return {"ok": True}


# ===== CUSTOMERS =====
@api.get("/customers")
async def customers_list(q: Optional[str] = None, request: Request = None, user: dict = Depends(get_current_user)):
    supabase_rows = await fetch_customers_from_supabase(q, request.headers.get("Authorization") if request else None)
    if supabase_rows is not None:
        return supabase_rows

    filt = {}
    if q:
        filt = {"$or": [
            {"name": {"$regex": q, "$options": "i"}},
            {"phone": {"$regex": q, "$options": "i"}},
            {"email": {"$regex": q, "$options": "i"}},
        ]}
    return await db.customers.find(filt, {"_id": 0}).sort("name", 1).to_list(500)


@api.get("/dev/supabase-auth-check")
async def supabase_auth_check(request: Request):
    if not SUPABASE_AUTH_CHECK_ENABLED:
        raise HTTPException(status_code=404, detail="Not found")

    if not SUPABASE_URL or not SUPABASE_ANON_KEY:
        raise HTTPException(status_code=503, detail="Supabase auth check ej konfigurerad")

    auth_header = request.headers.get("Authorization")
    if not auth_header:
        raise HTTPException(status_code=401, detail="Ej autentiserad")

    user_access_token = extract_bearer_token(auth_header)
    if not user_access_token:
        raise HTTPException(status_code=400, detail="Ogiltigt Authorization-format")

    user_id = await verify_supabase_user_token(user_access_token)
    if not user_id:
        raise HTTPException(status_code=401, detail="Ogiltig Supabase access token")

    return {
        "authenticated": True,
        "user_id": user_id,
        "customers_read_token_usable": True,
    }


@api.post("/customers")
async def customers_create(payload: CustomerIn, user: dict = Depends(get_current_user)):
    doc = payload.model_dump()
    doc["id"] = str(uuid.uuid4())
    doc["created_at"] = datetime.now(timezone.utc).isoformat()
    await db.customers.insert_one(doc)
    doc.pop("_id", None)
    await log_audit("customer", doc["id"], "create", user, new_value=payload.model_dump())
    return doc


@api.get("/customers/{cid}")
async def customers_get(cid: str, user: dict = Depends(get_current_user)):
    c = await db.customers.find_one({"id": cid}, {"_id": 0})
    if not c:
        raise HTTPException(404, "Kund finns ej")
    c["vehicles"] = await db.vehicles.find({"customer_id": cid}, {"_id": 0}).to_list(100)
    c["bookings"] = await db.bookings.find({"customer_id": cid}, {"_id": 0}).sort("created_at", -1).to_list(100)
    c["work_orders"] = await db.work_orders.find({"customer_id": cid}, {"_id": 0}).sort("created_at", -1).to_list(100)
    return c


@api.put("/customers/{cid}")
async def customers_update(cid: str, payload: CustomerIn, user: dict = Depends(get_current_user)):
    old = await db.customers.find_one({"id": cid}, {"_id": 0})
    if not old:
        raise HTTPException(404, "Kund finns ej")
    await db.customers.update_one({"id": cid}, {"$set": payload.model_dump()})
    await log_audit("customer", cid, "update", user, old_value=old, new_value=payload.model_dump())
    return await db.customers.find_one({"id": cid}, {"_id": 0})


@api.delete("/customers/{cid}")
async def customers_delete(cid: str, user: dict = Depends(require_roles("admin"))):
    await db.customers.delete_one({"id": cid})
    await log_audit("customer", cid, "delete", user)
    return {"ok": True}


# ===== VEHICLES =====
@api.get("/vehicles")
async def vehicles_list(q: Optional[str] = None, customer_id: Optional[str] = None, user: dict = Depends(get_current_user)):
    filt = {}
    if customer_id:
        filt["customer_id"] = customer_id
    if q:
        filt["$or"] = [
            {"regnr": {"$regex": q, "$options": "i"}},
            {"brand": {"$regex": q, "$options": "i"}},
            {"model": {"$regex": q, "$options": "i"}},
        ]
    vehicles = await db.vehicles.find(filt, {"_id": 0}).to_list(500)
    # attach customer name
    for v in vehicles:
        c = await db.customers.find_one({"id": v.get("customer_id")}, {"_id": 0, "name": 1})
        v["customer_name"] = c["name"] if c else None
    return vehicles


@api.post("/vehicles")
async def vehicles_create(payload: VehicleIn, user: dict = Depends(get_current_user)):
    doc = payload.model_dump()
    doc["id"] = str(uuid.uuid4())
    doc["regnr"] = doc["regnr"].upper().replace(" ", "")
    doc["created_at"] = datetime.now(timezone.utc).isoformat()
    await db.vehicles.insert_one(doc)
    doc.pop("_id", None)
    await log_audit("vehicle", doc["id"], "create", user, new_value=doc)
    return doc


@api.put("/vehicles/{vid}")
async def vehicles_update(vid: str, payload: VehicleIn, user: dict = Depends(get_current_user)):
    old = await db.vehicles.find_one({"id": vid}, {"_id": 0})
    if not old:
        raise HTTPException(404, "Fordon finns ej")
    data = payload.model_dump()
    data["regnr"] = data["regnr"].upper().replace(" ", "")
    await db.vehicles.update_one({"id": vid}, {"$set": data})
    await log_audit("vehicle", vid, "update", user, old_value=old, new_value=data)
    return await db.vehicles.find_one({"id": vid}, {"_id": 0})


@api.delete("/vehicles/{vid}")
async def vehicles_delete(vid: str, user: dict = Depends(require_roles("admin"))):
    await db.vehicles.delete_one({"id": vid})
    await log_audit("vehicle", vid, "delete", user)
    return {"ok": True}


# ===== SERVICES =====
@api.get("/services")
async def services_list():
    return await db.services.find({"active": True}, {"_id": 0}).sort("category", 1).to_list(200)


@api.get("/services/all")
async def services_all(user: dict = Depends(get_current_user)):
    return await db.services.find({}, {"_id": 0}).sort("category", 1).to_list(200)


@api.post("/services")
async def services_create(payload: ServiceIn, user: dict = Depends(require_roles("admin"))):
    doc = payload.model_dump()
    doc["id"] = str(uuid.uuid4())
    await db.services.insert_one(doc)
    doc.pop("_id", None)
    await log_audit("service", doc["id"], "create", user, new_value=doc)
    return doc


@api.put("/services/{sid}")
async def services_update(sid: str, payload: ServiceIn, user: dict = Depends(require_roles("admin"))):
    old = await db.services.find_one({"id": sid}, {"_id": 0})
    if not old:
        raise HTTPException(404, "Tjänst finns ej")
    await db.services.update_one({"id": sid}, {"$set": payload.model_dump()})
    await log_audit("service", sid, "update", user, old_value=old, new_value=payload.model_dump())
    return await db.services.find_one({"id": sid}, {"_id": 0})


@api.delete("/services/{sid}")
async def services_delete(sid: str, user: dict = Depends(require_roles("admin"))):
    await db.services.delete_one({"id": sid})
    await log_audit("service", sid, "delete", user)
    return {"ok": True}


# ===== STANDARD ACTIONS =====
@api.get("/standard-actions")
async def actions_list(category: Optional[str] = None, user: dict = Depends(get_current_user)):
    filt = {"active": True}
    if category:
        filt["category"] = category
    return await db.standard_actions.find(filt, {"_id": 0}).sort([("category", 1), ("name", 1)]).to_list(500)


@api.post("/standard-actions")
async def actions_create(payload: StandardActionIn, user: dict = Depends(require_roles("admin"))):
    doc = payload.model_dump()
    doc["id"] = str(uuid.uuid4())
    await db.standard_actions.insert_one(doc)
    doc.pop("_id", None)
    await log_audit("standard_action", doc["id"], "create", user, new_value=doc)
    return doc


@api.put("/standard-actions/{aid}")
async def actions_update(aid: str, payload: StandardActionIn, user: dict = Depends(require_roles("admin"))):
    old = await db.standard_actions.find_one({"id": aid}, {"_id": 0})
    if not old:
        raise HTTPException(404, "Åtgärd finns ej")
    await db.standard_actions.update_one({"id": aid}, {"$set": payload.model_dump()})
    await log_audit("standard_action", aid, "update", user, old_value=old, new_value=payload.model_dump())
    return await db.standard_actions.find_one({"id": aid}, {"_id": 0})


@api.delete("/standard-actions/{aid}")
async def actions_delete(aid: str, user: dict = Depends(require_roles("admin"))):
    await db.standard_actions.delete_one({"id": aid})
    await log_audit("standard_action", aid, "delete", user)
    return {"ok": True}


# ===== BOOKINGS =====
DEFAULT_SLOTS = [f"{h:02d}:{m:02d}" for h in range(8, 17) for m in (0, 30)]


@api.get("/public/availability")
async def public_availability(date: str, service_id: str):
    svc = await db.services.find_one({"id": service_id}, {"_id": 0})
    if not svc:
        raise HTTPException(404, "Tjänst finns ej")
    taken = await db.bookings.find(
        {"date": date, "service_id": service_id, "status": {"$nin": ["cancelled"]}}, {"_id": 0, "time": 1}
    ).to_list(200)
    taken_set = {t["time"] for t in taken}
    slots = [{"time": s, "available": s not in taken_set} for s in DEFAULT_SLOTS]
    return {"date": date, "service": svc, "slots": slots}


@api.post("/public/bookings")
async def public_create_booking(payload: PublicBookingIn, request: Request):
    svc = await db.services.find_one({"id": payload.service_id}, {"_id": 0})
    if not svc:
        raise HTTPException(404, "Tjänst finns ej")

    # find/create customer by phone+email
    email = payload.email.lower().strip()
    customer = await db.customers.find_one({"email": email}, {"_id": 0})
    if not customer:
        customer = {
            "id": str(uuid.uuid4()),
            "name": payload.customer_name,
            "phone": payload.phone,
            "email": email,
            "notes": None,
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
        await db.customers.insert_one(customer.copy())

    regnr = payload.regnr.upper().replace(" ", "")
    vehicle = await db.vehicles.find_one({"customer_id": customer["id"], "regnr": regnr}, {"_id": 0})
    if not vehicle:
        vehicle = {
            "id": str(uuid.uuid4()),
            "customer_id": customer["id"],
            "regnr": regnr,
            "brand": payload.brand,
            "model": payload.model,
            "year": None,
            "tire_info": None,
            "notes": None,
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
        await db.vehicles.insert_one(vehicle.copy())

    # prevent double booking
    conflict = await db.bookings.find_one(
        {"date": payload.date, "time": payload.time, "service_id": payload.service_id, "status": {"$nin": ["cancelled"]}}
    )
    if conflict:
        raise HTTPException(409, "Tiden är redan bokad")

    booking = {
        "id": str(uuid.uuid4()),
        "booking_number": f"GA-{datetime.now().strftime('%y%m%d')}-{str(uuid.uuid4())[:6].upper()}",
        "service_id": svc["id"],
        "service_name": svc["name"],
        "category": svc["category"],
        "duration_min": svc.get("duration_min", 30),
        "price_from": svc.get("price_from", 0),
        "date": payload.date,
        "time": payload.time,
        "customer_id": customer["id"],
        "customer_name": customer["name"],
        "customer_phone": customer["phone"],
        "customer_email": customer["email"],
        "vehicle_id": vehicle["id"],
        "regnr": regnr,
        "brand": payload.brand,
        "model": payload.model,
        "message": payload.message,
        "status": "new",
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    await db.bookings.insert_one(booking.copy())

    # status history
    await db.booking_status_history.insert_one({
        "id": str(uuid.uuid4()),
        "booking_id": booking["id"],
        "from_status": None,
        "to_status": "new",
        "user_name": "kund (webb)",
        "changed_at": datetime.now(timezone.utc).isoformat(),
        "note": "Bokning skapad via webbformulär",
    })

    # mock notifications
    await send_notification(
        booking["id"], "email", email,
        f"Bokningsbekräftelse {booking['booking_number']}",
        f"Hej {customer['name']}!\n\nDin bokning för {svc['name']} är mottagen.\nDatum: {payload.date} {payload.time}\nBil: {regnr}\n\nVi kontaktar dig vid frågor.\n\nGolden Auto",
        "booking_confirmation",
    )
    await send_notification(
        booking["id"], "sms", payload.phone,
        "", f"Golden Auto: Bokning {booking['booking_number']} mottagen {payload.date} kl {payload.time}. Vi ses!",
        "booking_confirmation_sms",
    )

    await log_audit("booking", booking["id"], "create", None, new_value=booking, ip=request.client.host if request.client else None)
    booking.pop("_id", None)
    return booking


@api.get("/bookings")
async def bookings_list(
    status: Optional[str] = None, date: Optional[str] = None, q: Optional[str] = None,
    user: dict = Depends(get_current_user),
):
    filt = {}
    if status:
        filt["status"] = status
    if date:
        filt["date"] = date
    if q:
        filt["$or"] = [
            {"customer_name": {"$regex": q, "$options": "i"}},
            {"regnr": {"$regex": q, "$options": "i"}},
            {"customer_phone": {"$regex": q, "$options": "i"}},
            {"booking_number": {"$regex": q, "$options": "i"}},
        ]
    return await db.bookings.find(filt, {"_id": 0}).sort([("date", -1), ("time", 1)]).to_list(500)


@api.get("/bookings/today")
async def bookings_today(user: dict = Depends(get_current_user)):
    today = datetime.now(timezone.utc).date().isoformat()
    return await db.bookings.find({"date": today}, {"_id": 0}).sort("time", 1).to_list(200)


@api.get("/bookings/{bid}")
async def bookings_get(bid: str, user: dict = Depends(get_current_user)):
    b = await db.bookings.find_one({"id": bid}, {"_id": 0})
    if not b:
        raise HTTPException(404, "Bokning finns ej")
    b["history"] = await db.booking_status_history.find({"booking_id": bid}, {"_id": 0}).sort("changed_at", 1).to_list(100)
    b["notifications"] = await db.notifications.find({"booking_id": bid}, {"_id": 0}).sort("sent_at", -1).to_list(50)
    return b


@api.patch("/bookings/{bid}/status")
async def bookings_status(bid: str, payload: BookingStatusIn, user: dict = Depends(get_current_user)):
    b = await db.bookings.find_one({"id": bid}, {"_id": 0})
    if not b:
        raise HTTPException(404, "Bokning finns ej")
    await db.bookings.update_one({"id": bid}, {"$set": {"status": payload.status}})
    await db.booking_status_history.insert_one({
        "id": str(uuid.uuid4()),
        "booking_id": bid,
        "from_status": b["status"],
        "to_status": payload.status,
        "user_id": user["id"],
        "user_name": user["name"],
        "changed_at": datetime.now(timezone.utc).isoformat(),
        "note": payload.note,
    })
    await log_audit("booking", bid, f"status:{b['status']}->{payload.status}", user,
                    old_value={"status": b["status"]}, new_value={"status": payload.status})
    # auto-notify on key transitions (mock)
    if payload.status == "confirmed":
        await send_notification(bid, "sms", b["customer_phone"], "",
                                f"Golden Auto: Din bokning {b['booking_number']} är bekräftad {b['date']} kl {b['time']}.",
                                "booking_confirmed_sms")
    if payload.status == "done":
        await send_notification(bid, "sms", b["customer_phone"], "",
                                f"Golden Auto: Din bil {b['regnr']} är klar för upphämtning.",
                                "ready_for_pickup_sms")
    return await db.bookings.find_one({"id": bid}, {"_id": 0})


# ===== WORK ORDERS =====
def calc_totals(items: List[dict]) -> dict:
    subtotal = sum(i["qty"] * i["unit_price"] for i in items)
    vat = sum(i["qty"] * i["unit_price"] * (i.get("vat", 25) / 100) for i in items)
    return {"subtotal": round(subtotal, 2), "vat": round(vat, 2), "total": round(subtotal + vat, 2)}


@api.get("/work-orders")
async def wo_list(status: Optional[str] = None, user: dict = Depends(get_current_user)):
    filt = {}
    if status:
        filt["status"] = status
    return await db.work_orders.find(filt, {"_id": 0}).sort("created_at", -1).to_list(500)


@api.post("/work-orders")
async def wo_create(payload: WorkOrderIn, user: dict = Depends(get_current_user)):
    customer = await db.customers.find_one({"id": payload.customer_id}, {"_id": 0})
    vehicle = await db.vehicles.find_one({"id": payload.vehicle_id}, {"_id": 0})
    if not customer or not vehicle:
        raise HTTPException(404, "Kund eller fordon saknas")
    items = [i.model_dump() for i in payload.items]
    for i in items:
        i["amount"] = round(i["qty"] * i["unit_price"], 2)
    totals = calc_totals(items)
    wo = {
        "id": str(uuid.uuid4()),
        "order_number": f"WO-{datetime.now().strftime('%y%m%d')}-{str(uuid.uuid4())[:6].upper()}",
        "booking_id": payload.booking_id,
        "customer_id": customer["id"],
        "customer_name": customer["name"],
        "vehicle_id": vehicle["id"],
        "regnr": vehicle["regnr"],
        "brand": vehicle.get("brand"),
        "model": vehicle.get("model"),
        "assigned_to": payload.assigned_to,
        "planned_at": payload.planned_at,
        "items": items,
        "notes": payload.notes,
        "status": payload.status,
        "subtotal": totals["subtotal"],
        "vat_total": totals["vat"],
        "total": totals["total"],
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    await db.work_orders.insert_one(wo.copy())
    await log_audit("work_order", wo["id"], "create", user, new_value=wo)
    wo.pop("_id", None)
    return wo


@api.get("/work-orders/{wid}")
async def wo_get(wid: str, user: dict = Depends(get_current_user)):
    wo = await db.work_orders.find_one({"id": wid}, {"_id": 0})
    if not wo:
        raise HTTPException(404, "Arbetsorder finns ej")
    return wo


@api.put("/work-orders/{wid}")
async def wo_update(wid: str, payload: WorkOrderIn, user: dict = Depends(get_current_user)):
    old = await db.work_orders.find_one({"id": wid}, {"_id": 0})
    if not old:
        raise HTTPException(404, "Arbetsorder finns ej")
    items = [i.model_dump() for i in payload.items]
    for i in items:
        i["amount"] = round(i["qty"] * i["unit_price"], 2)
    totals = calc_totals(items)
    update = {
        "assigned_to": payload.assigned_to,
        "planned_at": payload.planned_at,
        "items": items,
        "notes": payload.notes,
        "status": payload.status,
        "subtotal": totals["subtotal"],
        "vat_total": totals["vat"],
        "total": totals["total"],
    }
    await db.work_orders.update_one({"id": wid}, {"$set": update})
    await log_audit("work_order", wid, "update", user, old_value=old, new_value=update)
    return await db.work_orders.find_one({"id": wid}, {"_id": 0})


@api.delete("/work-orders/{wid}")
async def wo_delete(wid: str, user: dict = Depends(require_roles("admin"))):
    await db.work_orders.delete_one({"id": wid})
    await log_audit("work_order", wid, "delete", user)
    return {"ok": True}


# ===== RECEIPTS =====
@api.get("/receipts")
async def receipts_list(user: dict = Depends(get_current_user)):
    return await db.receipts.find({}, {"_id": 0}).sort("created_at", -1).to_list(500)


@api.post("/receipts")
async def receipts_create(payload: ReceiptIn, user: dict = Depends(get_current_user)):
    wo = await db.work_orders.find_one({"id": payload.work_order_id}, {"_id": 0})
    if not wo:
        raise HTTPException(404, "Arbetsorder finns ej")
    receipt = {
        "id": str(uuid.uuid4()),
        "number": f"KV-{datetime.now().strftime('%y%m%d')}-{str(uuid.uuid4())[:6].upper()}",
        "work_order_id": wo["id"],
        "order_number": wo.get("order_number"),
        "customer_id": wo["customer_id"],
        "customer_name": wo["customer_name"],
        "regnr": wo["regnr"],
        "brand": wo.get("brand"),
        "model": wo.get("model"),
        "items": wo["items"],
        "subtotal": wo["subtotal"],
        "vat_total": wo["vat_total"],
        "total": wo["total"],
        "paid_status": payload.paid_status,
        "comment": payload.comment,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "created_by": user["name"],
    }
    await db.receipts.insert_one(receipt.copy())
    await db.work_orders.update_one({"id": wo["id"]}, {"$set": {"status": "invoiced"}})
    await log_audit("receipt", receipt["id"], "create", user, new_value=receipt)
    receipt.pop("_id", None)
    return receipt


@api.get("/receipts/{rid}")
async def receipts_get(rid: str, user: dict = Depends(get_current_user)):
    r = await db.receipts.find_one({"id": rid}, {"_id": 0})
    if not r:
        raise HTTPException(404, "Kvitto finns ej")
    return r


@api.get("/receipts/{rid}/pdf")
async def receipts_pdf(rid: str, user: dict = Depends(get_current_user)):
    r = await db.receipts.find_one({"id": rid}, {"_id": 0})
    if not r:
        raise HTTPException(404, "Kvitto finns ej")
    buf = io.BytesIO()
    c = pdf_canvas.Canvas(buf, pagesize=A4)
    w, h = A4
    # Header
    c.setFillColor(colors.HexColor("#0A0A0A"))
    c.rect(0, h - 30 * mm, w, 30 * mm, fill=1, stroke=0)
    c.setFillColor(colors.HexColor("#F59E0B"))
    c.setFont("Helvetica-Bold", 24)
    c.drawString(20 * mm, h - 18 * mm, "GOLDEN AUTO")
    c.setFillColor(colors.white)
    c.setFont("Helvetica", 9)
    c.drawString(20 * mm, h - 24 * mm, "Bilverkstad | Däckhotell | Rekond")
    c.setFont("Helvetica-Bold", 12)
    c.drawRightString(w - 20 * mm, h - 18 * mm, "KVITTO")
    c.setFont("Helvetica", 9)
    c.drawRightString(w - 20 * mm, h - 24 * mm, r["number"])

    c.setFillColor(colors.black)
    y = h - 45 * mm
    c.setFont("Helvetica-Bold", 10)
    c.drawString(20 * mm, y, "Kund")
    c.drawString(110 * mm, y, "Fordon")
    c.setFont("Helvetica", 10)
    y -= 6 * mm
    c.drawString(20 * mm, y, r["customer_name"])
    c.drawString(110 * mm, y, f"Reg.nr: {r['regnr']}")
    y -= 5 * mm
    c.drawString(110 * mm, y, f"{(r.get('brand') or '')} {(r.get('model') or '')}")
    y -= 5 * mm
    c.drawString(20 * mm, y, f"Datum: {r['created_at'][:10]}")
    c.drawString(110 * mm, y, f"Order: {r.get('order_number','')}")

    # Items table header
    y -= 12 * mm
    c.setFillColor(colors.HexColor("#F59E0B"))
    c.rect(20 * mm, y - 1 * mm, w - 40 * mm, 7 * mm, fill=1, stroke=0)
    c.setFillColor(colors.black)
    c.setFont("Helvetica-Bold", 9)
    c.drawString(22 * mm, y + 2 * mm, "BESKRIVNING")
    c.drawRightString(125 * mm, y + 2 * mm, "ANTAL")
    c.drawRightString(155 * mm, y + 2 * mm, "À-PRIS")
    c.drawRightString(w - 22 * mm, y + 2 * mm, "SUMMA")
    y -= 8 * mm

    c.setFont("Helvetica", 9)
    for item in r["items"]:
        c.drawString(22 * mm, y, item["description"][:55])
        c.drawRightString(125 * mm, y, f"{item['qty']:g}")
        c.drawRightString(155 * mm, y, f"{item['unit_price']:.2f}")
        c.drawRightString(w - 22 * mm, y, f"{item['amount']:.2f}")
        y -= 6 * mm
        if y < 40 * mm:
            c.showPage()
            y = h - 30 * mm

    # Totals
    y -= 6 * mm
    c.line(120 * mm, y, w - 20 * mm, y)
    y -= 6 * mm
    c.setFont("Helvetica", 10)
    c.drawRightString(155 * mm, y, "Netto:")
    c.drawRightString(w - 22 * mm, y, f"{r['subtotal']:.2f} kr")
    y -= 5 * mm
    c.drawRightString(155 * mm, y, "Moms (25%):")
    c.drawRightString(w - 22 * mm, y, f"{r['vat_total']:.2f} kr")
    y -= 6 * mm
    c.setFont("Helvetica-Bold", 12)
    c.drawRightString(155 * mm, y, "ATT BETALA:")
    c.drawRightString(w - 22 * mm, y, f"{r['total']:.2f} kr")

    # Status & footer
    y -= 12 * mm
    c.setFont("Helvetica-Bold", 10)
    status_label = "BETALD" if r["paid_status"] == "paid" else "OBETALD"
    c.setFillColor(colors.HexColor("#10B981") if r["paid_status"] == "paid" else colors.HexColor("#EF4444"))
    c.drawString(20 * mm, y, f"Status: {status_label}")
    if r.get("comment"):
        c.setFillColor(colors.black)
        c.setFont("Helvetica-Oblique", 9)
        y -= 6 * mm
        c.drawString(20 * mm, y, f"Kommentar: {r['comment']}")

    c.setFillColor(colors.grey)
    c.setFont("Helvetica", 8)
    c.drawString(20 * mm, 15 * mm, "Golden Auto AB | info@goldenauto.se | Tack för att du valde oss!")
    c.save()
    buf.seek(0)
    return StreamingResponse(buf, media_type="application/pdf",
                             headers={"Content-Disposition": f'inline; filename="{r["number"]}.pdf"'})


# ===== NOTIFICATIONS =====
@api.get("/notifications")
async def notifications_list(user: dict = Depends(get_current_user)):
    return await db.notifications.find({}, {"_id": 0}).sort("sent_at", -1).to_list(500)


# ===== AUDIT LOGS =====
@api.get("/audit-logs")
async def audit_list(entity: Optional[str] = None, user: dict = Depends(require_roles("admin"))):
    filt = {}
    if entity:
        filt["entity"] = entity
    return await db.audit_logs.find(filt, {"_id": 0}).sort("timestamp", -1).to_list(500)


# ===== TIRE HOTEL =====
@api.get("/tire-hotel")
async def tire_hotel_list(user: dict = Depends(get_current_user)):
    records = await db.tire_hotel.find({}, {"_id": 0}).sort("stored_at", -1).to_list(500)
    for rec in records:
        c = await db.customers.find_one({"id": rec.get("customer_id")}, {"_id": 0, "name": 1})
        v = await db.vehicles.find_one({"id": rec.get("vehicle_id")}, {"_id": 0, "regnr": 1})
        rec["customer_name"] = c["name"] if c else None
        rec["regnr"] = v["regnr"] if v else None
    return records


@api.post("/tire-hotel")
async def tire_hotel_create(payload: TireHotelIn, user: dict = Depends(get_current_user)):
    doc = payload.model_dump()
    doc["id"] = str(uuid.uuid4())
    doc["stored_at"] = datetime.now(timezone.utc).isoformat()
    doc["withdrawn_at"] = None
    await db.tire_hotel.insert_one(doc)
    doc.pop("_id", None)
    await log_audit("tire_hotel", doc["id"], "create", user, new_value=doc)
    return doc


# ===== DASHBOARD / REPORTS =====
@api.get("/reports/overview")
async def reports_overview(user: dict = Depends(get_current_user)):
    today = datetime.now(timezone.utc).date().isoformat()
    today_count = await db.bookings.count_documents({"date": today})
    new_count = await db.bookings.count_documents({"status": "new"})
    in_progress = await db.bookings.count_documents({"status": "in_progress"})
    done = await db.bookings.count_documents({"status": "done"})
    total_customers = await db.customers.count_documents({})
    total_vehicles = await db.vehicles.count_documents({})
    receipts_pending = await db.receipts.count_documents({"paid_status": "unpaid"})

    # revenue last 30 days
    cutoff = (datetime.now(timezone.utc) - timedelta(days=30)).isoformat()
    receipts = await db.receipts.find({"created_at": {"$gte": cutoff}}, {"_id": 0, "total": 1, "created_at": 1}).to_list(1000)
    revenue_30d = sum(r["total"] for r in receipts)

    # category breakdown
    pipeline = [{"$group": {"_id": "$category", "count": {"$sum": 1}}}]
    cat_cursor = db.bookings.aggregate(pipeline)
    cats = {}
    async for row in cat_cursor:
        cats[row["_id"] or "ok\u00e4nd"] = row["count"]

    return {
        "today_bookings": today_count,
        "new_bookings": new_count,
        "in_progress": in_progress,
        "done": done,
        "total_customers": total_customers,
        "total_vehicles": total_vehicles,
        "receipts_pending": receipts_pending,
        "revenue_30d": round(revenue_30d, 2),
        "categories": cats,
    }


@api.get("/")
async def api_root():
    return {"app": "Golden Auto", "status": "ok"}


# ---------- Seed data ----------
DEFAULT_SERVICES = [
    {"category": "verkstad", "name": "Felsökning", "description": "Professionell felsökning", "price_from": 800, "duration_min": 60},
    {"category": "verkstad", "name": "Bromsbyte fram", "description": "Byte av bromsbelägg fram", "price_from": 1800, "duration_min": 90},
    {"category": "service", "name": "Oljeservice", "description": "Olja + filter", "price_from": 1495, "duration_min": 60},
    {"category": "service", "name": "Stor service", "description": "Fullständig service", "price_from": 2995, "duration_min": 120},
    {"category": "hjulskifte", "name": "Hjulskifte", "description": "Säsongsskifte av hjul", "price_from": 495, "duration_min": 30},
    {"category": "hjulskifte", "name": "Hjulskifte + balansering", "description": "Skifte med balansering", "price_from": 795, "duration_min": 45},
    {"category": "dackhotell", "name": "Däckhotell - säsong", "description": "Förvaring en säsong", "price_from": 695, "duration_min": 30},
    {"category": "biltvatt", "name": "Utvändig tvätt", "description": "Handtvätt utvändigt", "price_from": 249, "duration_min": 30},
    {"category": "biltvatt", "name": "Tvätt + invändig", "description": "Komplett tvätt", "price_from": 549, "duration_min": 60},
    {"category": "rekond", "name": "Invändig rekond", "description": "Djuprengöring invändigt", "price_from": 2495, "duration_min": 180},
    {"category": "rekond", "name": "Utvändig rekond", "description": "Polering + lackskydd", "price_from": 3495, "duration_min": 240},
]

DEFAULT_ACTIONS = [
    ("verkstad", "Oljebyte utfört", 595),
    ("verkstad", "Oljefilter bytt", 195),
    ("verkstad", "Luftfilter bytt", 295),
    ("verkstad", "Kupéfilter bytt", 395),
    ("verkstad", "Tändstift bytta", 495),
    ("verkstad", "Kamrem bytt", 4995),
    ("verkstad", "Bromsbelägg fram bytta", 1495),
    ("verkstad", "Bromsbelägg bak bytta", 1495),
    ("verkstad", "Bromsskivor fram bytta", 2495),
    ("verkstad", "Felsökning utförd", 795),
    ("verkstad", "Batteri bytt", 1495),
    ("hjulskifte", "Hjulskifte utfört", 495),
    ("hjulskifte", "Sommarhjul monterade", 495),
    ("hjulskifte", "Vinterhjul monterade", 495),
    ("hjulskifte", "Balansering utförd", 300),
    ("dackhotell", "Däck inlagda i däckhotell", 695),
    ("dackhotell", "Däck utlämnade från däckhotell", 0),
    ("biltvatt", "Utvändig tvätt utförd", 249),
    ("biltvatt", "Invändig rengöring utförd", 349),
    ("biltvatt", "Fälgrengöring utförd", 149),
    ("rekond", "Invändig rekond utförd", 2495),
    ("rekond", "Utvändig rekond utförd", 3495),
    ("rekond", "Polering utförd", 1995),
    ("rekond", "Lackskydd applicerat", 2495),
]


async def seed_admin():
    email = os.environ["ADMIN_EMAIL"].lower()
    password = os.environ["ADMIN_PASSWORD"]
    existing = await db.users.find_one({"email": email})
    if not existing:
        await db.users.insert_one({
            "id": str(uuid.uuid4()),
            "email": email,
            "password_hash": hash_password(password),
            "name": "Superadmin",
            "role": "superadmin",
            "active": True,
            "created_at": datetime.now(timezone.utc).isoformat(),
        })
        logger.info(f"Seeded admin: {email}")
    elif not verify_password(password, existing["password_hash"]):
        await db.users.update_one({"email": email}, {"$set": {"password_hash": hash_password(password)}})


async def seed_services():
    if await db.services.count_documents({}) == 0:
        for s in DEFAULT_SERVICES:
            doc = {"id": str(uuid.uuid4()), "active": True, **s}
            await db.services.insert_one(doc)
        logger.info("Seeded default services")


async def seed_actions():
    if await db.standard_actions.count_documents({}) == 0:
        for cat, name, price in DEFAULT_ACTIONS:
            await db.standard_actions.insert_one({
                "id": str(uuid.uuid4()),
                "category": cat,
                "name": name,
                "description": None,
                "default_price": price,
                "default_vat": 25.0,
                "active": True,
            })
        logger.info("Seeded default standard actions")


@app.on_event("startup")
async def on_startup():
    await db.users.create_index("email", unique=True)
    await db.customers.create_index("email")
    await db.vehicles.create_index("regnr")
    await db.bookings.create_index([("date", 1), ("time", 1)])
    await seed_admin()
    await seed_services()
    await seed_actions()


@app.on_event("shutdown")
async def on_shutdown():
    client.close()


app.include_router(api)

app.add_middleware(
    CORSMiddleware,
    allow_credentials=True,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)
