import csv
from decimal import Decimal, InvalidOperation
from io import BytesIO, StringIO
from pathlib import Path
from uuid import UUID, uuid4

from PIL import Image, UnidentifiedImageError
from fastapi import APIRouter, Depends, File, HTTPException, Query, Request, UploadFile, status
from fastapi.responses import FileResponse
from pydantic import ValidationError
from sqlalchemy import case, func, or_, select
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.orm import Session

from app.api.deps import AuthContext, require_path_merchant, require_path_merchant_roles
from app.core.config import get_settings
from app.db.session import get_db
from app.models import (
    Category,
    MembershipRole,
    Product,
    ProductImage,
    RecordStatus,
    StockMovement,
    StockMovementType,
)
from app.schemas.catalog import (
    CategoryCreate,
    CategoryRead,
    CategoryUpdate,
    ProductCreate,
    ProductImageRead,
    ProductRead,
    ProductStockRead,
    ProductUpdate,
)
from app.services.audit import record_audit

router = APIRouter()
CATALOG_EDITORS = (MembershipRole.OWNER, MembershipRole.MANAGER, MembershipRole.STOCK_MANAGER)
MAX_IMAGE_BYTES = 5 * 1024 * 1024
IMAGE_TYPES = {
    "image/jpeg": ("JPEG", "jpg"),
    "image/png": ("PNG", "png"),
    "image/webp": ("WEBP", "webp"),
}


def _stock_expression():
    signed_quantity = case(
        (
            StockMovement.movement_type.in_(
                (StockMovementType.ENTRY, StockMovementType.REVERSAL)
            ),
            StockMovement.quantity,
        ),
        else_=-StockMovement.quantity,
    )
    return (
        select(func.coalesce(func.sum(signed_quantity), 0))
        .where(
            StockMovement.product_id == Product.id,
            StockMovement.merchant_id == Product.merchant_id,
        )
        .correlate(Product)
        .scalar_subquery()
    )


def _product_response(db: Session, product: Product, category_name: str | None, quantity) -> ProductRead:
    image = db.scalar(
        select(ProductImage)
        .where(
            ProductImage.product_id == product.id,
            ProductImage.merchant_id == product.merchant_id,
        )
        .order_by(ProductImage.display_order, ProductImage.created_at)
        .limit(1)
    )
    return ProductRead(
        id=product.id,
        merchant_id=product.merchant_id,
        category_id=product.category_id,
        category_name=category_name,
        name=product.name,
        sku=product.sku,
        purchase_price=product.purchase_price,
        sale_price=product.sale_price,
        stock_alert_threshold=product.stock_alert_threshold,
        quantity=quantity,
        status=product.status.value,
        image=(
            ProductImageRead(
                id=image.id,
                url=f"/api/v1/merchants/{product.merchant_id}/products/{product.id}/images/{image.id}",
                content_type=image.content_type,
                size_bytes=image.size_bytes,
                display_order=image.display_order,
            )
            if image
            else None
        ),
        created_at=product.created_at,
        updated_at=product.updated_at,
    )


def _check_category(db: Session, category_id: UUID | None, merchant_id: UUID) -> None:
    if category_id is None:
        return
    category = db.scalar(
        select(Category).where(
            Category.id == category_id,
            Category.merchant_id == merchant_id,
            Category.status == RecordStatus.ACTIVE,
        )
    )
    if category is None:
        raise HTTPException(status_code=404, detail="Catégorie introuvable.")


def _check_category_name(db: Session, name: str, merchant_id: UUID, except_id: UUID | None = None) -> None:
    query = select(Category.id).where(
        Category.merchant_id == merchant_id,
        func.lower(Category.name) == name.lower(),
        Category.status == RecordStatus.ACTIVE,
    )
    if except_id:
        query = query.where(Category.id != except_id)
    if db.scalar(query):
        raise HTTPException(status_code=409, detail="Une catégorie porte déjà ce nom.")


