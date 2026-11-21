from functools import lru_cache

from pydantic import Field, SecretStr, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy.engine import URL


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_env: str = "development"
    app_name: str = "Boutik Faso API"
    api_v1_prefix: str = "/api/v1"
    database_url: str | None = None
    db_host: str | None = None
    db_port: int = Field(default=5432, ge=1, le=65535)
    db_name: str | None = None
    db_user: str | None = None
    db_password: SecretStr | None = None
    jwt_secret_key: SecretStr = SecretStr(
        "local-only-development-secret-change-before-deployment"
    )
    jwt_algorithm: str = "HS256"
    jwt_issuer: str = "boutik-faso-api"
    jwt_audience: str = "boutik-faso-client"
    jwt_access_token_minutes: int = Field(default=15, ge=1, le=60)
    jwt_refresh_token_days: int = Field(default=30, ge=1, le=90)
    product_images_dir: str = "storage/product-images"

    @model_validator(mode="after")
    def assemble_database_url_and_validate_secrets(self) -> "Settings":
        if self.database_url is None:
            if not all((self.db_host, self.db_name, self.db_user, self.db_password)):
                raise ValueError(
                    "Configurez DATABASE_URL ou DB_HOST, DB_NAME, DB_USER et DB_PASSWORD."
                )
            self.database_url = URL.create(
                "postgresql+psycopg",
                username=self.db_user,
                password=self.db_password.get_secret_value(),
                host=self.db_host,
                port=self.db_port,
                database=self.db_name,
            ).render_as_string(hide_password=False)

        if (
            self.app_env == "production"
            and self.jwt_secret_key.get_secret_value().startswith("local-only-")
        ):
            raise ValueError("Un secret JWT de production doit être configuré.")
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
