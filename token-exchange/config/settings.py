from app_logging.logger import get_logger
from pydantic_settings import BaseSettings, SettingsConfigDict


logger = get_logger(__name__)


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="IDENTITY_BROKER_",
        case_sensitive=False,
        env_file=".env",
        extra="ignore",
    )

    vault_addr: str = "https://127.0.0.1:8200"
    vault_tls_verify: bool = True
    # Path to a PEM CA bundle for Vault's self-signed or private CA certificate.
    # When set, TLS verification uses this bundle instead of the default certifi roots.
    vault_ca_bundle: str | None = None

    # IBM Verify OBO token exchange settings.
    verify_base_url: str = ""
    obo_client_id: str = ""

    cache_ttl: int = 3600       # seconds; also the TTLCache eviction window
    cache_maxsize: int = 1024   # max number of cached tokens

    log_level: str = "INFO"

    def log_configured_values(self) -> None:
        logger.info("settings_loaded", **self.model_dump())


settings = Settings()