@router.get("/categories", response_model=list[CategoryRead])
def list_categories(
    merchant_id: UUID,
    include_archived: bool = False,
    _: AuthContext = Depends(require_path_merchant),
    db: Session = Depends(get_db),
) -> list[Category]:
    query = select(Category).where(Category.merchant_id == merchant_id)
    if not include_archived:
        query = query.where(Category.status == RecordStatus.ACTIVE)
    return list(db.scalars(query.order_by(Category.name)).all())


@router.post("/categories", response_model=CategoryRead, status_code=status.HTTP_201_CREATED)
def create_category(
    merchant_id: UUID,
    payload: CategoryCreate,
    request: Request,
    context: AuthContext = Depends(require_path_merchant_roles(*CATALOG_EDITORS)),
    db: Session = Depends(get_db),
) -> Category:
    _check_category_name(db, payload.name, merchant_id)
    category = Category(merchant_id=merchant_id, name=payload.name)
    db.add(category)
    try:
        db.flush()
        record_audit(db, request, "category.created", actor_user_id=context.user.id,
                     merchant_id=merchant_id, target_type="category", target_id=category.id)
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Une catégorie porte déjà ce nom.") from None
    db.refresh(category)
    return category


@router.patch("/categories/{category_id}", response_model=CategoryRead)
def update_category(
    merchant_id: UUID,
    category_id: UUID,
    payload: CategoryUpdate,
    request: Request,
    context: AuthContext = Depends(require_path_merchant_roles(*CATALOG_EDITORS)),
    db: Session = Depends(get_db),
) -> Category:
    category = db.scalar(select(Category).where(
        Category.id == category_id, Category.merchant_id == merchant_id,
        Category.status == RecordStatus.ACTIVE,
    ))
    if category is None:
        raise HTTPException(status_code=404, detail="Catégorie introuvable.")
    _check_category_name(db, payload.name, merchant_id, except_id=category.id)
    category.name = payload.name
    record_audit(db, request, "category.updated", actor_user_id=context.user.id,
                 merchant_id=merchant_id, target_type="category", target_id=category.id)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Une catégorie porte déjà ce nom.") from None
    db.refresh(category)
    return category


@router.delete("/categories/{category_id}", status_code=status.HTTP_204_NO_CONTENT)
def archive_category(
    merchant_id: UUID,
    category_id: UUID,
    request: Request,
    context: AuthContext = Depends(require_path_merchant_roles(*CATALOG_EDITORS)),
    db: Session = Depends(get_db),
) -> None:
    category = db.scalar(select(Category).where(
        Category.id == category_id, Category.merchant_id == merchant_id,
        Category.status == RecordStatus.ACTIVE,
    ))
    if category is None:
        raise HTTPException(status_code=404, detail="Catégorie introuvable.")
    category.status = RecordStatus.ARCHIVED
    record_audit(db, request, "category.archived", actor_user_id=context.user.id,
                 merchant_id=merchant_id, target_type="category", target_id=category.id)
    db.commit()


@router.get("/products", response_model=list[ProductRead])
def list_products(
    merchant_id: UUID,
    q: str | None = Query(default=None, max_length=180),
    category_id: UUID | None = None,
    stock: str = Query(default="all", pattern="^(all|in_stock|available|low|out_of_stock)$"),
    include_archived: bool = False,
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=100, ge=1, le=200),
    _: AuthContext = Depends(require_path_merchant),
    db: Session = Depends(get_db),
) -> list[ProductRead]:
    quantity = _stock_expression()
    query = select(Product, Category.name, quantity).outerjoin(
        Category,
        (Category.id == Product.category_id) & (Category.merchant_id == merchant_id),
    ).where(Product.merchant_id == merchant_id)
    if not include_archived:
        query = query.where(Product.status == RecordStatus.ACTIVE)
    if category_id:
        query = query.where(Product.category_id == category_id)
    if q and q.strip():
        pattern = f"%{q.strip()}%"
        query = query.where(or_(Product.name.ilike(pattern), Product.sku.ilike(pattern)))
    if stock == "available":
        query = query.where(quantity > Product.stock_alert_threshold)
    elif stock == "in_stock":
        query = query.where(quantity > 0)
    elif stock == "low":
        query = query.where(quantity > 0, quantity <= Product.stock_alert_threshold)
    elif stock == "out_of_stock":
        query = query.where(quantity <= 0)
    rows = db.execute(query.order_by(Product.name).offset(offset).limit(limit)).all()
    return [_product_response(db, product, category_name, qty) for product, category_name, qty in rows]


@router.get("/products/{product_id}", response_model=ProductRead)
def read_product(
    merchant_id: UUID,
    product_id: UUID,
    _: AuthContext = Depends(require_path_merchant),
    db: Session = Depends(get_db),
) -> ProductRead:
    row = db.execute(
        select(Product, Category.name, _stock_expression())
        .outerjoin(Category, (Category.id == Product.category_id)
                   & (Category.merchant_id == merchant_id))
        .where(
            Product.id == product_id,
            Product.merchant_id == merchant_id,
            Product.status == RecordStatus.ACTIVE,
        )
    ).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Produit introuvable.")
    product, category_name, quantity = row
    return _product_response(db, product, category_name, quantity)


@router.get("/products/{product_id}/stock", response_model=ProductStockRead)
def read_product_stock(
    merchant_id: UUID,
    product_id: UUID,
    _: AuthContext = Depends(require_path_merchant),
    db: Session = Depends(get_db),
) -> ProductStockRead:
    row = db.execute(
        select(Product, _stock_expression()).where(
            Product.id == product_id,
            Product.merchant_id == merchant_id,
            Product.status == RecordStatus.ACTIVE,
        )
    ).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Produit introuvable.")
    product, quantity = row
    return ProductStockRead(
        product_id=product.id,
        product_name=product.name,
        quantity=quantity,
        alert_threshold=product.stock_alert_threshold,
    )


@router.post("/products", response_model=ProductRead, status_code=status.HTTP_201_CREATED)
def create_product(
    merchant_id: UUID,
    payload: ProductCreate,
    request: Request,
    context: AuthContext = Depends(require_path_merchant_roles(*CATALOG_EDITORS)),
    db: Session = Depends(get_db),
) -> ProductRead:
    _check_category(db, payload.category_id, merchant_id)
    product = Product(merchant_id=merchant_id, **payload.model_dump(exclude={"initial_quantity"}))
    initial_quantity = payload.initial_quantity
    db.add(product)
    db.flush()
    if initial_quantity > 0:
        db.add(StockMovement(
            merchant_id=merchant_id,
            product_id=product.id,
            created_by_user_id=context.user.id,
            movement_type=StockMovementType.ENTRY,
            quantity=initial_quantity,
            note="Stock initial",
        ))
    record_audit(db, request, "product.created", actor_user_id=context.user.id,
                 merchant_id=merchant_id, target_type="product", target_id=product.id)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Ce code produit est déjà utilisé.") from None
    db.refresh(product)
    category_name = db.scalar(select(Category.name).where(Category.id == product.category_id)) if product.category_id else None
    return _product_response(db, product, category_name, initial_quantity)


@router.post("/products/import", status_code=status.HTTP_201_CREATED)
async def import_products(
    merchant_id: UUID,
    request: Request,
    file: UploadFile = File(...),
    context: AuthContext = Depends(require_path_merchant_roles(*CATALOG_EDITORS)),
    db: Session = Depends(get_db),
) -> dict[str, int]:
    if (
        file.content_type not in ("text/csv", "application/csv", "application/vnd.ms-excel")
        and not (file.filename or "").lower().endswith(".csv")
    ):
        raise HTTPException(status_code=415, detail="Le fichier doit être un CSV.")
    content = await file.read(1_000_001)
    if len(content) > 1_000_000:
        raise HTTPException(status_code=413, detail="Le fichier CSV dépasse 1 Mo.")
    try:
        text = content.decode("utf-8-sig")
        reader = csv.DictReader(StringIO(text))
        required = {"name", "sale_price"}
        if not reader.fieldnames or not required.issubset(set(reader.fieldnames)):
            raise ValueError("Colonnes obligatoires : name, sale_price.")
        rows = list(reader)
    except (UnicodeDecodeError, csv.Error, ValueError) as error:
        raise HTTPException(status_code=422, detail=str(error)) from None
    if not rows or len(rows) > 500:
        raise HTTPException(status_code=422, detail="Le CSV doit contenir de 1 à 500 produits.")

    imported = 0
    try:
        for line_number, row in enumerate(rows, start=2):
            category_id = None
            category_name = (row.get("category") or "").strip()
            if category_name:
                category = db.scalar(select(Category).where(
                    Category.merchant_id == merchant_id,
                    func.lower(Category.name) == category_name.lower(),
                    Category.status == RecordStatus.ACTIVE,
                ))
                if category is None:
                    if len(category_name) > 100:
                        raise HTTPException(status_code=422, detail=f"Ligne {line_number} : catégorie trop longue.")
                    category = Category(merchant_id=merchant_id, name=category_name[:100])
                    db.add(category)
                    db.flush()
                category_id = category.id
            try:
                product_data = ProductCreate(
                    name=row.get("name"),
                    category_id=category_id,
                    sku=row.get("sku") or None,
                    purchase_price=int(row.get("purchase_price") or 0),
                    sale_price=int(row["sale_price"]),
                    stock_alert_threshold=Decimal(row.get("stock_alert_threshold") or "0"),
                    initial_quantity=Decimal(row.get("initial_quantity") or "0"),
                )
            except (ValueError, InvalidOperation, ValidationError, KeyError) as error:
                raise HTTPException(
                    status_code=422,
                    detail=f"Ligne {line_number} invalide : {error}",
                ) from None
            product = Product(
                merchant_id=merchant_id,
                **product_data.model_dump(exclude={"initial_quantity"}),
            )
            db.add(product)
            db.flush()
            if product_data.initial_quantity > 0:
                db.add(StockMovement(
                    merchant_id=merchant_id,
                    product_id=product.id,
                    created_by_user_id=context.user.id,
                    movement_type=StockMovementType.ENTRY,
                    quantity=product_data.initial_quantity,
                    note="Stock initial importé",
                ))
            imported += 1
        record_audit(
            db,
            request,
            "products.imported",
            actor_user_id=context.user.id,
            merchant_id=merchant_id,
            details={"count": imported},
        )
        db.commit()
    except HTTPException:
        db.rollback()
        raise
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="Import annulé : un code SKU existe déjà dans la boutique ou le fichier.",
        ) from None
    return {"imported": imported}


@router.patch("/products/{product_id}", response_model=ProductRead)
def update_product(
    merchant_id: UUID,
    product_id: UUID,
    payload: ProductUpdate,
    request: Request,
    context: AuthContext = Depends(require_path_merchant_roles(*CATALOG_EDITORS)),
    db: Session = Depends(get_db),
) -> ProductRead:
    product = db.scalar(select(Product).where(
        Product.id == product_id, Product.merchant_id == merchant_id,
        Product.status == RecordStatus.ACTIVE,
    ).with_for_update())
    if product is None:
        raise HTTPException(status_code=404, detail="Produit introuvable.")
    updates = payload.model_dump(exclude_unset=True)
    if "category_id" in updates:
        _check_category(db, updates["category_id"], merchant_id)
    for field, value in updates.items():
        setattr(product, field, value)
    record_audit(db, request, "product.updated", actor_user_id=context.user.id,
                 merchant_id=merchant_id, target_type="product", target_id=product.id)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Ce code produit est déjà utilisé.") from None
    db.refresh(product)
    category_name = db.scalar(select(Category.name).where(Category.id == product.category_id)) if product.category_id else None
    quantity = db.scalar(select(_stock_expression()).where(Product.id == product.id)) or 0
    return _product_response(db, product, category_name, quantity)


@router.delete("/products/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
def archive_product(
    merchant_id: UUID,
    product_id: UUID,
    request: Request,
    context: AuthContext = Depends(require_path_merchant_roles(*CATALOG_EDITORS)),
    db: Session = Depends(get_db),
) -> None:
    product = db.scalar(select(Product).where(
        Product.id == product_id, Product.merchant_id == merchant_id,
        Product.status == RecordStatus.ACTIVE,
    ).with_for_update())
    if product is None:
        raise HTTPException(status_code=404, detail="Produit introuvable.")
    product.status = RecordStatus.ARCHIVED
    record_audit(db, request, "product.archived", actor_user_id=context.user.id,
                 merchant_id=merchant_id, target_type="product", target_id=product.id)
    db.commit()


@router.post("/products/{product_id}/images", response_model=ProductImageRead,
             status_code=status.HTTP_201_CREATED)
async def upload_product_image(
    merchant_id: UUID,
    product_id: UUID,
    request: Request,
    file: UploadFile = File(...),
    context: AuthContext = Depends(require_path_merchant_roles(*CATALOG_EDITORS)),
    db: Session = Depends(get_db),
) -> ProductImageRead:
    product = db.scalar(select(Product).where(
        Product.id == product_id, Product.merchant_id == merchant_id,
        Product.status == RecordStatus.ACTIVE,
    ).with_for_update())
    if product is None:
        raise HTTPException(status_code=404, detail="Produit introuvable.")
    image_info = IMAGE_TYPES.get(file.content_type or "")
    if image_info is None:
        raise HTTPException(status_code=415, detail="Format accepté : JPEG, PNG ou WebP.")
    content = await file.read(MAX_IMAGE_BYTES + 1)
    if not content or len(content) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=400, detail="Image invalide ou supérieure à 5 Mo.")
    try:
        with Image.open(BytesIO(content)) as decoded:
            valid_image = (
                decoded.format == image_info[0]
                and decoded.width * decoded.height <= 20_000_000
            )
            decoded.verify()
    except (UnidentifiedImageError, OSError, Image.DecompressionBombError):
        valid_image = False
    if not valid_image:
        raise HTTPException(status_code=400, detail="Le contenu du fichier n’est pas une image valide.")

    root = Path(get_settings().product_images_dir).resolve()
    key = Path(str(merchant_id), str(product_id), f"{uuid4()}.{image_info[1]}")
    destination = root / key
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(content)
    image = db.scalar(select(ProductImage).where(
        ProductImage.product_id == product_id,
        ProductImage.merchant_id == merchant_id,
        ProductImage.display_order == 0,
    ).with_for_update())
    old_path = (root / image.storage_key).resolve() if image else None
    if image is None:
        image = ProductImage(
            merchant_id=merchant_id,
            product_id=product_id,
            storage_key=key.as_posix(),
            content_type=file.content_type,
            size_bytes=len(content),
            display_order=0,
        )
        db.add(image)
    else:
        image.storage_key = key.as_posix()
        image.content_type = file.content_type
        image.size_bytes = len(content)
    try:
        db.flush()
        record_audit(db, request, "product.image_uploaded", actor_user_id=context.user.id,
                     merchant_id=merchant_id, target_type="product_image", target_id=image.id)
        db.commit()
    except IntegrityError:
        db.rollback()
        destination.unlink(missing_ok=True)
        raise HTTPException(status_code=409, detail="Une image principale existe déjà.") from None
    except SQLAlchemyError:
        db.rollback()
        destination.unlink(missing_ok=True)
        raise
    if old_path and root in old_path.parents and old_path != destination:
        old_path.unlink(missing_ok=True)
    db.refresh(image)
    return ProductImageRead(
        id=image.id,
        url=f"/api/v1/merchants/{merchant_id}/products/{product_id}/images/{image.id}",
        content_type=image.content_type,
        size_bytes=image.size_bytes,
        display_order=image.display_order,
    )


@router.get("/products/{product_id}/images/{image_id}")
def read_product_image(
    merchant_id: UUID,
    product_id: UUID,
    image_id: UUID,
    _: AuthContext = Depends(require_path_merchant),
    db: Session = Depends(get_db),
) -> FileResponse:
    image = db.scalar(select(ProductImage).where(
        ProductImage.id == image_id, ProductImage.product_id == product_id,
        ProductImage.merchant_id == merchant_id,
    ))
    if image is None:
        raise HTTPException(status_code=404, detail="Image introuvable.")
    path = (Path(get_settings().product_images_dir) / image.storage_key).resolve()
    root = Path(get_settings().product_images_dir).resolve()
    if root not in path.parents or not path.is_file():
        raise HTTPException(status_code=404, detail="Image introuvable.")
    return FileResponse(path, media_type=image.content_type, content_disposition_type="inline")
